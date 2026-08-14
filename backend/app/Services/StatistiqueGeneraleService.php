<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Classe;
use App\Models\Inscription;
use App\Models\InstantaneStatistique;
use App\Models\User;

/**
 * Agrège les données déjà existantes des modules Élèves, Frais Scolaires,
 * Notes et Classes pour alimenter le tableau de bord général de l'école.
 * Ne recalcule rien qui existe déjà : réutilise FraisCalculService pour le
 * financier et NoteCalculService pour les résultats pédagogiques.
 */
class StatistiqueGeneraleService
{
    public function __construct(
        private FraisCalculService $fraisCalcul,
        private NoteCalculService $noteCalcul,
    ) {
    }

    // ── Effectifs élèves ──────────────────────────────────────────
    // TODO: eleves.statut est l'enum ['actif','suspendu','exclu','transfere',
    // 'diplome','abandon'] — il n'existe pas de statut "renvoyé" distinct,
    // on le rapproche de 'exclu'. Les "abandons" sont comptés via
    // inscriptions.statut = 'abandonne' (rattaché à l'année précise) avec
    // repli sur eleves.statut = 'abandon'.
    public function effectifsGeneraux(int $anneeScolaireId): array
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);

        $inscriptions = Inscription::where('annee_academique_id', $anneeScolaireId)
            ->whereHas('eleve', fn ($q) => $q->where('ecole_id', $annee->ecole_id))
            ->with('eleve')
            ->get();

        // Années antérieures de la même école, pour distinguer nouvelles
        // inscriptions et réinscriptions.
        $anneesAnterieuresIds = AnneeAcademique::where('ecole_id', $annee->ecole_id)
            ->where('date_debut', '<', $annee->date_debut)
            ->pluck('id');

        $elevesDejaInscritsAvant = $anneesAnterieuresIds->isEmpty()
            ? collect()
            : Inscription::whereIn('annee_academique_id', $anneesAnterieuresIds)->pluck('eleve_id')->unique();

        $nouveaux = 0;
        $reinscriptions = 0;

        foreach ($inscriptions as $inscription) {
            if ($elevesDejaInscritsAvant->contains($inscription->eleve_id)) {
                $reinscriptions++;
            } else {
                $nouveaux++;
            }
        }

        return [
            'annee_scolaire_id' => $anneeScolaireId,
            'total'             => $inscriptions->count(),
            'garcons'           => $inscriptions->filter(fn ($i) => $i->eleve?->sexe === 'M')->count(),
            'filles'            => $inscriptions->filter(fn ($i) => $i->eleve?->sexe === 'F')->count(),
            'nouveaux_inscrits' => $nouveaux,
            'reinscriptions'    => $reinscriptions,
            'transferes'        => $inscriptions->filter(fn ($i) => $i->eleve?->statut === 'transfere')->count(),
            'renvoyes'          => $inscriptions->filter(fn ($i) => $i->eleve?->statut === 'exclu')->count(),
            'abandons'          => $inscriptions->filter(
                fn ($i) => $i->statut === 'abandonne' || $i->eleve?->statut === 'abandon'
            )->count(),
        ];
    }

    // ── Effectifs enseignants ─────────────────────────────────────
    // TODO: aucun champ ne distingue permanent/vacataire sur users — on se
    // base sur le champ libre "fonction" (s'il contient "vacataire").
    // À remplacer par un vrai champ type_contrat si ce besoin est confirmé.
    public function effectifsEnseignants(int $ecoleId): array
    {
        $enseignants = User::where('ecole_id', $ecoleId)->where('role', 'enseignant')->get();

        $vacataires = $enseignants
            ->filter(fn ($e) => str_contains(strtolower((string) $e->fonction), 'vacataire'))
            ->count();

        return [
            'total'      => $enseignants->count(),
            'permanents' => $enseignants->count() - $vacataires,
            'vacataires' => $vacataires,
            'actifs'     => $enseignants->where('actif', true)->count(),
        ];
    }

    // ── Effectifs classes ─────────────────────────────────────────
    public function effectifsClasses(int $anneeScolaireId): array
    {
        $classes = Classe::where('annee_academique_id', $anneeScolaireId)
            ->withCount('inscriptions')
            ->get();

        $totalClasses = $classes->count();
        $totalEleves = $classes->sum('inscriptions_count');

        return [
            'total_classes'         => $totalClasses,
            'moyenne_eleves_classe' => $totalClasses > 0 ? round($totalEleves / $totalClasses, 1) : 0.0,
            'salles_utilisees'      => $classes->pluck('salle')->filter()->unique()->count(),
        ];
    }

    // ── Résumé financier (délègue à FraisCalculService) ───────────
    public function resumeFinancier(int $anneeScolaireId): array
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);
        $rapport = $this->fraisCalcul->rapportEcole($annee->ecole_id, $anneeScolaireId);

        $attendu = $rapport['total_global']['total_attendu'];
        $encaisse = $rapport['total_global']['total_encaisse'];

        return [
            'annee_scolaire_id' => $anneeScolaireId,
            'montant_attendu'   => $attendu,
            'montant_encaisse'  => $encaisse,
            'montant_restant'   => $rapport['total_global']['total_restant'],
            'taux_recouvrement' => $attendu > 0 ? round($encaisse / $attendu * 100, 1) : 0.0,
            'nombre_debiteurs'  => count($rapport['debiteurs']),
        ];
    }

    // ── Résumé résultats scolaires (délègue à NoteCalculService) ──
    // Si periodeId n'est pas fourni, on prend la période active de l'année.
    public function resumeResultatsScolaires(int $anneeScolaireId, ?int $periodeId = null): array
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);
        $periodeId = $periodeId ?? $annee->periodeActive()?->id;

        if (!$periodeId) {
            return [
                'annee_scolaire_id'   => $anneeScolaireId,
                'periode_id'          => null,
                'moyenne_generale'    => null,
                'taux_reussite'       => 0.0,
                'taux_echec'          => 0.0,
                'nombre_eleves_ge_10' => 0,
                'nombre_eleves_lt_10' => 0,
            ];
        }

        $elevesIds = Inscription::where('annee_academique_id', $anneeScolaireId)
            ->whereHas('eleve', fn ($q) => $q->where('ecole_id', $annee->ecole_id))
            ->pluck('eleve_id');

        $moyennes = $elevesIds
            ->map(fn ($eleveId) => $this->noteCalcul->moyenneEleve($eleveId, $periodeId))
            ->filter(fn ($m) => $m !== null)
            ->values();

        $nbGe10 = $moyennes->filter(fn ($m) => $m >= 10)->count();
        $nbLt10 = $moyennes->count() - $nbGe10;

        return [
            'annee_scolaire_id'   => $anneeScolaireId,
            'periode_id'          => $periodeId,
            'moyenne_generale'    => $moyennes->isNotEmpty() ? round($moyennes->avg(), 2) : null,
            'taux_reussite'       => $moyennes->isNotEmpty() ? round($nbGe10 / $moyennes->count() * 100, 1) : 0.0,
            'taux_echec'          => $moyennes->isNotEmpty() ? round($nbLt10 / $moyennes->count() * 100, 1) : 0.0,
            'nombre_eleves_ge_10' => $nbGe10,
            'nombre_eleves_lt_10' => $nbLt10,
        ];
    }

    // ── Tableau de bord général (combine tout) ────────────────────
    public function dashboardGeneral(int $anneeScolaireId, ?int $periodeId = null): array
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);

        return [
            'annee_scolaire_id' => $anneeScolaireId,
            'periode_id'        => $periodeId,
            'effectifs'         => $this->effectifsGeneraux($anneeScolaireId),
            'enseignants'       => $this->effectifsEnseignants($annee->ecole_id),
            'classes'           => $this->effectifsClasses($anneeScolaireId),
            'financier'         => $this->resumeFinancier($anneeScolaireId),
            'resultats'         => $this->resumeResultatsScolaires($anneeScolaireId, $periodeId),
        ];
    }

    // ── Historisation ──────────────────────────────────────────────
    public function creerSnapshot(int $anneeScolaireId, string $type): InstantaneStatistique
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);
        $donnees = $this->calculerDonneesType($anneeScolaireId, $type);

        return InstantaneStatistique::create([
            'ecole_id'          => $annee->ecole_id,
            'annee_scolaire_id' => $anneeScolaireId,
            'type'              => $type,
            'donnees'           => $donnees,
            'date_snapshot'     => now(),
        ]);
    }

    // Compare le dernier instantané enregistré de chaque année pour un type
    // donné (calculé à la volée si aucun instantané n'existe encore).
    public function comparerAnnees(int $anneeScolaireId1, int $anneeScolaireId2, string $type): array
    {
        $donnees1 = $this->donneesPourComparaison($anneeScolaireId1, $type);
        $donnees2 = $this->donneesPourComparaison($anneeScolaireId2, $type);

        $ecarts = [];
        foreach ($donnees1 as $cle => $valeur1) {
            $valeur2 = $donnees2[$cle] ?? null;
            if (!is_numeric($valeur1) || !is_numeric($valeur2)) {
                continue;
            }

            $ecarts[$cle] = [
                'annee_1'           => $valeur1,
                'annee_2'           => $valeur2,
                'ecart'             => round($valeur2 - $valeur1, 2),
                'ecart_pourcentage' => $valeur1 != 0 ? round((($valeur2 - $valeur1) / $valeur1) * 100, 1) : null,
            ];
        }

        return [
            'type'    => $type,
            'annee_1' => ['id' => $anneeScolaireId1, 'donnees' => $donnees1],
            'annee_2' => ['id' => $anneeScolaireId2, 'donnees' => $donnees2],
            'ecarts'  => $ecarts,
        ];
    }

    private function donneesPourComparaison(int $anneeScolaireId, string $type): array
    {
        $snapshot = InstantaneStatistique::where('annee_scolaire_id', $anneeScolaireId)
            ->where('type', $type)
            ->orderByDesc('date_snapshot')
            ->first();

        return $snapshot ? $snapshot->donnees : $this->calculerDonneesType($anneeScolaireId, $type);
    }

    private function calculerDonneesType(int $anneeScolaireId, string $type): array
    {
        return match ($type) {
            'effectifs'   => $this->effectifsGeneraux($anneeScolaireId),
            'financier'   => $this->resumeFinancier($anneeScolaireId),
            'pedagogique' => $this->resumeResultatsScolaires($anneeScolaireId),
            default       => throw new \InvalidArgumentException("Type d'instantané inconnu : {$type}"),
        };
    }
}
