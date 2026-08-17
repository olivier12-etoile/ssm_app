<?php

namespace App\Services;

use App\Models\AppelPresence;
use App\Models\Classe;
use App\Models\Eleve;
use App\Models\ParametreNotification;
use App\Models\PeriodeAcademique;
use App\Models\Presence;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Gestion des appels de présence (module Classes) : une session d'appel par
 * classe/matière/date/créneau, avec une ligne Presence par élève créée au
 * statut "present" par défaut — l'enseignant ne fait que signaler les
 * absents/retards, jamais l'inverse.
 */
class PresenceService
{
    public function __construct(private DeclencheurNotificationService $declencheurService)
    {
    }

    public function creerAppel(
        int $classeId,
        ?int $matiereId,
        int $periodeId,
        string $dateAppel,
        ?int $creneauHoraireId
    ): AppelPresence {
        $classe = Classe::findOrFail($classeId);
        $periode = PeriodeAcademique::findOrFail($periodeId);

        // L'unicité en base ne bloque pas les doublons quand matiere_id/
        // creneau_horaire_id sont NULL (voir migration) : on vérifie donc
        // aussi ici, y compris pour les valeurs NULL.
        $existant = AppelPresence::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('date_appel', $dateAppel)
            ->where('creneau_horaire_id', $creneauHoraireId)
            ->exists();

        if ($existant) {
            throw new RuntimeException('Un appel existe déjà pour ce cours à cette date.');
        }

        $eleves = Eleve::whereHas('inscriptions', fn ($q) => $q
            ->where('classe_id', $classeId)
            ->where('annee_academique_id', $periode->annee_academique_id))
            ->orderBy('nom')
            ->get();

        if ($eleves->isEmpty()) {
            throw new RuntimeException("Aucun élève inscrit dans la classe {$classe->nom} pour cette année.");
        }

        return DB::transaction(function () use ($classe, $matiereId, $periode, $dateAppel, $creneauHoraireId, $eleves) {
            $appel = AppelPresence::create([
                'ecole_id' => auth()->user()->ecole_id,
                'classe_id' => $classe->id,
                'matiere_id' => $matiereId,
                'enseignant_id' => auth()->id(),
                'annee_scolaire_id' => $periode->annee_academique_id,
                'periode_id' => $periode->id,
                'date_appel' => $dateAppel,
                'creneau_horaire_id' => $creneauHoraireId,
                'statut' => 'en_cours',
            ]);

            foreach ($eleves as $eleve) {
                Presence::create([
                    'appel_presence_id' => $appel->id,
                    'eleve_id' => $eleve->id,
                    'statut' => 'present',
                ]);
            }

            return $appel->load('presences.eleve');
        });
    }

    public function marquerPresence(
        int $appelId,
        int $eleveId,
        string $statut,
        bool $justifie = false,
        ?string $motif = null,
        ?int $minutesRetard = null
    ): Presence {
        $appel = AppelPresence::findOrFail($appelId);

        if ($appel->statut === 'termine') {
            throw new RuntimeException('Cet appel est déjà terminé, il ne peut plus être modifié.');
        }

        $presence = Presence::where('appel_presence_id', $appelId)->where('eleve_id', $eleveId)->firstOrFail();

        $presence->update([
            'statut' => $statut,
            'justifie' => $statut === 'absent' ? $justifie : false,
            'motif_justification' => $motif,
            'minutes_retard' => $statut === 'retard' ? $minutesRetard : null,
        ]);

        return $presence->fresh();
    }

    public function marquerPresenceBulk(int $appelId, array $statuts): AppelPresence
    {
        $appel = AppelPresence::findOrFail($appelId);

        if ($appel->statut === 'termine') {
            throw new RuntimeException('Cet appel est déjà terminé, il ne peut plus être modifié.');
        }

        DB::transaction(function () use ($appelId, $statuts) {
            foreach ($statuts as $ligne) {
                $presence = Presence::where('appel_presence_id', $appelId)
                    ->where('eleve_id', $ligne['eleve_id'])
                    ->first();

                if (!$presence) {
                    continue;
                }

                $statut = $ligne['statut'];

                $presence->update([
                    'statut' => $statut,
                    'justifie' => $statut === 'absent' ? ($ligne['justifie'] ?? false) : false,
                    'motif_justification' => $ligne['motif_justification'] ?? null,
                    'minutes_retard' => $statut === 'retard' ? ($ligne['minutes_retard'] ?? null) : null,
                ]);
            }
        });

        return $appel->fresh('presences.eleve');
    }

