<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;

class AffectationController extends Controller
{
    // Liste des affectations d'un enseignant
    public function index(Request $request, $enseignantId)
    {
        $enseignant = User::where('id', $enseignantId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->where('role', 'enseignant')
            ->firstOrFail();

        $affectations = DB::table('enseignant_classe_matiere')
            ->where('enseignant_id', $enseignantId)
            ->join('classes', 'classes.id', '=', 'enseignant_classe_matiere.classe_id')
            ->join('matieres', 'matieres.id', '=', 'enseignant_classe_matiere.matiere_id')
            ->select(
                'enseignant_classe_matiere.id',
                'classes.id as classe_id',
                'classes.nom as classe_nom',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
            )
            ->get();

        return response()->json([
            'enseignant'   => [
                'id'  => $enseignant->id,
                'nom' => $enseignant->name,
            ],
            'affectations' => $affectations,
        ]);
    }

    // Ajouter une affectation
    public function ajouter(Request $request)
    {
        $request->validate([
            'enseignant_id' => 'required|integer',
            'classe_id'     => 'required|integer',
            'matiere_id'    => 'required|integer',
        ]);

        // Vérifier que l'enseignant appartient à l'école
        $enseignant = User::where('id', $request->enseignant_id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->where('role', 'enseignant')
            ->firstOrFail();

        // Vérifier si l'affectation existe déjà
        $existe = DB::table('enseignant_classe_matiere')
            ->where('enseignant_id', $request->enseignant_id)
            ->where('classe_id', $request->classe_id)
            ->where('matiere_id', $request->matiere_id)
            ->exists();

        if ($existe) {
            return response()->json([
                'message' => 'Cette affectation existe déjà'
            ], 409);
        }

        DB::table('enseignant_classe_matiere')->insert([
            'enseignant_id' => $request->enseignant_id,
            'classe_id'     => $request->classe_id,
            'matiere_id'    => $request->matiere_id,
            'created_at'    => now(),
            'updated_at'    => now(),
        ]);

        return response()->json([
            'message' => 'Affectation ajoutée avec succès'
        ], 201);
    }

    // Supprimer une affectation
    public function supprimer(Request $request, $id)
    {
        DB::table('enseignant_classe_matiere')
            ->where('id', $id)
            ->delete();

        return response()->json([
            'message' => 'Affectation supprimée avec succès'
        ]);
    }
}