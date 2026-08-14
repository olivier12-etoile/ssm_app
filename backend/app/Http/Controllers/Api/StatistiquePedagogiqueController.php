<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\StatistiquePedagogiqueService;
use Illuminate\Http\Request;

class StatistiquePedagogiqueController extends Controller
{
    public function __construct(private StatistiquePedagogiqueService $service)
    {
    }

    // GET /statistiques/pedagogique/par-matiere?periode_id=
    public function parMatiere(Request $request)
    {
        $request->validate(['periode_id' => 'required|integer']);

        return response()->json([
            'matieres' => $this->service->parMatiere($request->user()->ecole_id, (int) $request->periode_id),
        ]);
    }

    // GET /statistiques/pedagogique/par-enseignant?periode_id=
    public function parEnseignant(Request $request)
    {
        $request->validate(['periode_id' => 'required|integer']);

        return response()->json([
            'enseignants' => $this->service->parEnseignant($request->user()->ecole_id, (int) $request->periode_id),
        ]);
    }

    // GET /statistiques/pedagogique/par-classe?periode_id=
    public function parClasse(Request $request)
    {
        $request->validate(['periode_id' => 'required|integer']);

        return response()->json([
            'classes' => $this->service->parClasse($request->user()->ecole_id, (int) $request->periode_id),
        ]);
    }

    // GET /statistiques/pedagogique/meilleures-classes?periode_id=&limite=
    public function meilleuresClasses(Request $request)
    {
        $request->validate(['periode_id' => 'required|integer', 'limite' => 'nullable|integer']);

        $limite = $request->filled('limite') ? (int) $request->limite : 10;

        return response()->json([
            'classement' => $this->service->meilleuresClasses($request->user()->ecole_id, (int) $request->periode_id, $limite),
        ]);
    }

    // GET /statistiques/pedagogique/meilleurs-eleves?periode_id=&limite=&niveau=
    public function meilleursEleves(Request $request)
    {
        $request->validate([
            'periode_id' => 'required|integer',
            'limite'     => 'nullable|integer',
            'niveau'     => 'nullable|string',
        ]);

        $limite = $request->filled('limite') ? (int) $request->limite : 10;

        return response()->json([
            'eleves' => $this->service->meilleursEleves(
                $request->user()->ecole_id,
                (int) $request->periode_id,
                $limite,
                $request->input('niveau')
            ),
        ]);
    }

    // GET /statistiques/pedagogique/eleves-en-difficulte?periode_id=&seuil=
    public function elevesEnDifficulte(Request $request)
    {
        $request->validate(['periode_id' => 'required|integer', 'seuil' => 'nullable|numeric']);

        $seuil = $request->filled('seuil') ? (float) $request->seuil : 8.0;

        return response()->json([
            'seuil'  => $seuil,
            'eleves' => $this->service->elevesEnDifficulte($request->user()->ecole_id, (int) $request->periode_id, $seuil),
        ]);
    }
}
