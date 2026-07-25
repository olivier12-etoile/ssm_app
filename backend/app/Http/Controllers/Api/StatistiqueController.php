<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Eleve;
use App\Models\User;
use App\Models\Note;
use App\Models\Paiement;
use App\Models\Inscription;
use App\Models\Classe;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StatistiqueController extends Controller
{
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $anneeId = $request->query('annee_id');
        $periodeId = $request->query('periode_id');

        // Effectifs
        $totalEleves = Eleve::where('ecole_id', $ecoleId)->count();
        $totalGarcons = Eleve::where('ecole_id', $ecoleId)
            ->where('sexe', 'M')->count();
        $totalFilles = Eleve::where('ecole_id', $ecoleId)
            ->where('sexe', 'F')->count();
        $nouveauxCeMois = Eleve::where('ecole_id', $ecoleId)
            ->whereMonth('created_at', now()->month)
            ->whereYear('created_at', now()->year)
            ->count();

        // Utilisateurs
        $totalEnseignants = User::where('ecole_id', $ecoleId)
            ->where('role', 'enseignant')->count();

        // Classes
        $totalClasses = Classe::where('ecole_id', $ecoleId)->count();

        // Paiements
        $totalEncaisse = Paiement::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->when($anneeId, fn($q) => $q->where('annee_academique_id', $anneeId))
            ->sum('montant');

        // Notes par statut
        $notesParStatut = Note::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->when($anneeId, function ($q) use ($anneeId) {
                $q->whereHas('periode', function ($q2) use ($anneeId) {
                    $q2->whereHas('annee', function ($q3) use ($anneeId) {
                        $q3->where('id', $anneeId);
                    });
                });
            })
            ->when($periodeId, fn($q) => $q->where('periode_id', $periodeId))
            ->select('statut', DB::raw('count(*) as total'))
            ->groupBy('statut')
            ->pluck('total', 'statut');

        // Moyenne générale par classe
        $moyennesClasses = DB::table('notes')
            ->join('inscriptions', function ($join) {
                $join->on('notes.eleve_id', '=', 'inscriptions.eleve_id');
            })
            ->join('classes', 'inscriptions.classe_id', '=', 'classes.id')
            ->join('eleves', 'notes.eleve_id', '=', 'eleves.id')
            ->where('eleves.ecole_id', $ecoleId)
            ->where('notes.statut', 'valide')
            ->when($anneeId, fn($q) => $q->where('inscriptions.annee_academique_id', $anneeId))
            ->when($periodeId, fn($q) => $q->where('notes.periode_id', $periodeId))
            ->select('classes.id as classe_id', 'classes.nom', DB::raw('ROUND(AVG(notes.valeur), 2) as moyenne'))
            ->groupBy('classes.id', 'classes.nom')
            ->orderByDesc('moyenne')
            ->get();

        // Moyenne générale par matière
        $moyennesMatieres = DB::table('notes')
            ->join('eleves', 'notes.eleve_id', '=', 'eleves.id')
            ->join('matieres', 'notes.matiere_id', '=', 'matieres.id')
            ->where('eleves.ecole_id', $ecoleId)
            ->where('notes.statut', 'valide')
            ->when($anneeId, function ($q) use ($anneeId) {
                $q->whereExists(function ($sub) use ($anneeId) {
                    $sub->selectRaw('1')
                        ->from('periodes_academiques')
                        ->whereColumn('periodes_academiques.id', 'notes.periode_id')
                        ->where('periodes_academiques.annee_academique_id', $anneeId);
                });
            })
            ->when($periodeId, fn($q) => $q->where('notes.periode_id', $periodeId))
            ->select('matieres.nom', DB::raw('ROUND(AVG(notes.valeur), 2) as moyenne'))
            ->groupBy('matieres.id', 'matieres.nom')
            ->orderByDesc('moyenne')
            ->get();

        // Taux de réussite (part des notes validées ≥ 10/20)
        $notesValidees = Note::whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('statut', 'valide')
            ->when($anneeId, function ($q) use ($anneeId) {
                $q->whereExists(function ($sub) use ($anneeId) {
                    $sub->selectRaw('1')
                        ->from('periodes_academiques')
                        ->whereColumn('periodes_academiques.id', 'notes.periode_id')
                        ->where('periodes_academiques.annee_academique_id', $anneeId);
                });
            })
            ->when($periodeId, fn($q) => $q->where('periode_id', $periodeId))
            ->get(['valeur']);

        $tauxReussite = $notesValidees->isEmpty()
            ? 0
            : round($notesValidees->where('valeur', '>=', 10)->count() / $notesValidees->count() * 100, 1);

        // Effectif par classe (avec capacité max, pour le graphique en barres)
        $effectifsParClasse = Classe::where('ecole_id', $ecoleId)
            ->when($anneeId, fn($q) => $q->where('annee_academique_id', $anneeId))
            ->withCount('inscriptions')
            ->orderBy('nom')
            ->get()
            ->map(fn($c) => [
                'classe_id'    => $c->id,
                'nom'          => $c->nom,
                'effectif'     => $c->inscriptions_count,
                'capacite_max' => $c->capacite_max,
            ]);

        // Absences par semaine (4 dernières semaines)
        $absencesParSemaine = [];
        for ($i = 3; $i >= 0; $i--) {
            $debutSemaine = now()->subWeeks($i)->startOfWeek();
            $finSemaine   = now()->subWeeks($i)->endOfWeek();

            $requeteBase = Absence::whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                ->whereBetween('date_absence', [$debutSemaine->format('Y-m-d'), $finSemaine->format('Y-m-d')]);

            $absencesParSemaine[] = [
                'semaine'        => 'S' . $debutSemaine->format('W'),
                'debut'          => $debutSemaine->format('Y-m-d'),
                'total'          => (clone $requeteBase)->count(),
                'non_justifiees' => (clone $requeteBase)->where('justifiee', false)->count(),
            ];
        }

        // Élèves les plus absents (top 5, plus de 3 absences non justifiées)
        $topAbsences = Absence::where('justifiee', false)
            ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->select('eleve_id', DB::raw('count(*) as total_absences'))
            ->groupBy('eleve_id')
            ->having('total_absences', '>', 3)
            ->orderByDesc('total_absences')
            ->limit(5)
            ->get();

        $elevesPlusAbsents = $topAbsences->map(function ($row) use ($anneeId) {
            $eleve = Eleve::find($row->eleve_id);
            if (!$eleve) {
                return null;
            }
            $inscription = Inscription::where('eleve_id', $eleve->id)
                ->when($anneeId, fn($q) => $q->where('annee_academique_id', $anneeId))
                ->with('classe')
                ->latest('id')
                ->first();

            return [
                'eleve_id'       => $eleve->id,
                'nom'            => $eleve->nom,
                'prenom'         => $eleve->prenom,
                'photo_url'      => $eleve->photo_url,
                'classe_nom'     => $inscription?->classe?->nom,
                'total_absences' => $row->total_absences,
            ];
        })->filter()->values();

        // Paiements par mois (6 derniers mois)
        $paiementsParMois = Paiement::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->where('date_paiement', '>=', now()->subMonths(6))
            ->select(
                DB::raw('MONTH(date_paiement) as mois'),
                DB::raw('YEAR(date_paiement) as annee'),
                DB::raw('SUM(montant) as total')
            )
            ->groupBy('annee', 'mois')
            ->orderBy('annee')
            ->orderBy('mois')
            ->get();

        return response()->json([
            'effectifs' => [
                'total'          => $totalEleves,
                'garcons'        => $totalGarcons,
                'filles'         => $totalFilles,
                'enseignants'    => $totalEnseignants,
                'classes'        => $totalClasses,
                'nouveaux_ce_mois' => $nouveauxCeMois,
                'par_classe'     => $effectifsParClasse,
            ],
            'finances' => [
                'total_encaisse'  => $totalEncaisse,
                'paiements_mois'  => $paiementsParMois,
            ],
            'notes' => [
                'par_statut'        => $notesParStatut,
                'moyennes_classes'  => $moyennesClasses,
                'moyennes_matieres' => $moyennesMatieres,
                'taux_reussite'     => $tauxReussite,
            ],
            'assiduite' => [
                'par_semaine'    => $absencesParSemaine,
                'plus_absents'   => $elevesPlusAbsents,
            ],
        ]);
    }
}