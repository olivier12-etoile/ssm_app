<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Bulletin;
use App\Models\Eleve;
use Illuminate\Http\Request;

class HistoriqueBulletinController extends Controller
{
    // GET /bulletins/historique/eleve/{eleveId}
    // Groupé par année scolaire puis par période, ex :
    // { "2026-2027": { "annee_scolaire_id": 3, "periodes": { "Premier trimestre": {...}, ... } }, ... }
    public function parEleve(Request $request, int $eleveId)
    {
        $eleve = Eleve::where('id', $eleveId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $bulletins = Bulletin::where('eleve_id', $eleve->id)
            ->with(['anneeScolaire', 'periode', 'classe'])
            ->get();

        $parAnnee = $bulletins
            ->groupBy(fn (Bulletin $b) => $b->anneeScolaire->libelle ?? 'Année inconnue')
            ->map(function ($bulletinsAnnee) {
                $periodes = $bulletinsAnnee
                    ->sortBy(fn (Bulletin $b) => $b->periode->ordre ?? 0)
                    ->groupBy(fn (Bulletin $b) => $b->periode->nom ?? 'Période inconnue')
                    ->map(fn ($groupe) => $this->formaterBulletin($groupe->first()));

                return [
                    'annee_scolaire_id' => $bulletinsAnnee->first()->annee_scolaire_id,
                    'periodes' => $periodes,
                ];
            })
            ->sortByDesc(fn ($groupe) => $groupe['annee_scolaire_id']);

        return response()->json([
            'eleve' => [
                'id' => $eleve->id,
                'nom' => $eleve->nom,
                'prenom' => $eleve->prenom,
                'matricule' => $eleve->matricule,
            ],
            'historique' => $parAnnee,
        ]);
    }

    // GET /bulletins/historique/rechercher
    public function rechercher(Request $request)
    {
        $data = $request->validate([
            'query' => 'nullable|string',
            'classe_id' => 'nullable|integer',
            'annee_scolaire_id' => 'nullable|integer',
            'periode_id' => 'nullable|integer',
        ]);

        $bulletins = Bulletin::where('ecole_id', $request->user()->ecole_id)
            ->when(!empty($data['classe_id']), fn ($q) => $q->where('classe_id', $data['classe_id']))
            ->when(!empty($data['annee_scolaire_id']), fn ($q) => $q->where('annee_scolaire_id', $data['annee_scolaire_id']))
            ->when(!empty($data['periode_id']), fn ($q) => $q->where('periode_id', $data['periode_id']))
            ->when(!empty($data['query']), function ($q) use ($data) {
                $terme = $data['query'];
                $q->whereHas('eleve', function ($eq) use ($terme) {
                    $eq->where('nom', 'like', "%{$terme}%")
                        ->orWhere('prenom', 'like', "%{$terme}%")
                        ->orWhere('matricule', 'like', "%{$terme}%");
                });
            })
            ->with([
                'eleve:id,nom,prenom,matricule',
                'classe:id,nom',
                'periode:id,nom',
                'anneeScolaire:id,libelle',
            ])
            ->orderByDesc('id')
            ->paginate(30);

        return response()->json($bulletins);
    }

    private function formaterBulletin(Bulletin $bulletin): array
    {
        return [
            'bulletin_id' => $bulletin->id,
            'periode_id' => $bulletin->periode_id,
            'classe_nom' => $bulletin->classe->nom ?? null,
            'moyenne_generale' => (float) $bulletin->moyenne_generale,
            'rang' => $bulletin->rang,
            'rang_ex_aequo' => $bulletin->rang_ex_aequo,
            'effectif_classe' => $bulletin->effectif_classe,
            'decision_conseil' => $bulletin->decision_conseil,
            'statut' => $bulletin->statut,
        ];
    }
}
