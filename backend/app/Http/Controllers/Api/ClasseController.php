<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use Illuminate\Http\Request;

class ClasseController extends Controller
{
    // Liste des classes de l'école
    public function index(Request $request)
    {
        $classes = Classe::where('ecole_id', $request->user()->ecole_id)
            ->orderBy('niveau')
            ->orderBy('nom')
            ->get();

        return response()->json($classes);
    }

    // Créer une classe
    public function creer(Request $request)
    {
        $request->validate([
            'nom'          => 'required|string|max:50',
            'niveau'       => 'required|string|max:20',
            'capacite_max' => 'nullable|integer|min:1',
        ]);

        $classe = Classe::create([
            'ecole_id'     => $request->user()->ecole_id,
            'nom'          => $request->nom,
            'niveau'       => $request->niveau,
            'capacite_max' => $request->capacite_max ?? 50,
        ]);

        return response()->json([
            'message' => 'Classe créée avec succès',
            'classe'  => $classe,
        ], 201);
    }

    // Modifier une classe
    public function modifier(Request $request, $id)
    {
        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $request->validate([
            'nom'          => 'required|string|max:50',
            'niveau'       => 'required|string|max:20',
            'capacite_max' => 'nullable|integer|min:1',
        ]);

        $classe->update($request->only(['nom', 'niveau', 'capacite_max']));

        return response()->json(['message' => 'Classe modifiée avec succès']);
    }

    // Supprimer une classe
    public function supprimer(Request $request, $id)
    {
        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $classe->delete();

        return response()->json(['message' => 'Classe supprimée avec succès']);
    }
}