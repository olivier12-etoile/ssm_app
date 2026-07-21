<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CahierTexte;
use App\Models\Classe;
use Illuminate\Http\Request;

class CahierTexteController extends Controller
{
    // GET /cahier-texte?classe_id=X&matiere_id=Y&date=Z
    public function index(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'matiere_id' => 'nullable|integer',
            'date'       => 'nullable|date',
        ]);

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $entrees = CahierTexte::where('classe_id', $request->classe_id)
            ->when($request->matiere_id, fn($q) => $q->where('matiere_id', $request->matiere_id))
            ->when($request->date, fn($q) => $q->where('date_cours', $request->date))
            ->with(['matiere:id,nom', 'enseignant:id,name'])
            ->orderByDesc('date_cours')
            ->get();

        return response()->json($entrees);
    }

    // POST /cahier-texte
    public function store(Request $request)
    {
        $data = $request->validate([
            'classe_id'           => 'required|integer',
            'matiere_id'          => 'required|integer',
            'date_cours'          => 'required|date',
            'cours_du_jour'       => 'required|string',
            'exercices'           => 'nullable|string',
            'devoir'              => 'nullable|string',
            'date_remise_devoir'  => 'nullable|date',
        ]);

        Classe::where('id', $data['classe_id'])
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $entree = CahierTexte::create([
            ...$data,
            'enseignant_id' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Entrée du cahier de texte créée avec succès',
            'entree'  => $entree,
        ], 201);
    }

    // PUT /cahier-texte/{id}
    public function update(Request $request, $id)
    {
        $entree = CahierTexte::where('id', $id)
            ->whereHas('classe', fn($q) => $q->where('ecole_id', $request->user()->ecole_id))
            ->firstOrFail();

        $data = $request->validate([
            'matiere_id'          => 'sometimes|integer',
            'date_cours'          => 'sometimes|date',
            'cours_du_jour'       => 'sometimes|string',
            'exercices'           => 'nullable|string',
            'devoir'              => 'nullable|string',
            'date_remise_devoir'  => 'nullable|date',
        ]);

        $entree->update($data);

        return response()->json([
            'message' => 'Entrée du cahier de texte modifiée avec succès',
            'entree'  => $entree,
        ]);
    }

    // GET /cahier-texte/classe/{classeId}
    public function historiqueClasse(Request $request, $classeId)
    {
        Classe::where('id', $classeId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $entrees = CahierTexte::where('classe_id', $classeId)
            ->with(['matiere:id,nom', 'enseignant:id,name'])
            ->orderByDesc('date_cours')
            ->get();

        return response()->json($entrees);
    }
}
