<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\EvenementCalendrier;
use Illuminate\Http\Request;

class CalendrierController extends Controller
{
    // GET /emploi-du-temps/calendrier?annee_scolaire_id=
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $anneeId = $request->integer('annee_scolaire_id') ?: optional(
            AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first()
        )->id;

        if (!$anneeId) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $evenements = EvenementCalendrier::where('annee_scolaire_id', $anneeId)
            ->when($request->filled('type'), fn ($q) => $q->where('type', $request->type))
            ->orderBy('date_debut')
            ->get();

        return response()->json(['evenements' => $evenements]);
    }

    // POST /emploi-du-temps/calendrier
    public function store(Request $request)
    {
        $data = $request->validate([
            'annee_scolaire_id' => 'required|integer',
            'type' => 'required|in:vacances,ferie,examen,composition,conseil_classe',
            'libelle' => 'required|string|max:150',
            'date_debut' => 'required|date',
            'date_fin' => 'required|date|after_or_equal:date_debut',
        ]);

        $ecoleId = $request->user()->ecole_id;

        AnneeAcademique::where('id', $data['annee_scolaire_id'])
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $evenement = EvenementCalendrier::create([...$data, 'ecole_id' => $ecoleId]);

        return response()->json([
            'message' => 'Événement créé avec succès',
            'evenement' => $evenement,
        ], 201);
    }

    // PUT /emploi-du-temps/calendrier/{id}
    public function update(Request $request, $id)
    {
        $evenement = EvenementCalendrier::findOrFail($id);

        $data = $request->validate([
            'type' => 'sometimes|required|in:vacances,ferie,examen,composition,conseil_classe',
            'libelle' => 'sometimes|required|string|max:150',
            'date_debut' => 'sometimes|required|date',
            'date_fin' => 'sometimes|required|date',
        ]);

        $dateDebut = $data['date_debut'] ?? $evenement->date_debut->format('Y-m-d');
        $dateFin = $data['date_fin'] ?? $evenement->date_fin->format('Y-m-d');

        if ($dateFin < $dateDebut) {
            return response()->json(['message' => 'La date de fin doit être après la date de début.'], 422);
        }

        $evenement->update($data);

        return response()->json([
            'message' => 'Événement modifié avec succès',
            'evenement' => $evenement->fresh(),
        ]);
    }

    // DELETE /emploi-du-temps/calendrier/{id}
    public function destroy($id)
    {
        $evenement = EvenementCalendrier::findOrFail($id);
        $evenement->delete();

        return response()->json(['message' => 'Événement supprimé avec succès']);
    }

    // GET /emploi-du-temps/calendrier/verifier-date?date=
    public function verifierDateLibre(Request $request)
    {
        $data = $request->validate([
            'date' => 'required|date',
        ]);

        $evenement = EvenementCalendrier::whereIn('type', ['vacances', 'ferie'])
            ->whereDate('date_debut', '<=', $data['date'])
            ->whereDate('date_fin', '>=', $data['date'])
            ->first();

        return response()->json([
            'date' => $data['date'],
            'bloquee' => (bool) $evenement,
            'evenement' => $evenement,
        ]);
    }
}
