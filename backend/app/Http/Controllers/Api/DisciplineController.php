<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\Sanction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DisciplineController extends Controller
{
    private const TYPES = ['retard', 'avertissement', 'exclusion', 'observation', 'conseil_discipline'];

    // GET /sanctions?classe_id=X&eleve_id=Y
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $sanctions = Sanction::whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->when($request->classe_id, fn($q) => $q->where('classe_id', $request->classe_id))
            ->when($request->eleve_id, fn($q) => $q->where('eleve_id', $request->eleve_id))
            ->with(['eleve:id,nom,prenom,matricule', 'classe:id,nom', 'auteur:id,name'])
            ->orderByDesc('date_sanction')
            ->get();

        return response()->json($sanctions);
    }

    // POST /sanctions
    public function store(Request $request)
    {
        $data = $request->validate([
            'eleve_id'       => 'required|integer',
            'classe_id'      => 'required|integer',
            'type'           => 'required|in:' . implode(',', self::TYPES),
            'description'    => 'required|string',
            'date_sanction'  => 'required|date',
            'notifie_parent' => 'nullable|boolean',
        ]);

        Classe::where('id', $data['classe_id'])
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $sanction = Sanction::create([
            ...$data,
            'notifie_parent' => $data['notifie_parent'] ?? false,
            'prononce_par'   => $request->user()->id,
        ]);

        return response()->json([
            'message'  => 'Sanction enregistrée avec succès',
            'sanction' => $sanction,
        ], 201);
    }

    // GET /sanctions/eleve/{eleveId}
    public function historiqueEleve(Request $request, $eleveId)
    {
        $ecoleId = $request->user()->ecole_id;

        $sanctions = Sanction::where('eleve_id', $eleveId)
            ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->with(['classe:id,nom', 'auteur:id,name'])
            ->orderByDesc('date_sanction')
            ->get();

        return response()->json($sanctions);
    }

    // GET /sanctions/statistiques?classe_id=X
    public function statistiques(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $base = Sanction::whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->when($request->classe_id, fn($q) => $q->where('classe_id', $request->classe_id));

        $parType = (clone $base)
            ->select('type', DB::raw('count(*) as total'))
            ->groupBy('type')
            ->pluck('total', 'type');

        return response()->json([
            'total'   => (clone $base)->count(),
            'par_type' => [
                'retard'              => $parType['retard']              ?? 0,
                'avertissement'       => $parType['avertissement']       ?? 0,
                'exclusion'           => $parType['exclusion']           ?? 0,
                'observation'         => $parType['observation']         ?? 0,
                'conseil_discipline'  => $parType['conseil_discipline']  ?? 0,
            ],
            'non_notifiees' => (clone $base)->where('notifie_parent', false)->count(),
        ]);
    }

    // PATCH /sanctions/{id}/notifier
    public function notifier(Request $request, $id)
    {
        $sanction = Sanction::where('id', $id)
            ->whereHas('eleve', fn($q) => $q->where('ecole_id', $request->user()->ecole_id))
            ->firstOrFail();

        $sanction->update(['notifie_parent' => true]);

        return response()->json(['message' => 'Parent marqué comme notifié']);
    }
}
