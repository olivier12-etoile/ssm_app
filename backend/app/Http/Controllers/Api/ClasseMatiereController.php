<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\Matiere;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ClasseMatiereController extends Controller
{
    // Liste des matières d'une classe avec leur coefficient
    public function index(Request $request)
    {
        $request->validate([
            'classe_id' => 'required|integer',
        ]);

        $classe = Classe::where('id', $request->classe_id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $matieres = DB::table('classe_matiere')
            ->where('classe_matiere.classe_id', $classe->id)
            ->join('matieres', 'matieres.id', '=', 'classe_matiere.matiere_id')
            ->select(
                'classe_matiere.id',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
                'matieres.code as matiere_code',
                'classe_matiere.coefficient',
            )
            ->orderBy('matieres.nom')
            ->get();

        return response()->json($matieres);
    }

    // Ajouter ou modifier le coefficient d'une matière dans une classe
    public function enregistrer(Request $request)
    {
        $request->validate([
            'classe_id'   => 'required|integer',
            'matiere_id'  => 'required|integer',
            'coefficient' => 'required|numeric|min:0.5',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        Matiere::where('id', $request->matiere_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $classeMatiere = ClasseMatiere::updateOrCreate(
            [
                'classe_id'  => $request->classe_id,
                'matiere_id' => $request->matiere_id,
            ],
            [
                'coefficient' => $request->coefficient,
            ]
        );

        return response()->json([
            'message'        => 'Matière enregistrée pour la classe avec succès',
            'classe_matiere' => $classeMatiere,
        ], 201);
    }

    // Supprimer une matière d'une classe
    public function supprimer(Request $request, $id)
    {
        $classeMatiere = ClasseMatiere::where('id', $id)
            ->whereHas('classe', function ($q) use ($request) {
                $q->where('ecole_id', $request->user()->ecole_id);
            })
            ->firstOrFail();

        $classeMatiere->delete();

        return response()->json(['message' => 'Matière retirée de la classe avec succès']);
    }
}
