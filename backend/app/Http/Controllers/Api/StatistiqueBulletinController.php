<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Services\StatistiqueBulletinService;
use Illuminate\Http\Request;

class StatistiqueBulletinController extends Controller
{
    public function __construct(private StatistiqueBulletinService $service)
    {
    }

    // GET /bulletins/statistiques/classe/{classeId}/{periodeId}
    public function parClasse(Request $request, int $classeId, int $periodeId)
    {
        $this->classeDeLecole($request, $classeId);

        return response()->json($this->service->parClasse($classeId, $periodeId));
    }

    // GET /bulletins/statistiques/distribution/{classeId}/{periodeId}
    public function distribution(Request $request, int $classeId, int $periodeId)
    {
        $this->classeDeLecole($request, $classeId);

        return response()->json($this->service->distributionMoyennes($classeId, $periodeId));
    }

    // GET /bulletins/statistiques/comparaison
    public function comparaison(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'required|integer',
            'periode_id_1' => 'required|integer',
            'periode_id_2' => 'required|integer',
        ]);

        $this->classeDeLecole($request, $data['classe_id']);

        return response()->json(
            $this->service->comparaisonPeriodes($data['classe_id'], $data['periode_id_1'], $data['periode_id_2'])
        );
    }

    private function classeDeLecole(Request $request, int $classeId): Classe
    {
        return Classe::where('id', $classeId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();
    }
}
