<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HistoriqueValidationNote;
use App\Models\SaisieNote;
use App\Models\VerrouillageNote;
use App\Services\NoteCalculService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ValidationNoteController extends Controller
{
    public function __construct(private NoteCalculService $noteCalcul)
    {
    }

    // GET /notes/validation/en-attente
    public function enAttente(Request $request)
    {
        $this->autoriserGestionnaire($request);

        $saisies = SaisieNote::where('statut', 'en_attente_validation')
            ->with(['classe:id,nom', 'matiere:id,nom', 'enseignant:id,name'])
            ->orderBy('date_soumission')
            ->get();

        $resultat = $saisies->map(function (SaisieNote $saisie) {
            $anomalies = $this->noteCalcul->detecterAnomalies($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id);

            return [
                'id' => $saisie->id,
                'classe_id' => $saisie->classe_id,
                'classe_nom' => $saisie->classe->nom,
                'matiere_id' => $saisie->matiere_id,
                'matiere_nom' => $saisie->matiere->nom,
                'enseignant_id' => $saisie->enseignant_id,
                'enseignant_nom' => $saisie->enseignant->name,
                'date_soumission' => $saisie->date_soumission,
                'nombre_notes' => $saisie->notes()->count(),
                'moyenne_classe' => $this->noteCalcul->moyenneMatiere($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id),
                'nombre_anomalies' => count($anomalies),
                'anomalies_apercu' => collect($anomalies)->take(2)->values(),
            ];
        });

        return response()->json(['saisies' => $resultat]);
    }

    // GET /notes/validation/{saisieId}
    public function detail(Request $request, $saisieId)
    {
        $this->autoriserGestionnaire($request);

        $saisie = SaisieNote::with(['classe:id,nom', 'matiere:id,nom', 'periode:id,nom', 'enseignant:id,name'])
            ->findOrFail($saisieId);

        $notes = $saisie->notes()->with('eleve:id,nom,prenom,matricule')->orderBy('eleve_id')->get();

        return response()->json([
            'saisie' => $saisie,
            'notes' => $notes,
            'statistiques' => [
                'moyenne_classe' => $this->noteCalcul->moyenneMatiere($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id),
                'meilleure_note' => $this->noteCalcul->meilleureNote($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id),
                'plus_faible_note' => $this->noteCalcul->plusFaibleNote($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id),
                'taux_reussite' => $this->noteCalcul->tauxReussite($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id),
            ],
            'anomalies' => $this->noteCalcul->detecterAnomalies($saisie->classe_id, $saisie->matiere_id, $saisie->periode_id),
            'historique' => $saisie->historiqueValidations()->with('effectuePar:id,name')->orderByDesc('created_at')->get(),
        ]);
    }

    // POST /notes/validation/{saisieId}/valider
    public function valider(Request $request, $saisieId)
    {
        $this->autoriserGestionnaire($request);

        $saisie = SaisieNote::findOrFail($saisieId);

        if ($saisie->statut !== 'en_attente_validation') {
            return response()->json([
                'message' => "Cette saisie n'est pas en attente de validation (statut actuel : {$saisie->statut}).",
            ], 422);
        }

        $utilisateur = $request->user();

        DB::transaction(function () use ($saisie, $utilisateur) {
            $saisie->notes()->update([
                'statut' => 'validee',
                'valide_par' => $utilisateur->id,
                'date_validation' => now(),
            ]);

            $saisie->update(['statut' => 'validee']);

            VerrouillageNote::create([
                'saisie_note_id' => $saisie->id,
                'verrouille' => true,
            ]);

            HistoriqueValidationNote::create([
                'saisie_note_id' => $saisie->id,
                'action' => 'validation',
                'effectue_par' => $utilisateur->id,
            ]);
        });

        return response()->json([
            'message' => 'Saisie validée avec succès',
            'saisie' => $saisie->fresh(),
        ]);
    }

    // POST /notes/validation/{saisieId}/rejeter
    public function rejeter(Request $request, $saisieId)
    {
        $this->autoriserGestionnaire($request);

        $data = $request->validate([
            'motif' => 'required|string|max:1000',
        ]);

        $saisie = SaisieNote::findOrFail($saisieId);

        if ($saisie->statut !== 'en_attente_validation') {
            return response()->json([
                'message' => "Cette saisie n'est pas en attente de validation (statut actuel : {$saisie->statut}).",
            ], 422);
        }

        $utilisateur = $request->user();

        DB::transaction(function () use ($saisie, $utilisateur, $data) {
            // Les notes repassent en brouillon pour que l'enseignant puisse
            // les corriger (cf. Note::modifiable, qui exige statut=brouillon).
            $saisie->notes()->update([
                'statut' => 'brouillon',
                'motif_rejet' => $data['motif'],
            ]);

            $saisie->update(['statut' => 'rejetee']);

            // "Notifier l'enseignant" : pas de système de notification
            // dédié pour l'instant. Cette ligne d'historique, associée au
            // motif_rejet désormais présent sur chaque note, sert de trace
            // consultable par l'enseignant (via /notes/saisie/progression
            // et /notes/validation/{id} côté direction).
            HistoriqueValidationNote::create([
                'saisie_note_id' => $saisie->id,
                'action' => 'rejet',
                'effectue_par' => $utilisateur->id,
                'motif' => $data['motif'],
            ]);
        });

        return response()->json([
            'message' => 'Saisie rejetée',
            'saisie' => $saisie->fresh(),
        ]);
    }

    // GET /notes/validation/historique
    public function historique(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'nullable|integer',
            'matiere_id' => 'nullable|integer',
            'periode_id' => 'nullable|integer',
            'action' => 'nullable|in:soumission,validation,rejet,deverrouillage',
            'date_debut' => 'nullable|date',
            'date_fin' => 'nullable|date',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $historique = HistoriqueValidationNote::whereHas('saisieNote', function ($q) use ($ecoleId, $data) {
                $q->where('ecole_id', $ecoleId);
                if (!empty($data['classe_id'])) {
                    $q->where('classe_id', $data['classe_id']);
                }
                if (!empty($data['matiere_id'])) {
                    $q->where('matiere_id', $data['matiere_id']);
                }
                if (!empty($data['periode_id'])) {
                    $q->where('periode_id', $data['periode_id']);
                }
            })
            ->when(!empty($data['action']), fn ($q) => $q->where('action', $data['action']))
            ->when(!empty($data['date_debut']), fn ($q) => $q->whereDate('created_at', '>=', $data['date_debut']))
            ->when(!empty($data['date_fin']), fn ($q) => $q->whereDate('created_at', '<=', $data['date_fin']))
            ->with([
                'effectuePar:id,name',
                'saisieNote.classe:id,nom',
                'saisieNote.matiere:id,nom',
                'saisieNote.periode:id,nom',
            ])
            ->orderByDesc('created_at')
            ->paginate(30);

        return response()->json($historique);
    }

    private function autoriserGestionnaire(Request $request): void
    {
        abort_unless(in_array($request->user()->role, ['directeur', 'censeur']), 403,
            'Seuls le directeur ou le censeur peuvent effectuer cette action.');
    }
}
