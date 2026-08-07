<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EcheanceFrais;
use App\Models\FraisScolaire;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FraisScolaireController extends Controller
{
    // GET /frais-scolaires
    public function index(Request $request)
    {
        $frais = FraisScolaire::with(['echeances', 'classe:id,nom'])
            ->when($request->filled('classe_id'), fn($q) => $q->where('classe_id', $request->classe_id))
            ->when($request->filled('annee_scolaire_id'), fn($q) => $q->where('annee_scolaire_id', $request->annee_scolaire_id))
            ->when($request->has('actif'), fn($q) => $q->where('actif', $request->boolean('actif')))
            ->orderBy('nom')
            ->get();

        return response()->json($frais);
    }

    // POST /frais-scolaires
    public function store(Request $request)
    {
        $data = $request->validate([
            'nom'                => 'required|string|max:255',
            'description'        => 'nullable|string',
            'montant'            => 'required|numeric|min:0',
            'classe_id'          => 'nullable|integer',
            'serie'              => 'nullable|string|max:50',
            'annee_scolaire_id'  => 'required|integer',
            'date_limite'        => 'required|date',
            'obligatoire'        => 'nullable|boolean',
            'actif'              => 'nullable|boolean',
            'echeances'                    => 'nullable|array',
            'echeances.*.libelle'          => 'required_with:echeances|string|max:255',
            'echeances.*.montant'          => 'required_with:echeances|numeric|min:0',
            'echeances.*.date_limite'      => 'required_with:echeances|date',
            'echeances.*.ordre'            => 'nullable|integer',
        ]);

        $frais = DB::transaction(function () use ($data) {
            $frais = FraisScolaire::create([
                'nom'               => $data['nom'],
                'description'       => $data['description'] ?? null,
                'montant'           => $data['montant'],
                'classe_id'         => $data['classe_id'] ?? null,
                'serie'             => $data['serie'] ?? null,
                'annee_scolaire_id' => $data['annee_scolaire_id'],
                'date_limite'       => $data['date_limite'],
                'obligatoire'       => $data['obligatoire'] ?? true,
                'actif'             => $data['actif'] ?? true,
            ]);

            foreach ($data['echeances'] ?? [] as $index => $echeance) {
                EcheanceFrais::create([
                    'frais_scolaire_id' => $frais->id,
                    'libelle'           => $echeance['libelle'],
                    'montant'           => $echeance['montant'],
                    'date_limite'       => $echeance['date_limite'],
                    'ordre'             => $echeance['ordre'] ?? $index + 1,
                ]);
            }

            return $frais;
        });

        return response()->json([
            'message' => 'Frais scolaire créé avec succès',
            'frais'   => $frais->load(['echeances', 'classe:id,nom']),
        ], 201);
    }

    // GET /frais-scolaires/{id}
    public function show($id)
    {
        $frais = FraisScolaire::with(['echeances', 'classe:id,nom'])->findOrFail($id);

        return response()->json($frais);
    }

    // PUT /frais-scolaires/{id}
    public function update(Request $request, $id)
    {
        $frais = FraisScolaire::findOrFail($id);

        $data = $request->validate([
            'nom'                => 'sometimes|required|string|max:255',
            'description'        => 'nullable|string',
            'montant'            => 'sometimes|required|numeric|min:0',
            'classe_id'          => 'nullable|integer',
            'serie'              => 'nullable|string|max:50',
            'annee_scolaire_id'  => 'sometimes|required|integer',
            'date_limite'        => 'sometimes|required|date',
            'obligatoire'        => 'nullable|boolean',
            'actif'              => 'nullable|boolean',
            'echeances'                    => 'nullable|array',
            'echeances.*.libelle'          => 'required_with:echeances|string|max:255',
            'echeances.*.montant'          => 'required_with:echeances|numeric|min:0',
            'echeances.*.date_limite'      => 'required_with:echeances|date',
            'echeances.*.ordre'            => 'nullable|integer',
        ]);

        DB::transaction(function () use ($frais, $data) {
            $frais->update(collect($data)->except('echeances')->toArray());

            if (array_key_exists('echeances', $data)) {
                EcheanceFrais::where('frais_scolaire_id', $frais->id)->delete();
                foreach ($data['echeances'] as $index => $echeance) {
                    EcheanceFrais::create([
                        'frais_scolaire_id' => $frais->id,
                        'libelle'           => $echeance['libelle'],
                        'montant'           => $echeance['montant'],
                        'date_limite'       => $echeance['date_limite'],
                        'ordre'             => $echeance['ordre'] ?? $index + 1,
                    ]);
                }
            }
        });

        return response()->json([
            'message' => 'Frais scolaire mis à jour avec succès',
            'frais'   => $frais->fresh(['echeances', 'classe:id,nom']),
        ]);
    }

    // DELETE /frais-scolaires/{id} — désactivation (soft), pas de suppression physique
    public function destroy($id)
    {
        $frais = FraisScolaire::findOrFail($id);
        $frais->update(['actif' => false]);

        return response()->json([
            'message' => 'Frais scolaire désactivé avec succès',
            'frais'   => $frais,
        ]);
    }
}
