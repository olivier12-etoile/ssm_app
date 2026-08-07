<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\RemiseEleve;
use Illuminate\Http\Request;

class RemiseController extends Controller
{
    // GET /remises
    public function index(Request $request)
    {
        $remises = RemiseEleve::with(['eleve:id,nom,prenom,matricule', 'fraisScolaire:id,nom', 'autorisePar:id,name'])
            ->when($request->filled('eleve_id'), fn($q) => $q->where('eleve_id', $request->eleve_id))
            ->when($request->filled('frais_scolaire_id'), fn($q) => $q->where('frais_scolaire_id', $request->frais_scolaire_id))
            ->orderByDesc('created_at')
            ->get();

        return response()->json($remises);
    }

    // POST /remises
    public function store(Request $request)
    {
        $data = $request->validate([
            'eleve_id'          => 'required|integer',
            'frais_scolaire_id' => 'required|integer',
            'type'              => 'required|in:bourse,reduction_familiale,reduction_exceptionnelle,remise_administrative',
            'montant'           => 'nullable|required_without:pourcentage|numeric|min:0',
            'pourcentage'       => 'nullable|required_without:montant|numeric|min:0|max:100',
            'motif'             => 'required|string',
        ]);

        $remise = RemiseEleve::create([
            ...$data,
            'autorise_par' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Remise enregistrée avec succès',
            'remise'  => $remise->load(['eleve:id,nom,prenom', 'fraisScolaire:id,nom']),
        ], 201);
    }

    // PUT /remises/{id}
    public function update(Request $request, $id)
    {
        $remise = RemiseEleve::findOrFail($id);

        $data = $request->validate([
            'type'        => 'sometimes|required|in:bourse,reduction_familiale,reduction_exceptionnelle,remise_administrative',
            'montant'     => 'nullable|numeric|min:0',
            'pourcentage' => 'nullable|numeric|min:0|max:100',
            'motif'       => 'sometimes|required|string',
        ]);

        $remise->update($data);

        return response()->json([
            'message' => 'Remise mise à jour avec succès',
            'remise'  => $remise->fresh(),
        ]);
    }

    // DELETE /remises/{id}
    public function destroy($id)
    {
        RemiseEleve::findOrFail($id)->delete();

        return response()->json(['message' => 'Remise supprimée avec succès']);
    }
}
