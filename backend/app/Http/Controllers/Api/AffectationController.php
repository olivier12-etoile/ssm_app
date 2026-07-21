<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;

class AffectationController extends Controller
{
    // Liste des affectations d'une classe (et éventuellement d'une matière précise)
    public function parClasse(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'matiere_id' => 'nullable|integer',
        ]);

        $classe = Classe::where('id', $request->classe_id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $affectations = DB::table('enseignant_classe_matiere')
            ->where('enseignant_classe_matiere.classe_id', $classe->id)
            ->when($request->matiere_id, function ($q) use ($request) {
                $q->where('enseignant_classe_matiere.matiere_id', $request->matiere_id);
            })
            ->join('users', 'users.id', '=', 'enseignant_classe_matiere.enseignant_id')
            ->join('matieres', 'matieres.id', '=', 'enseignant_classe_matiere.matiere_id')
            ->leftJoin('classe_matiere', function ($join) {
                $join->on('classe_matiere.classe_id', '=', 'enseignant_classe_matiere.classe_id')
                     ->on('classe_matiere.matiere_id', '=', 'enseignant_classe_matiere.matiere_id');
            })
            ->select(
                'enseignant_classe_matiere.id',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
                'users.id as enseignant_id',
                'users.name as enseignant_nom',
                'users.telephone as enseignant_telephone',
                'users.photo_path as enseignant_photo_path',
                'classe_matiere.coefficient',
            )
            ->get()
            ->map(function ($a) {
                $a->enseignant_photo_url = $a->enseignant_photo_path
                    ? asset('storage/' . $a->enseignant_photo_path)
                    : null;
                unset($a->enseignant_photo_path);
                return $a;
            });

        return response()->json($affectations);
    }

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
            ->leftJoin('classe_matiere', function ($join) {
                $join->on('classe_matiere.classe_id', '=', 'enseignant_classe_matiere.classe_id')
                     ->on('classe_matiere.matiere_id', '=', 'enseignant_classe_matiere.matiere_id');
            })
            ->select(
                'enseignant_classe_matiere.id',
                'classes.id as classe_id',
                'classes.nom as classe_nom',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
                'classe_matiere.coefficient',
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