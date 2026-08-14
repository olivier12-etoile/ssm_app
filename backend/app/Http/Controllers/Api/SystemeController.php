<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SauvegardeInfo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SystemeController extends Controller
{
    // GET /parametres/systeme/statut
    public function statut(Request $request)
    {
        $baseDeDonnees = 'operationnel';
        try {
            DB::connection()->getPdo();
        } catch (\Throwable $e) {
            $baseDeDonnees = 'indisponible';
        }

        return response()->json([
            'version'        => config('ssm.version'),
            // Si cette réponse part, le serveur applicatif répond forcément.
            'serveur'        => 'operationnel',
            'base_de_donnees' => $baseDeDonnees,
            // Placeholder : aucune vraie synchronisation offline/online
            // n'est encore branchée côté backend (module sync Flutter à
            // relier plus tard).
            'synchronisation' => 'a_jour',
        ]);
    }

    // GET /parametres/systeme/sauvegarde
    public function sauvegardeInfo(Request $request)
    {
        // Statut informatif uniquement : la sauvegarde réelle de la base
        // est gérée par l'infrastructure (Railway), pas par l'application.
        $derniere = SauvegardeInfo::where('ecole_id', $request->user()->ecole_id)
            ->orderByDesc('created_at')
            ->first();

        return response()->json(['sauvegarde' => $derniere]);
    }
}
