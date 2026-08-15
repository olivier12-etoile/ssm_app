<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Bulletin;
use App\Models\Eleve;
use App\Models\PeriodeAcademique;
use Illuminate\Http\Request;

class DashboardBulletinController extends Controller
{
    // GET /bulletins/dashboard/resume?annee_scolaire_id=&periode_id=
    public function resume(Request $request)
    {
        $data = $request->validate([
            'annee_scolaire_id' => 'required|integer',
            'periode_id' => 'required|integer',
        ]);
        $anneeScolaireId = $data['annee_scolaire_id'];
        $periodeId = $data['periode_id'];

        $ecoleId = $request->user()->ecole_id;

        AnneeAcademique::where('id', $anneeScolaireId)->where('ecole_id', $ecoleId)->firstOrFail();
        PeriodeAcademique::where('id', $periodeId)->where('annee_academique_id', $anneeScolaireId)->firstOrFail();

        $bulletins = Bulletin::where('ecole_id', $ecoleId)
            ->where('annee_scolaire_id', $anneeScolaireId)
            ->where('periode_id', $periodeId)
            ->get();

        $nombreGeneres = $bulletins->count();
        $nombreValides = $bulletins->whereIn('statut', ['valide', 'verrouille'])->count();
        $nombreEnAttente = $bulletins->where('statut', 'genere')->count();
        $nombreClassesConcernees = $bulletins->pluck('classe_id')->unique()->count();

        // Effectif attendu : tous les élèves inscrits sur l'année, toutes
        // classes confondues (même population que celle parcourue par
        // GenerationBulletinService::genererPourClasse()).
        $effectifTotal = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', fn ($q) => $q->where('annee_academique_id', $anneeScolaireId))
            ->count();

        $nombreNonGeneres = max(0, $effectifTotal - $nombreGeneres);

        return response()->json([
            'annee_scolaire_id' => $anneeScolaireId,
            'periode_id' => $periodeId,
            'effectif_total' => $effectifTotal,
            'nombre_bulletins_generes' => $nombreGeneres,
            'nombre_bulletins_valides' => $nombreValides,
            'nombre_bulletins_en_attente' => $nombreEnAttente,
            'nombre_classes_concernees' => $nombreClassesConcernees,
            'nombre_bulletins_non_generes' => $nombreNonGeneres,
        ]);
    }
}
