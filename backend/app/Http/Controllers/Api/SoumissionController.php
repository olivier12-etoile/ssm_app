<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Eleve;
use App\Models\HistoriqueValidationNote;
use App\Models\SaisieNote;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SoumissionController extends Controller
{
    // POST /notes/saisie/{id}/soumettre
    // Termine la saisie et la transmet à la direction pour validation.
    // Bloque si toutes les notes de la classe (devoir + composition, pour
    // chaque élève) ne sont pas encore saisies.
    public function soumettre(Request $request, $id)
    {
        $saisie = SaisieNote::findOrFail($id);
        $utilisateur = $request->user();

        if ($saisie->enseignant_id !== $utilisateur->id && !in_array($utilisateur->role, ['directeur', 'censeur'])) {
            return response()->json(['message' => "Vous n'êtes pas autorisé à soumettre cette saisie."], 403);
        }

        if (!in_array($saisie->statut, ['en_cours', 'rejetee'])) {
            return response()->json(['message' => 'Cette saisie a déjà été soumise ou validée.'], 422);
        }

        if ($saisie->estVerrouillee()) {
            return response()->json(['message' => 'Cette saisie est verrouillée.'], 403);
        }

        $elevesIncomplets = $this->elevesIncomplets($saisie);

        if ($elevesIncomplets->isNotEmpty()) {
            return response()->json([
                'message' => "Impossible de soumettre : {$elevesIncomplets->count()} élève(s) n'ont pas toutes leurs notes saisies (devoir et composition).",
                'eleves_incomplets' => $elevesIncomplets->values(),
            ], 422);
        }

        DB::transaction(function () use ($saisie, $utilisateur) {
            $saisie->update([
                'statut' => 'en_attente_validation',
                'date_soumission' => now(),
            ]);

            HistoriqueValidationNote::create([
                'saisie_note_id' => $saisie->id,
                'action' => 'soumission',
                'effectue_par' => $utilisateur->id,
            ]);
        });

        return response()->json([
            'message' => 'Notes soumises pour validation avec succès',
            'saisie' => $saisie->fresh(),
        ]);
    }

    private function elevesIncomplets(SaisieNote $saisie)
    {
        $eleves = Eleve::where('ecole_id', $saisie->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q
                ->where('classe_id', $saisie->classe_id)
                ->where('annee_academique_id', $saisie->annee_scolaire_id))
            ->orderBy('nom')
            ->get();

        $notesParEleve = $saisie->notes()->get()->groupBy('eleve_id');

        return $eleves
            ->filter(function (Eleve $eleve) use ($notesParEleve) {
                $types = $notesParEleve->get($eleve->id, collect())->pluck('type_evaluation');
                return !$types->contains('devoir') || !$types->contains('composition');
            })
            ->map(fn (Eleve $eleve) => [
                'eleve_id' => $eleve->id,
                'nom' => $eleve->nom,
                'prenom' => $eleve->prenom,
            ]);
    }
}
