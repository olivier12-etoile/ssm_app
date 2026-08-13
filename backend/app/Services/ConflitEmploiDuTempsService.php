<?php

namespace App\Services;

use App\Models\ClasseMatiere;
use App\Models\CreneauHoraire;
use App\Models\EmploiDuTemps;
use App\Models\Seance;

/**
 * Centralise toutes les vérifications de conflits du module Emploi du
 * Temps, pour garantir qu'elles sont appliquées de façon identique à la
 * création, la modification, la saisie en masse et la validation d'un
 * emploi du temps.
 *
 * Convention commune à verifierConflitEnseignant/verifierConflitSalle : le
 * paramètre "emploiDuTempsIdExclu" désigne l'emploi du temps CONCERNÉ par
 * la séance en cours de création/modification. Il sert à la fois à
 * résoudre l'année scolaire/période de la recherche de conflit, et à
 * exclure ce même emploi du temps des résultats — une séance de la classe
 * qu'on est en train de programmer n'est jamais "une autre classe".
 */
class ConflitEmploiDuTempsService
{
    // ── L'enseignant est-il déjà programmé ailleurs sur ce créneau/jour ? ──
    public function verifierConflitEnseignant(
        int $enseignantId,
        string $jour,
        int $creneauHoraireId,
        ?int $emploiDuTempsIdExclu = null
    ): ?array {
        $creneau = CreneauHoraire::find($creneauHoraireId);
        if (!$creneau) {
            return null;
        }

        $periodeId = null;
        if ($emploiDuTempsIdExclu) {
            $periodeId = EmploiDuTemps::find($emploiDuTempsIdExclu)?->periode_id;
        }

        $conflit = Seance::where('enseignant_id', $enseignantId)
            ->where('jour', $jour)
            ->where('creneau_horaire_id', $creneauHoraireId)
            ->whereHas('emploiDuTemps', function ($q) use ($creneau, $periodeId, $emploiDuTempsIdExclu) {
                $q->where('annee_scolaire_id', $creneau->annee_scolaire_id);
                if ($periodeId) {
                    $q->where('periode_id', $periodeId);
                }
                if ($emploiDuTempsIdExclu) {
                    $q->where('id', '!=', $emploiDuTempsIdExclu);
                }
            })
            ->with(['emploiDuTemps.classe:id,nom', 'matiere:id,nom'])
            ->first();

        if (!$conflit) {
            return null;
        }

        return [
            'type' => 'conflit_enseignant',
            'message' => "L'enseignant est déjà programmé sur ce créneau, dans la classe "
                . "{$conflit->emploiDuTemps->classe->nom} ({$conflit->matiere->nom}).",
            'seance_id' => $conflit->id,
            'classe_nom' => $conflit->emploiDuTemps->classe->nom,
            'matiere_nom' => $conflit->matiere->nom,
        ];
    }

    // ── Ce créneau/jour est-il déjà occupé dans CET emploi du temps ? ──
    public function verifierConflitClasse(
        int $emploiDuTempsId,
        string $jour,
        int $creneauHoraireId,
        ?int $seanceIdExclu = null
    ): ?array {
        $conflit = Seance::where('emploi_du_temps_id', $emploiDuTempsId)
            ->where('jour', $jour)
            ->where('creneau_horaire_id', $creneauHoraireId)
            ->when($seanceIdExclu, fn ($q) => $q->where('id', '!=', $seanceIdExclu))
            ->with('matiere:id,nom')
            ->first();

        if (!$conflit) {
            return null;
        }

        return [
            'type' => 'conflit_classe',
            'message' => "Une séance de {$conflit->matiere->nom} est déjà programmée sur ce créneau pour cette classe.",
            'seance_id' => $conflit->id,
        ];
    }

    // ── La salle est-elle déjà occupée ailleurs sur ce créneau/jour ? ──
    public function verifierConflitSalle(
        ?string $salle,
        string $jour,
        int $creneauHoraireId,
        int $anneeScolaireId,
        ?int $emploiDuTempsIdExclu = null
    ): ?array {
        if (!$salle) {
            return null;
        }

        $conflit = Seance::where('salle', $salle)
            ->where('jour', $jour)
            ->where('creneau_horaire_id', $creneauHoraireId)
            ->whereHas('emploiDuTemps', function ($q) use ($anneeScolaireId, $emploiDuTempsIdExclu) {
                $q->where('annee_scolaire_id', $anneeScolaireId);
                if ($emploiDuTempsIdExclu) {
                    $q->where('id', '!=', $emploiDuTempsIdExclu);
                }
            })
            ->with(['emploiDuTemps.classe:id,nom', 'matiere:id,nom'])
            ->first();

        if (!$conflit) {
            return null;
        }

        return [
            'type' => 'conflit_salle',
            'message' => "La salle \"{$salle}\" est déjà occupée sur ce créneau par la classe "
                . "{$conflit->emploiDuTemps->classe->nom} ({$conflit->matiere->nom}).",
            'seance_id' => $conflit->id,
        ];
    }

