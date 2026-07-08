<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Note;
use App\Models\Absence;
use App\Models\Paiement;
use App\Models\Eleve;
use App\Models\NotificationAttente;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $utilisateur = $request->user();
        $role        = $utilisateur->role;
        $ecoleId     = $utilisateur->ecole_id;

        return match ($role) {
            'enseignant'  => $this->dashboardEnseignant($utilisateur),
            'censeur'     => $this->dashboardCenseur($ecoleId),
            'secretaire'  => $this->dashboardSecretaire($ecoleId),
            default       => response()->json(['message' => 'Rôle non supporté'], 403),
        };
    }

    // ── Dashboard Enseignant ──────────────────────────────
    private function dashboardEnseignant($utilisateur)
    {
        $enseignantId = $utilisateur->id;

        // Mes classes et matières affectées
        $affectations = DB::table('enseignant_classe_matiere')
            ->where('enseignant_id', $enseignantId)
            ->join('classes',  'classes.id',  '=', 'enseignant_classe_matiere.classe_id')
            ->join('matieres', 'matieres.id', '=', 'enseignant_classe_matiere.matiere_id')
            ->select(
                'enseignant_classe_matiere.id',
                'classes.id as classe_id',
                'classes.nom as classe_nom',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
                'matieres.coefficient',
            )
            ->get();

        // Mes notes par statut
        $notesParStatut = Note::where('enseignant_id', $enseignantId)
            ->select('statut', DB::raw('count(*) as total'))
            ->groupBy('statut')
            ->pluck('total', 'statut');

        // Mes absences marquées aujourd'hui
        $absencesAujourdhui = Absence::where('marque_par', $enseignantId)
            ->where('date_absence', now()->format('Y-m-d'))
            ->with('eleve')
            ->get();

        // Notes rejetées récentes (à corriger)
        $notesRejetees = Note::where('enseignant_id', $enseignantId)
            ->where('statut', 'rejete')
            ->with(['eleve', 'matiere', 'periode'])
            ->orderBy('updated_at', 'desc')
            ->take(5)
            ->get();

        return response()->json([
            'role'         => 'enseignant',
            'affectations' => $affectations,
            'notes'        => [
                'brouillon' => $notesParStatut['brouillon'] ?? 0,
                'soumis'    => $notesParStatut['soumis']    ?? 0,
                'valide'    => $notesParStatut['valide']    ?? 0,
                'rejete'    => $notesParStatut['rejete']    ?? 0,
            ],
            'absences_aujourdhui' => $absencesAujourdhui,
            'notes_rejetees'      => $notesRejetees,
        ]);
    }

    // ── Dashboard Censeur ─────────────────────────────────
    private function dashboardCenseur($ecoleId)
    {
        // Notes en attente de validation
        $notesASoumettre = Note::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->where('statut', 'soumis')
            ->with(['eleve', 'matiere', 'enseignant'])
            ->orderBy('updated_at', 'desc')
            ->take(10)
            ->get();

        $totalNotesASoumettre = Note::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->where('statut', 'soumis')
            ->count();

        // Absences du jour
        $absencesAujourdhui = Absence::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->where('date_absence', now()->format('Y-m-d'))
            ->with(['eleve', 'classe'])
            ->get();

        // Absences de la semaine par classe
        $absencesSemaine = DB::table('absences')
            ->join('eleves',  'eleves.id',  '=', 'absences.eleve_id')
            ->join('classes', 'classes.id', '=', 'absences.classe_id')
            ->where('eleves.ecole_id', $ecoleId)
            ->whereBetween('absences.date_absence', [
                now()->startOfWeek()->format('Y-m-d'),
                now()->endOfWeek()->format('Y-m-d'),
            ])
            ->select('classes.nom', DB::raw('count(*) as total'))
            ->groupBy('classes.id', 'classes.nom')
            ->orderBy('total', 'desc')
            ->get();

        // Moyennes par classe (notes validées)
        $moyennesClasses = DB::table('notes')
            ->join('inscriptions', 'notes.eleve_id', '=', 'inscriptions.eleve_id')
            ->join('classes', 'inscriptions.classe_id', '=', 'classes.id')
            ->join('eleves', 'notes.eleve_id', '=', 'eleves.id')
            ->where('eleves.ecole_id', $ecoleId)
            ->where('notes.statut', 'valide')
            ->select('classes.nom', DB::raw('ROUND(AVG(notes.valeur), 2) as moyenne'))
            ->groupBy('classes.id', 'classes.nom')
            ->orderBy('moyenne', 'desc')
            ->get();

        // Notes en attente de validation, par classe
        $notesAValiderParClasse = DB::table('notes')
            ->join('inscriptions', 'notes.eleve_id', '=', 'inscriptions.eleve_id')
            ->join('classes', 'inscriptions.classe_id', '=', 'classes.id')
            ->join('eleves', 'notes.eleve_id', '=', 'eleves.id')
            ->where('eleves.ecole_id', $ecoleId)
            ->where('notes.statut', 'soumis')
            ->select('classes.id as classe_id', DB::raw('count(*) as total'))
            ->groupBy('classes.id')
            ->pluck('total', 'classe_id');

        return response()->json([
            'role'                       => 'censeur',
            'notes_a_valider'            => $notesASoumettre,
            'total_notes_a_valider'      => $totalNotesASoumettre,
            'notes_a_valider_par_classe' => $notesAValiderParClasse,
            'absences_aujourdhui'        => $absencesAujourdhui,
            'absences_semaine'           => $absencesSemaine,
            'moyennes_classes'           => $moyennesClasses,
        ]);
    }

    // ── Dashboard Secrétaire ──────────────────────────────
    private function dashboardSecretaire($ecoleId)
    {
        // Total encaissé aujourd'hui
        $encaisseAujourdhui = Paiement::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->where('date_paiement', now()->format('Y-m-d'))
            ->sum('montant');

        // Total encaissé ce mois
        $encaisseMois = Paiement::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->whereMonth('date_paiement', now()->month)
            ->whereYear('date_paiement', now()->year)
            ->sum('montant');

        // Derniers paiements (5)
        $derniersPaiements = Paiement::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->with('eleve')
            ->orderBy('created_at', 'desc')
            ->take(5)
            ->get();

        // Notifications en attente
        $notificationsEnAttente = NotificationAttente::where('ecole_id', $ecoleId)
            ->where('statut', 'en_attente')
            ->select('type', DB::raw('count(*) as total'))
            ->groupBy('type')
            ->pluck('total', 'type');

        $totalNotifications = NotificationAttente::where('ecole_id', $ecoleId)
            ->where('statut', 'en_attente')
            ->count();

        // Total élèves
        $totalEleves = Eleve::where('ecole_id', $ecoleId)->count();

        return response()->json([
            'role'                  => 'secretaire',
            'encaisse_aujourdhui'   => $encaisseAujourdhui,
            'encaisse_mois'         => $encaisseMois,
            'derniers_paiements'    => $derniersPaiements,
            'notifications'         => [
                'total'    => $totalNotifications,
                'absence'  => $notificationsEnAttente['absence']  ?? 0,
                'paiement' => $notificationsEnAttente['paiement'] ?? 0,
                'bulletin' => $notificationsEnAttente['bulletin'] ?? 0,
            ],
            'total_eleves' => $totalEleves,
        ]);
    }
}