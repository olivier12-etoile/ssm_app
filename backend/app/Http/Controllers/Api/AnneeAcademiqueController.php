<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use Illuminate\Http\Request;

class AnneeAcademiqueController extends Controller
{
    public function index(Request $request)
    {
        $annees = AnneeAcademique::where('ecole_id', $request->user()->ecole_id)
            ->with('periodes')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json($annees);
    }

    public function creer(Request $request)
    {
        $request->validate([
            'libelle'    => 'required|string|max:20',
            'date_debut' => 'required|date',
            'date_fin'   => 'required|date|after:date_debut',
        ]);

        $annee = AnneeAcademique::create([
            'ecole_id'   => $request->user()->ecole_id,
            'libelle'    => $request->libelle,
            'date_debut' => $request->date_debut,
            'date_fin'   => $request->date_fin,
            'statut'     => 'en_cours',
        ]);

        return response()->json([
            'message' => 'Année académique créée',
            'annee'   => $annee,
        ], 201);
    }
}