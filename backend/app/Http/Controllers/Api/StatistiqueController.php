<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
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

        // Effectifs
        $totalEleves = Eleve::where('ecole_id', $ecoleId)->count();
        $totalGarcons = Eleve::where('ecole_id', $ecoleId)
            ->where('sexe', 'M')->count();
        $totalFilles = Eleve::where('ecole_id', $ecoleId)
            ->where('sexe', 'F')->count();

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
            ->select('classes.nom', DB::raw('ROUND(AVG(notes.valeur), 2) as moyenne'))
            ->groupBy('classes.id', 'classes.nom')
            ->get();

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
                'total'       => $totalEleves,
                'garcons'     => $totalGarcons,
                'filles'      => $totalFilles,
                'enseignants' => $totalEnseignants,
                'classes'     => $totalClasses,
            ],
            'finances' => [
                'total_encaisse'  => $totalEncaisse,
                'paiements_mois'  => $paiementsParMois,
            ],
            'notes' => [
                'par_statut'      => $notesParStatut,
                'moyennes_classes' => $moyennesClasses,
            ],
        ]);
    }
}