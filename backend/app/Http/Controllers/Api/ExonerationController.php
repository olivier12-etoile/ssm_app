<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ExonerationEleve;
use Illuminate\Http\Request;

class ExonerationController extends Controller
{
    // GET /exonerations
    public function index(Request $request)
    {
        $exonerations = ExonerationEleve::with(['eleve:id,nom,prenom,matricule', 'fraisScolaire:id,nom', 'autorisePar:id,name'])
            ->when($request->filled('eleve_id'), fn($q) => $q->where('eleve_id', $request->eleve_id))
            ->when($request->filled('frais_scolaire_id'), fn($q) => $q->where('frais_scolaire_id', $request->frais_scolaire_id))
            ->orderByDesc('created_at')
            ->get();

        return response()->json($exonerations);
    }

    // POST /exonerations
    public function store(Request $request)
    {
        $data = $request->validate([
            'eleve_id'          => 'required|integer',
            'frais_scolaire_id' => 'required|integer',
            'type'              => 'required|in:totale,partielle',
            'justification'     => 'required|string',
        ]);

        $exoneration = ExonerationEleve::create([
            ...$data,
            'autorise_par' => $request->user()->id,
        ]);

        return response()->json([
            'message'      => 'Exonération enregistrée avec succès',
            'exoneration'  => $exoneration->load(['eleve:id,nom,prenom', 'fraisScolaire:id,nom']),
        ], 201);
    }

    // PUT /exonerations/{id}
    public function update(Request $request, $id)
    {
        $exoneration = ExonerationEleve::findOrFail($id);

        $data = $request->validate([
            'type'          => 'sometimes|required|in:totale,partielle',
            'justification' => 'sometimes|required|string',
        ]);

        $exoneration->update($data);

        return response()->json([
            'message'     => 'Exonération mise à jour avec succès',
            'exoneration' => $exoneration->fresh(),
        ]);
    }

    // DELETE /exonerations/{id}
    public function destroy($id)
    {
        ExonerationEleve::findOrFail($id)->delete();

        return response()->json(['message' => 'Exonération supprimée avec succès']);
    }
}
