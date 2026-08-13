<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\JourTravaille;
use Illuminate\Http\Request;

class JourTravailleController extends Controller
{
    // GET /emploi-du-temps/jours-travailles
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $anneeId = $request->integer('annee_scolaire_id') ?: optional(
            AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first()
        )->id;

        if (!$anneeId) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $jours = JourTravaille::where('annee_scolaire_id', $anneeId)->get();

        return response()->json(['jours' => $jours]);
    }

    // POST /emploi-du-temps/jours-travailles
    public function store(Request $request)
    {
        $data = $request->validate([
            'jour' => 'required|in:lundi,mardi,mercredi,jeudi,vendredi,samedi',
            'actif' => 'boolean',
            'annee_scolaire_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        AnneeAcademique::where('id', $data['annee_scolaire_id'])
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        // upsert : évite de violer la contrainte unique (annee_scolaire_id, jour)
        // si le jour a déjà été configuré.
        $jour = JourTravaille::updateOrCreate(
            ['annee_scolaire_id' => $data['annee_scolaire_id'], 'jour' => $data['jour']],
            ['ecole_id' => $ecoleId, 'actif' => $data['actif'] ?? true]
        );

        return response()->json(['message' => 'Jour enregistré avec succès', 'jour' => $jour], 201);
    }

    // PUT /emploi-du-temps/jours-travailles/{id}
    public function update(Request $request, $id)
    {
        $jour = JourTravaille::findOrFail($id);

        $data = $request->validate([
            'actif' => 'required|boolean',
        ]);

        $jour->update($data);

        return response()->json(['message' => 'Jour modifié avec succès', 'jour' => $jour->fresh()]);
    }

    // DELETE /emploi-du-temps/jours-travailles/{id}
    public function destroy($id)
    {
        $jour = JourTravaille::findOrFail($id);
        $jour->delete();

        return response()->json(['message' => 'Jour supprimé avec succès']);
    }
}