    // ── Le créneau existe-t-il bien pour l'école, et est-ce un créneau de
    // cours (pas une récréation/pause) ? ──
    public function verifierHoraireEcole(int $creneauHoraireId): ?array
    {
        $ecoleId = auth()->user()?->ecole_id;

        $creneau = CreneauHoraire::where('id', $creneauHoraireId)
            ->where('ecole_id', $ecoleId)
            ->first();

        if (!$creneau) {
            return [
                'type' => 'horaire_invalide',
                'message' => "Ce créneau horaire n'existe pas pour votre école.",
            ];
        }

        if ($creneau->type !== 'cours') {
            return [
                'type' => 'horaire_invalide',
                'message' => "Le créneau \"{$creneau->libelle}\" n'est pas un créneau de cours "
                    . "(récréation ou pause) et ne peut pas recevoir de séance.",
            ];
        }

        return null;
    }

    // ── Lance toutes les vérifications pour une séance à créer/modifier ──
    // $donnees attendu : emploi_du_temps_id, creneau_horaire_id, jour,
    // matiere_id, enseignant_id, salle (optionnel), seance_id_exclu
    // (optionnel, lors d'une modification).
    public function verifierTous(array $donnees): array
    {
        $conflits = [];

        $horaireInvalide = $this->verifierHoraireEcole($donnees['creneau_horaire_id']);
        if ($horaireInvalide) {
            // Un créneau invalide rend les vérifications suivantes non pertinentes.
            return [$horaireInvalide];
        }

        $conflitClasse = $this->verifierConflitClasse(
            $donnees['emploi_du_temps_id'],
            $donnees['jour'],
            $donnees['creneau_horaire_id'],
            $donnees['seance_id_exclu'] ?? null
        );
        if ($conflitClasse) {
            $conflits[] = $conflitClasse;
        }

        $conflitEnseignant = $this->verifierConflitEnseignant(
            $donnees['enseignant_id'],
            $donnees['jour'],
            $donnees['creneau_horaire_id'],
            $donnees['emploi_du_temps_id']
        );
        if ($conflitEnseignant) {
            $conflits[] = $conflitEnseignant;
        }

        if (!empty($donnees['salle'])) {
            $emploiDuTemps = EmploiDuTemps::find($donnees['emploi_du_temps_id']);
            if ($emploiDuTemps) {
                $conflitSalle = $this->verifierConflitSalle(
                    $donnees['salle'],
                    $donnees['jour'],
                    $donnees['creneau_horaire_id'],
                    $emploiDuTemps->annee_scolaire_id,
                    $donnees['emploi_du_temps_id']
                );
                if ($conflitSalle) {
                    $conflits[] = $conflitSalle;
                }
            }
        }

        return $conflits;
    }

    // ── Volume horaire programmé vs attendu, pour une matière donnée ──
    public function volumeHoraireMatiere(int $emploiDuTempsId, int $matiereId): array
    {
        $emploiDuTemps = EmploiDuTemps::findOrFail($emploiDuTempsId);

        $minutes = Seance::where('emploi_du_temps_id', $emploiDuTempsId)
            ->where('matiere_id', $matiereId)
            ->with('creneauHoraire')
            ->get()
            ->filter(fn (Seance $s) => $s->creneauHoraire?->type === 'cours')
            ->sum(function (Seance $s) {
                $debut = $s->creneauHoraire->heure_debut;
                $fin = $s->creneauHoraire->heure_fin;

                return $fin->diffInMinutes($debut, true);
            });

        $classeMatiere = ClasseMatiere::where('classe_id', $emploiDuTemps->classe_id)
            ->where('matiere_id', $matiereId)
            ->first();

        return [
            'programme' => round($minutes / 60, 2),
            'attendu' => $classeMatiere?->volume_horaire_hebdomadaire,
        ];
    }
}
