<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Matiere;
use Illuminate\Http\Request;

class MatiereController extends Controller
{
    // Liste des matières de l'école
    public function index(Request $request)
    {
        $matieres = Matiere::where('ecole_id', $request->user()->ecole_id)
            ->orderBy('nom')
            ->get();

        return response()->json($matieres);
    }

    // Créer une matière
    public function creer(Request $request)
    {
        $request->validate([
            'nom'         => 'required|string|max:100',
            'code'        => 'nullable|string|max:10',
            'coefficient' => 'nullable|numeric|min:0.5',
        ]);

        $matiere = Matiere::create([
            'ecole_id'    => $request->user()->ecole_id,
            'nom'         => $request->nom,
            'code'        => $request->code,
            'coefficient' => $request->coefficient ?? 1,
        ]);

        return response()->json([
            'message' => 'Matière créée avec succès',
            'matiere' => $matiere,
        ], 201);
    }

    // Modifier une matière
    public function modifier(Request $request, $id)
    {
        $matiere = Matiere::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $request->validate([
            'nom'         => 'required|string|max:100',
            'code'        => 'nullable|string|max:10',
            'coefficient' => 'nullable|numeric|min:0.5',
        ]);

        $matiere->update($request->only(['nom', 'code', 'coefficient']));

        return response()->json(['message' => 'Matière modifiée avec succès']);
    }

    // Supprimer une matière
    public function supprimer(Request $request, $id)
    {
        $matiere = Matiere::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $matiere->delete();

        return response()->json(['message' => 'Matière supprimée avec succès']);
    }
}