    /**
     * Termine l'appel puis notifie les parents des élèves absents (et des
     * retards si le déclencheur "retard" est actif pour l'école) qui n'ont
     * pas encore été notifiés pour cet appel.
     */
    public function terminerAppel(int $appelId): AppelPresence
    {
        $appel = AppelPresence::with('presences')->findOrFail($appelId);

        if ($appel->statut === 'termine') {
            throw new RuntimeException('Cet appel est déjà terminé.');
        }

        $appel->update(['statut' => 'termine']);

        $notifierRetards = ParametreNotification::estActif($appel->ecole_id, 'retard');

        foreach ($appel->presences as $presence) {
            if ($presence->notifie_parent) {
                continue;
            }

            $doitNotifier = $presence->statut === 'absent'
                || ($presence->statut === 'retard' && $notifierRetards);

            if (!$doitNotifier) {
                continue;
            }

            $this->declencheurService->surAbsence($presence->id);
            $presence->update(['notifie_parent' => true]);
        }

        return $appel->fresh('presences.eleve');
    }

    public function historiqueEleve(int $eleveId, int $periodeId): array
    {
        $presences = Presence::with(['appelPresence.classe', 'appelPresence.matiere'])
            ->where('eleve_id', $eleveId)
            ->whereHas('appelPresence', fn ($q) => $q->where('periode_id', $periodeId)->where('statut', 'termine'))
            ->get()
            ->sortByDesc(fn (Presence $p) => $p->appelPresence->date_appel)
            ->map(fn (Presence $p) => [
                'presence_id' => $p->id,
                'date' => $p->appelPresence->date_appel->format('Y-m-d'),
                'classe' => $p->appelPresence->classe->nom ?? null,
                'matiere' => $p->appelPresence->matiere->nom ?? null,
                'statut' => $p->statut,
                'justifie' => $p->justifie,
                'motif_justification' => $p->motif_justification,
                'minutes_retard' => $p->minutes_retard,
            ])
            ->values();

        return [
            'presences' => $presences,
            'totaux' => Presence::totauxPourEleve($eleveId, $periodeId),
        ];
    }

    public function statistiquesClasse(int $classeId, int $periodeId): array
    {
        $periode = PeriodeAcademique::findOrFail($periodeId);

        $eleves = Eleve::whereHas('inscriptions', fn ($q) => $q
            ->where('classe_id', $classeId)
            ->where('annee_academique_id', $periode->annee_academique_id))
            ->orderBy('nom')
            ->get();

        $classement = $eleves->map(function (Eleve $eleve) use ($periodeId) {
            $totaux = Presence::totauxPourEleve($eleve->id, $periodeId);

            return [
                'eleve_id' => $eleve->id,
                'nom' => $eleve->nom,
                'prenom' => $eleve->prenom,
                'absences_justifiees' => $totaux['absences_justifiees'],
                'absences_non_justifiees' => $totaux['absences_non_justifiees'],
                'retards' => $totaux['retards'],
                'taux_presence' => $totaux['taux_presence'],
            ];
        })->sortByDesc(fn ($ligne) => $ligne['absences_non_justifiees'] + $ligne['retards'])->values();

        $totalAppels = AppelPresence::where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->where('statut', 'termine')
            ->count();

        return [
            'classe_id' => $classeId,
            'periode_id' => $periodeId,
            'total_appels' => $totalAppels,
            'taux_presence_classe' => $classement->isNotEmpty() ? round($classement->avg('taux_presence'), 2) : 0.0,
            'eleves' => $classement,
        ];
    }

    public function appelsRecents(int $classeId, int $limite = 10)
    {
        return AppelPresence::where('classe_id', $classeId)
            ->with(['matiere', 'creneauHoraire', 'enseignant', 'presences'])
            ->orderByDesc('date_appel')
            ->orderByDesc('id')
            ->limit($limite)
            ->get();
    }
}
