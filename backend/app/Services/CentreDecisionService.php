<?php

namespace App\Services;

use App\Http\Controllers\Api\AnalysePerformanceController;
use App\Http\Controllers\Api\DashboardEmploiDuTempsController;
use App\Models\Inscription;
use App\Models\PeriodeAcademique;
use App\Models\SaisieNote;
use Illuminate\Http\Request;

/**
 * Analyse les données déjà calculées par les autres services statistiques
 * (Frais, Notes, Emploi du temps) et en dérive une liste d'alertes
 * actionnables pour le tableau de bord du directeur.
 *
 * Chaque règle vit dans sa propre méthode privée verifierXxx(), qui rend
 * une alerte (array) ou null/[] si rien à signaler, pour rester testable
 * indépendamment des autres règles.
 */
class CentreDecisionService
{
    public function __construct(
        private FraisCalculService $fraisCalcul,
        private NoteCalculService $noteCalcul,
        private StatistiquePedagogiqueService $statistiquePedagogique,
        private AnalysePerformanceController $analysePerformance,
        private DashboardEmploiDuTempsController $dashboardEmploiDuTemps,
    ) {
    }

    // $request est nécessaire ici (et pas seulement anneeScolaireId/periodeId)
    // car deux règles réutilisent directement des méthodes déjà écrites pour
    // les contrôleurs Notes et Emploi du temps, qui attendent un Request
    // (utilisateur connecté + filtres classe_id/niveau).
    public function genererAlertes(
        Request $request,
        int $anneeScolaireId,
        int $periodeId,
        int $seuilPaiementRetard = 20
    ): array {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas(
            'annee',
            fn ($q) => $q->where('ecole_id', $ecoleId)->where('id', $anneeScolaireId)
        )->findOrFail($periodeId);

        $alertes = [];

        if ($alerte = $this->verifierPaiementsRetard($ecoleId, $anneeScolaireId, $seuilPaiementRetard)) {
            $alertes[] = $alerte;
        }

        if ($alerte = $this->verifierSaisieNotes($request, $periode)) {
            $alertes[] = $alerte;
        }

        $alertes = array_merge($alertes, $this->verifierBaissePerformance($ecoleId, $periode));

        if ($alerte = $this->verifierRisqueRedoublement($ecoleId, $periode)) {
            $alertes[] = $alerte;
        }

        if ($alerte = $this->verifierClotureProche($periode)) {
            $alertes[] = $alerte;
        }

        $alertes = array_merge($alertes, $this->verifierEmploiDuTemps($request));

        return $alertes;
    }

    // ── Élèves non à jour de paiement ──────────────────────────────
    private function verifierPaiementsRetard(int $ecoleId, int $anneeScolaireId, int $seuil): ?array
    {
        $rapport = $this->fraisCalcul->rapportEcole($ecoleId, $anneeScolaireId);
        $nombre = count($rapport['debiteurs']);

        if ($nombre <= $seuil) {
            return null;
        }

        return [
            'type'         => 'warning',
            'titre'        => 'Élèves non à jour de paiement',
            'description'  => "{$nombre} élèves ne sont pas à jour de leurs frais scolaires.",
            'valeur'       => $nombre,
            'action'       => 'Voir la liste',
            'route_action' => '/statistiques/paiements/eleves-non-en-regle?annee_scolaire_id=' . $anneeScolaireId,
        ];
    }

    // ── Saisie de notes incomplète ─────────────────────────────────
    private function verifierSaisieNotes(Request $request, PeriodeAcademique $periode): ?array
    {
        if (!$periode->date_fin) {
            return null;
        }

        $joursRestants = (int) now()->startOfDay()->diffInDays($periode->date_fin, false);

        // On n'alerte que si la période se termine dans moins d'une semaine
        // ou est déjà terminée — sinon la saisie est encore normalement en cours.
        if ($joursRestants > 7) {
            return null;
        }

        if ($joursRestants < 0) {
            // Période déjà terminée : réutilise directement la détection
            // déjà établie dans le module Notes.
            $enseignantsConcernes = $this->analysePerformance
                ->calculerEnseignantsEnRetard($request, $periode)
                ->pluck('enseignant_id')
                ->unique();
        } else {
            // Avant échéance, calculerEnseignantsEnRetard() se limite
            // volontairement à l'après-échéance et renverrait toujours une
            // liste vide : on compte ici directement les saisies non
            // terminées pour anticiper l'alerte pendant la semaine qui
            // précède la clôture.
            $enseignantsConcernes = SaisieNote::where('ecole_id', $request->user()->ecole_id)
                ->where('periode_id', $periode->id)
                ->whereIn('statut', ['en_cours', 'rejetee'])
                ->pluck('enseignant_id')
                ->unique();
        }

        if ($enseignantsConcernes->isEmpty()) {
            return null;
        }

        $nombre = $enseignantsConcernes->count();

        return [
            'type'         => 'warning',
            'titre'        => 'Saisie de notes incomplète',
            'description'  => "{$nombre} enseignant(s) n'ont pas terminé la saisie des notes pour la période {$periode->nom}.",
            'valeur'       => $nombre,
            'action'       => 'Voir les enseignants concernés',
            'route_action' => '/notes/analyse/enseignants-en-retard?periode_id=' . $periode->id,
        ];
    }

