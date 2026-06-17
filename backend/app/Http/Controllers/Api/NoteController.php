<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Note;
use Illuminate\Http\Request;

class NoteController extends Controller
{
    // Notes d'une classe pour une période
    public function index(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'periode_id' => 'required|integer',
            'matiere_id' => 'required|integer',
        ]);

        $notes = Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->whereHas('eleve', function ($q) use ($request) {
                $q->whereHas('inscriptions', function ($q2) use ($request) {
                    $q2->where('classe_id', $request->classe_id);
                });
            })
            ->with('eleve')
            ->get();

        return response()->json($notes);
    }

    // Sauvegarder une note (brouillon)
    public function sauvegarder(Request $request)
    {
        $request->validate([
            'eleve_id'   => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
            'valeur'     => 'required|numeric|min:0|max:20',
        ]);

        $note = Note::updateOrCreate(
            [
                'eleve_id'    => $request->eleve_id,
                'matiere_id'  => $request->matiere_id,
                'periode_id'  => $request->periode_id,
            ],
            [
                'enseignant_id' => $request->user()->id,
                'valeur'        => $request->valeur,
                'statut'        => 'brouillon',
            ]
        );

        return response()->json([
            'message' => 'Note sauvegardée',
            'note'    => $note,
        ]);
    }

    // Soumettre les notes (enseignant verrouille)
    public function soumettre(Request $request)
    {
        $request->validate([
            'periode_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'classe_id'  => 'required|integer',
        ]);

        Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->where('enseignant_id', $request->user()->id)
            ->where('statut', 'brouillon')
            ->update(['statut' => 'soumis']);

        return response()->json(['message' => 'Notes soumises pour validation']);
    }

    // Valider les notes (directeur/censeur)
    public function valider(Request $request)
    {
        $request->validate([
            'periode_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'classe_id'  => 'required|integer',
        ]);

        Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->where('statut', 'soumis')
            ->update(['statut' => 'valide']);

        return response()->json(['message' => 'Notes validées']);
    }

    // Rejeter les notes (directeur/censeur)
    public function rejeter(Request $request)
    {
        $request->validate([
            'periode_id'   => 'required|integer',
            'matiere_id'   => 'required|integer',
            'classe_id'    => 'required|integer',
            'motif_rejet'  => 'required|string',
        ]);

        Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->where('statut', 'soumis')
            ->update([
                'statut'       => 'rejete',
                'motif_rejet'  => $request->motif_rejet,
            ]);

        return response()->json(['message' => 'Notes rejetées']);
    }
}