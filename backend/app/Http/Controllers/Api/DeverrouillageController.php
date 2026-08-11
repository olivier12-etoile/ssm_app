<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HistoriqueValidationNote;
use App\Models\SaisieNote;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DeverrouillageController extends Controller
{
    // POST /notes/deverrouillage
    public function deverrouiller(Request $request)
    {
        abort_unless($request->user()->role === 'directeur', 403,
            'Seul le directeur peut déverrouiller une saisie de notes.');

        $data = $request->validate([
            'classe_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
            'motif' => 'required|string|max:1000',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $saisie = SaisieNote::where('ecole_id', $ecoleId)
            ->where('classe_id', $data['classe_id'])
            ->where('matiere_id', $data['matiere_id'])
            ->where('periode_id', $data['periode_id'])
            ->first();

        if (!$saisie) {
            return response()->json([
                'message' => 'Aucune saisie trouvée pour cette classe, cette matière et cette période.',
            ], 404);
        }

        $verrouillage = $saisie->verrouillageActuel();

        if (!$verrouillage || !$verrouillage->verrouille) {
            return response()->json(['message' => "Cette saisie n'est pas verrouillée."], 422);
        }

        $utilisateur = $request->user();

        DB::transaction(function () use ($saisie, $verrouillage, $utilisateur, $data) {
            $verrouillage->update([
                'verrouille' => false,
                'deverrouille_par' => $utilisateur->id,
                'motif_deverrouillage' => $data['motif'],
                'date_deverrouillage' => now(),
            ]);

            // Repasser la saisie à "en_cours" ne suffit pas à elle seule :
            // Note::modifiable exige aussi statut=brouillon. On repasse donc
            // les notes déjà validées en brouillon pour que la correction
            // demandée soit effectivement possible.
            $saisie->notes()->where('statut', 'validee')->update(['statut' => 'brouillon']);

            $saisie->update(['statut' => 'en_cours']);

            HistoriqueValidationNote::create([
                'saisie_note_id' => $saisie->id,
                'action' => 'deverrouillage',
                'effectue_par' => $utilisateur->id,
                'motif' => $data['motif'],
            ]);
        });

        return response()->json([
            'message' => 'Saisie déverrouillée avec succès',
            'saisie' => $saisie->fresh(),
        ]);
    }
}
