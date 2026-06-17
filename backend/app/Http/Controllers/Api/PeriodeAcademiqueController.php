<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PeriodeAcademique;
use App\Models\AnneeAcademique;
use Illuminate\Http\Request;

class PeriodeAcademiqueController extends Controller
{
    public function index(Request $request, $anneeId)
    {
        $periodes = PeriodeAcademique::where('annee_academique_id', $anneeId)
            ->orderBy('date_debut')
            ->get();

        return response()->json($periodes);
    }

    public function creer(Request $request)
    {
        $request->validate([
            'annee_academique_id' => 'required|integer',
            'nom'                 => 'required|string|max:50',
            'date_debut'          => 'required|date',
            'date_fin'            => 'required|date|after:date_debut',
        ]);

        $periode = PeriodeAcademique::create([
            'annee_academique_id' => $request->annee_academique_id,
            'nom'                 => $request->nom,
            'date_debut'          => $request->date_debut,
            'date_fin'            => $request->date_fin,
            'statut'              => 'planifie',
        ]);

        return response()->json([
            'message' => 'Période créée',
            'periode' => $periode,
        ], 201);
    }

    public function changerStatut(Request $request, $id)
    {
        $request->validate([
            'statut' => 'required|in:planifie,actif,cloture',
        ]);

        $periode = PeriodeAcademique::findOrFail($id);
        $periode->update(['statut' => $request->statut]);

        return response()->json(['message' => 'Statut mis à jour']);
    }
}