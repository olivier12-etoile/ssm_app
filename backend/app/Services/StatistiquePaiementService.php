<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Eleve;
use App\Models\Paiement;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * Statistiques financières ventilées par classe, niveau et mois, et liste
 * des élèves non en règle. Réutilise entièrement FraisCalculService pour
 * les calculs de situation financière (jamais de recalcul manuel des
 * montants dus/payés ici).
 */
class StatistiquePaiementService
{
    private const MOIS_FR = [
        1 => 'Janvier', 2 => 'Février', 3 => 'Mars', 4 => 'Avril',
        5 => 'Mai', 6 => 'Juin', 7 => 'Juillet', 8 => 'Août',
        9 => 'Septembre', 10 => 'Octobre', 11 => 'Novembre', 12 => 'Décembre',
    ];

    public function __construct(private FraisCalculService $fraisCalcul)
    {
    }

    // Pour chaque classe : élèves à jour, en retard, montants et taux de recouvrement.
    public function parClasse(int $ecoleId, int $anneeScolaireId): array
    {
        $annee = $this->anneeEcole($ecoleId, $anneeScolaireId);

        return $this->situationsEcole($annee)
            ->groupBy(fn ($s) => $s['classe']?->id ?? 0)
            ->map(fn ($groupe) => $this->agregerSituations(
                $groupe,
                ['classe_id' => $groupe->first()['classe']?->id, 'classe_nom' => $groupe->first()['classe']?->nom ?? 'Non affecté']
            ))
            ->values()
            ->all();
    }

    // Agrégation par niveau (regroupe les classes de même niveau).
    public function parNiveau(int $ecoleId, int $anneeScolaireId): array
    {
        $annee = $this->anneeEcole($ecoleId, $anneeScolaireId);

        return $this->situationsEcole($annee)
            ->groupBy(fn ($s) => $s['classe']?->niveau ?? 'Non affecté')
            ->map(fn ($groupe, $niveau) => $this->agregerSituations($groupe, ['niveau' => $niveau]))
            ->values()
            ->all();
    }

    // Recettes encaissées mois par mois sur toute la durée de l'année scolaire.
    public function parMois(int $ecoleId, int $anneeScolaireId): array
    {
        $annee = $this->anneeEcole($ecoleId, $anneeScolaireId);

        $debut = Carbon::parse($annee->date_debut)->startOfMonth();
        $fin = Carbon::parse($annee->date_fin)->endOfMonth();

        $resultat = [];
        $mois = $debut->copy();

        while ($mois->lessThanOrEqualTo($fin)) {
            $montant = Paiement::whereHas('fraisScolaire', fn ($q) => $q->where('annee_scolaire_id', $annee->id))
                ->where('statut', 'valide')
                ->whereYear('date_paiement', $mois->year)
                ->whereMonth('date_paiement', $mois->month)
                ->sum('montant');

            $resultat[] = [
                'mois'    => $mois->format('Y-m'),
                'libelle' => self::MOIS_FR[$mois->month] . ' ' . $mois->year,
                'montant' => round((float) $montant, 2),
            ];

            $mois->addMonth();
        }

        return $resultat;
    }

    // Liste complète des élèves non à jour, avec filtres classe_id/niveau/montant_min.
    public function elevesNonEnRegle(Request $request): array
    {
        $ecoleId = $request->user()->ecole_id;

        $annee = $request->filled('annee_scolaire_id')
            ? AnneeAcademique::where('ecole_id', $ecoleId)->find((int) $request->annee_scolaire_id)
            : AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();

        if (!$annee) {
            return [];
        }

        $resultat = collect($this->elevesNonEnRegleListe(
            $annee,
            $request->filled('classe_id') ? (int) $request->classe_id : null,
            $request->input('niveau')
        ));

        if ($request->filled('montant_min')) {
            $seuil = (float) $request->montant_min;
            $resultat = $resultat->filter(fn ($e) => $e['reste_a_payer'] >= $seuil);
        }

        return $resultat->sortByDesc('reste_a_payer')->values()->all();
    }

    // Cœur de elevesNonEnRegle(), réutilisable sans Request (ex. rapport par
    // classe) : élèves de l'année donnée (filtrables par classe/niveau) dont
    // le reste à payer est strictement positif.
    public function elevesNonEnRegleListe(AnneeAcademique $annee, ?int $classeId = null, ?string $niveau = null): array
    {
        $eleves = Eleve::where('ecole_id', $annee->ecole_id)
            ->whereHas('inscriptions', function ($q) use ($annee, $classeId, $niveau) {
                $q->where('annee_academique_id', $annee->id);
                if ($classeId) {
                    $q->where('classe_id', $classeId);
                }
                if ($niveau) {
                    $q->whereHas('classe', fn ($q2) => $q2->where('niveau', $niveau));
                }
            })
            ->with(['inscriptions' => fn ($q) => $q->where('annee_academique_id', $annee->id)->with('classe')])
            ->get();

        return $eleves
            ->map(function (Eleve $eleve) use ($annee) {
                $classe = $eleve->inscriptions->first()?->classe;
                $situation = $this->fraisCalcul->situationEleve($eleve, $annee->id);

                return [
                    'eleve_id'         => $eleve->id,
                    'nom'              => $eleve->nom,
                    'prenom'           => $eleve->prenom,
                    'matricule'        => $eleve->matricule,
                    'classe_id'        => $classe?->id,
                    'classe_nom'       => $classe?->nom ?? 'Non affecté',
                    'telephone_parent' => $eleve->telephone_parent,
                    'montant_attendu'  => $situation['montant_attendu'],
                    'montant_paye'     => $situation['montant_paye'],
                    'reste_a_payer'    => $situation['reste_a_payer'],
                ];
            })
            ->filter(fn ($e) => $e['reste_a_payer'] > 0)
            ->sortByDesc('reste_a_payer')
            ->values()
            ->all();
    }

    // ── Aides internes ────────────────────────────────────────────

    private function situationsEcole(AnneeAcademique $annee): Collection
    {
        $eleves = Eleve::where('ecole_id', $annee->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q->where('annee_academique_id', $annee->id))
            ->with(['inscriptions' => fn ($q) => $q->where('annee_academique_id', $annee->id)->with('classe')])
            ->get();

        return $eleves->map(fn (Eleve $eleve) => [
            'eleve'     => $eleve,
            'classe'    => $eleve->inscriptions->first()?->classe,
            'situation' => $this->fraisCalcul->situationEleve($eleve, $annee->id),
        ]);
    }

    private function agregerSituations(Collection $groupe, array $entete): array
    {
        $attendu = $groupe->sum(fn ($s) => $s['situation']['montant_attendu']);
        $encaisse = $groupe->sum(fn ($s) => $s['situation']['montant_paye']);

        return array_merge($entete, [
            'nombre_eleves'     => $groupe->count(),
            'eleves_a_jour'     => $groupe->filter(fn ($s) => $s['situation']['reste_a_payer'] <= 0)->count(),
            'eleves_en_retard'  => $groupe->filter(fn ($s) => $s['situation']['reste_a_payer'] > 0)->count(),
            'montant_attendu'   => round($attendu, 2),
            'montant_encaisse'  => round($encaisse, 2),
            'reste_a_payer'     => round($attendu - $encaisse, 2),
            'taux_recouvrement' => $attendu > 0 ? round($encaisse / $attendu * 100, 1) : 0.0,
        ]);
    }

    private function anneeEcole(int $ecoleId, int $anneeScolaireId): AnneeAcademique
    {
        return AnneeAcademique::where('ecole_id', $ecoleId)->findOrFail($anneeScolaireId);
    }
}
