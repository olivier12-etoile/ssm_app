<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\RapportStatistiqueService;
use Illuminate\Http\Request;

class RapportStatistiqueController extends Controller
{
    public function __construct(private RapportStatistiqueService $service)
    {
    }

    // GET /statistiques/rapports/inscriptions?annee_scolaire_id=&format=pdf|excel
    public function inscriptions(Request $request)
    {
        $data = $request->validate([
            'annee_scolaire_id' => 'required|integer',
            'format'            => 'nullable|in:pdf,excel',
        ]);

        return $this->service->rapportInscriptions(
            $request->user()->ecole_id,
            (int) $data['annee_scolaire_id'],
            $data['format'] ?? 'pdf'
        );
    }

    // GET /statistiques/rapports/financier?annee_scolaire_id=&format=pdf|excel
    public function financier(Request $request)
    {
        $data = $request->validate([
            'annee_scolaire_id' => 'required|integer',
            'format'            => 'nullable|in:pdf,excel',
        ]);

        return $this->service->rapportFinancier(
            $request->user()->ecole_id,
            (int) $data['annee_scolaire_id'],
            $data['format'] ?? 'pdf'
        );
    }

    // GET /statistiques/rapports/paiements?annee_scolaire_id=&format=pdf|excel
    public function paiements(Request $request)
    {
        $data = $request->validate([
            'annee_scolaire_id' => 'required|integer',
            'format'            => 'nullable|in:pdf,excel',
        ]);

        return $this->service->rapportPaiements(
            $request->user()->ecole_id,
            (int) $data['annee_scolaire_id'],
            $data['format'] ?? 'pdf'
        );
    }

    // GET /statistiques/rapports/resultats?annee_scolaire_id=&periode_id=&format=pdf|excel
    public function resultats(Request $request)
    {
        $data = $request->validate([
            'annee_scolaire_id' => 'required|integer',
            'periode_id'        => 'required|integer',
            'format'            => 'nullable|in:pdf,excel',
        ]);

        return $this->service->rapportResultats(
            $request->user()->ecole_id,
            (int) $data['annee_scolaire_id'],
            (int) $data['periode_id'],
            $data['format'] ?? 'pdf'
        );
    }

    // GET /statistiques/rapports/meilleurs-eleves?periode_id=&limite=&format=pdf|excel
    public function meilleursEleves(Request $request)
    {
        $data = $request->validate([
            'periode_id' => 'required|integer',
            'limite'     => 'nullable|integer',
            'format'     => 'nullable|in:pdf,excel',
        ]);

        return $this->service->rapportMeilleursEleves(
            $request->user()->ecole_id,
            (int) $data['periode_id'],
            $data['limite'] ?? 10,
            $data['format'] ?? 'pdf'
        );
    }

    // GET /statistiques/rapports/eleves-en-difficulte?periode_id=&seuil=&format=pdf|excel
    public function elevesEnDifficulte(Request $request)
    {
        $data = $request->validate([
            'periode_id' => 'required|integer',
            'seuil'      => 'nullable|numeric',
            'format'     => 'nullable|in:pdf,excel',
        ]);

        return $this->service->rapportElevesEnDifficulte(
            $request->user()->ecole_id,
            (int) $data['periode_id'],
            $data['seuil'] ?? 8,
            $data['format'] ?? 'pdf'
        );
    }
}