    // ── Classe(s) en baisse de performance ─────────────────────────
    // Retourne un tableau (potentiellement plusieurs classes concernées).
    private function verifierBaissePerformance(int $ecoleId, PeriodeAcademique $periode): array
    {
        $periodePrecedente = PeriodeAcademique::where('annee_academique_id', $periode->annee_academique_id)
            ->where('ordre', $periode->ordre - 1)
            ->first();

        if (!$periodePrecedente) {
            return [];
        }

        $actuelles = collect($this->statistiquePedagogique->parClasse($ecoleId, $periode->id))->keyBy('classe_id');
        $precedentes = collect($this->statistiquePedagogique->parClasse($ecoleId, $periodePrecedente->id))->keyBy('classe_id');

        $alertes = [];

        foreach ($actuelles as $classeId => $donnees) {
            $moyenneActuelle = $donnees['moyenne_generale'];
            $moyennePrecedente = $precedentes->get($classeId)['moyenne_generale'] ?? null;

            if ($moyenneActuelle === null || $moyennePrecedente === null) {
                continue;
            }

            $baisse = round($moyennePrecedente - $moyenneActuelle, 2);

            if ($baisse > 2) {
                $alertes[] = [
                    'type'         => 'warning',
                    'titre'        => 'Baisse de performance',
                    'description'  => "Classe de {$donnees['classe_nom']} : moyenne de {$moyenneActuelle}/20, en baisse de {$baisse} points par rapport à la période précédente.",
                    'valeur'       => $baisse,
                    'action'       => 'Voir la classe',
                    'route_action' => '/statistiques/pedagogique/par-classe?periode_id=' . $periode->id,
                ];
            }
        }

        return $alertes;
    }

    // ── Élèves à risque de redoublement ────────────────────────────
    // Moyenne générale < 8 sur la période actuelle ET (si elle existe) sur
    // la période consécutive précédente ; si aucune période précédente
    // n'existe encore, la période actuelle seule suffit.
    private function verifierRisqueRedoublement(int $ecoleId, PeriodeAcademique $periode): ?array
    {
        $periodePrecedente = PeriodeAcademique::where('annee_academique_id', $periode->annee_academique_id)
            ->where('ordre', $periode->ordre - 1)
            ->first();

        $elevesIds = Inscription::where('annee_academique_id', $periode->annee_academique_id)
            ->whereHas('eleve', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->pluck('eleve_id');

        $nombreARisque = 0;

        foreach ($elevesIds as $eleveId) {
            $moyenneActuelle = $this->noteCalcul->moyenneEleve($eleveId, $periode->id);

            if ($moyenneActuelle === null || $moyenneActuelle >= 8) {
                continue;
            }

            if ($periodePrecedente) {
                $moyennePrecedente = $this->noteCalcul->moyenneEleve($eleveId, $periodePrecedente->id);
                if ($moyennePrecedente === null || $moyennePrecedente >= 8) {
                    continue;
                }
            }

            $nombreARisque++;
        }

        if ($nombreARisque === 0) {
            return null;
        }

        return [
            'type'         => 'danger',
            'titre'        => 'Élèves à risque de redoublement',
            'description'  => "{$nombreARisque} élève(s) risquent de redoubler selon leurs résultats actuels.",
            'valeur'       => $nombreARisque,
            'action'       => 'Voir la liste',
            'route_action' => '/statistiques/pedagogique/eleves-en-difficulte?periode_id=' . $periode->id . '&seuil=8',
        ];
    }

    // ── Clôture de période proche ───────────────────────────────────
    private function verifierClotureProche(PeriodeAcademique $periode): ?array
    {
        if (!$periode->date_fin || $periode->statut !== 'ouverte') {
            return null;
        }

        $joursRestants = (int) now()->startOfDay()->diffInDays($periode->date_fin, false);

        if ($joursRestants < 0 || $joursRestants > 7) {
            return null;
        }

        return [
            'type'         => 'info',
            'titre'        => 'Clôture de période proche',
            'description'  => "La clôture de la période {$periode->nom} approche ({$periode->date_fin->format('d/m/Y')}).",
            'valeur'       => $joursRestants,
            'action'       => 'Voir la période',
            'route_action' => '/annees/' . $periode->annee_academique_id . '/statistiques',
        ];
    }

    // ── Emploi du temps (incomplets + conflits) ────────────────────
    // Retourne un tableau (0, 1 ou 2 alertes selon ce qui est détecté).
    private function verifierEmploiDuTemps(Request $request): array
    {
        $resume = $this->dashboardEmploiDuTemps->resume($request)->getData(true);

        $alertes = [];

        $nombreIncomplets = $resume['nombre_emplois_incomplets'] ?? 0;
        if ($nombreIncomplets > 0) {
            $alertes[] = [
                'type'         => 'warning',
                'titre'        => 'Emplois du temps incomplets',
                'description'  => "{$nombreIncomplets} emploi(s) du temps n'atteignent pas le volume horaire attendu.",
                'valeur'       => $nombreIncomplets,
                'action'       => 'Voir les emplois du temps',
                'route_action' => '/emploi-du-temps/dashboard/resume?periode_id=' . $request->input('periode_id'),
            ];
        }

        $nombreConflits = $resume['nombre_conflits'] ?? 0;
        if ($nombreConflits > 0) {
            $alertes[] = [
                'type'         => 'danger',
                'titre'        => "Conflits d'emploi du temps",
                'description'  => "{$nombreConflits} séance(s) en conflit (créneau, enseignant ou salle) non résolues.",
                'valeur'       => $nombreConflits,
                'action'       => 'Voir les conflits',
                'route_action' => '/emploi-du-temps/dashboard/resume?periode_id=' . $request->input('periode_id'),
            ];
        }

        return $alertes;
    }
}
