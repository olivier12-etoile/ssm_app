<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Bulletin;
use App\Models\BulletinDetail;
use App\Models\CorrectionBulletin;
use App\Models\JournalGlobal;
use App\Services\GenerationBulletinService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class CorrectionBulletinController extends Controller
{
    // Champs du Bulletin corrigibles directement. Les champs recalculés
    // (total_points, moyenne_generale, rang, rang_ex_aequo) ne se
    // corrigent que via la note d'une matière (voir recalculerBulletin()).
    private const CHAMPS_BULLETIN_AUTORISES = [
        'decision_conseil',
        'appreciation_generale',
        'absences_justifiees',
        'absences_non_justifiees',
        'retards',
    ];

    // Champs d'un bulletin_details corrigibles.
    private const CHAMPS_DETAIL_AUTORISES = [
        'note',
        'appreciation_matiere',
    ];

    private const DECISIONS_CONSEIL_VALIDES = [
        'encouragements',
        'felicitations',
        'tableau_honneur',
        'avertissement_travail',
        'avertissement_conduite',
        'passage',
        'redoublement',
        'exclusion',
    ];

    public function __construct(private GenerationBulletinService $generationService)
    {
    }

    // POST /bulletins/corrections
    public function demanderCorrection(Request $request)
    {
        abort_unless($request->user()->role === 'directeur', 403,
            'Seul le directeur peut effectuer une correction de bulletin.');

        $data = $request->validate([
            'bulletin_id' => 'required|integer',
            'bulletin_detail_id' => 'nullable|integer',
            'champ_modifie' => 'required|string',
            'nouvelle_valeur' => 'required',
            'motif' => 'required|string|max:1000',
        ]);

        $bulletin = Bulletin::where('id', $data['bulletin_id'])
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        if ($bulletin->statut !== 'valide') {
            return response()->json([
                'message' => "Seul un bulletin validé peut faire l'objet d'une correction (statut actuel : {$bulletin->statut}).",
            ], 422);
        }

        $champ = $data['champ_modifie'];
        $detail = null;

        if (!empty($data['bulletin_detail_id'])) {
            $detail = BulletinDetail::where('id', $data['bulletin_detail_id'])
                ->where('bulletin_id', $bulletin->id)
                ->firstOrFail();

            if (!in_array($champ, self::CHAMPS_DETAIL_AUTORISES, true)) {
                return response()->json([
                    'message' => "Le champ '{$champ}' n'est pas modifiable sur une matière du bulletin.",
                ], 422);
            }
        } elseif (!in_array($champ, self::CHAMPS_BULLETIN_AUTORISES, true)) {
            return response()->json([
                'message' => "Le champ '{$champ}' n'est pas modifiable sur un bulletin.",
            ], 422);
        }

        try {
            $nouvelleValeur = $this->coercerValeur($champ, $data['nouvelle_valeur']);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $cible = $detail ?? $bulletin;
        $ancienneValeur = $cible->{$champ};

        DB::transaction(function () use ($bulletin, $detail, $champ, $nouvelleValeur, $ancienneValeur, $data, $request) {
            $cible = $detail ?? $bulletin;
            $cible->update([$champ => $nouvelleValeur]);

            CorrectionBulletin::create([
                'bulletin_id' => $bulletin->id,
                'bulletin_detail_id' => $detail?->id,
                'champ_modifie' => $champ,
                'ancienne_valeur' => $ancienneValeur === null ? null : (string) $ancienneValeur,
                'nouvelle_valeur' => (string) $nouvelleValeur,
                'motif' => $data['motif'],
                'demande_par' => $request->user()->id,
            ]);

            if ($detail && $champ === 'note') {
                $this->recalculerBulletin($bulletin);
            }
        });

        $this->journaliser($request, $bulletin, $champ);

        return response()->json([
            'message' => 'Correction appliquée avec succès',
            'bulletin' => $bulletin->fresh(['details']),
        ]);
    }

    // GET /bulletins/corrections/{bulletinId}/historique
    public function historique(Request $request, int $bulletinId)
    {
        $bulletin = Bulletin::where('id', $bulletinId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $corrections = $bulletin->corrections()
            ->with('demandePar:id,name')
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['corrections' => $corrections]);
    }

    // Recalcule total_points/total_coefficients/moyenne_generale à partir
    // des bulletin_details actuels, puis les rangs de toute la classe
    // (la correction d'une seule note peut changer le classement général).
    private function recalculerBulletin(Bulletin $bulletin): void
    {
        $details = $bulletin->details()->get();

        $totalPoints = $details->sum(fn (BulletinDetail $d) => (float) $d->note * (float) $d->coefficient);
        $totalCoefficients = $details->sum(fn (BulletinDetail $d) => (float) $d->coefficient);

        $bulletin->update([
            'total_points' => $totalPoints,
            'total_coefficients' => $totalCoefficients,
            'moyenne_generale' => $totalCoefficients > 0 ? round($totalPoints / $totalCoefficients, 2) : 0,
        ]);

        $this->generationService->calculerRangs($bulletin->classe_id, $bulletin->periode_id);
    }

    private function coercerValeur(string $champ, $valeur)
    {
        return match ($champ) {
            'note' => $this->coercerNote($valeur),
            'absences_justifiees', 'absences_non_justifiees', 'retards' => $this->coercerEntierPositif($valeur, $champ),
            'decision_conseil' => $this->coercerDecisionConseil($valeur),
            default => $valeur,
        };
    }

    private function coercerNote($valeur): float
    {
        if (!is_numeric($valeur) || $valeur < 0 || $valeur > 20) {
            throw new RuntimeException('La note corrigée doit être un nombre entre 0 et 20.');
        }

        return round((float) $valeur, 2);
    }

    private function coercerEntierPositif($valeur, string $champ): int
    {
        if (!is_numeric($valeur) || $valeur < 0) {
            throw new RuntimeException("La valeur de '{$champ}' doit être un entier positif ou nul.");
        }

        return (int) $valeur;
    }

    private function coercerDecisionConseil($valeur): string
    {
        if (!in_array($valeur, self::DECISIONS_CONSEIL_VALIDES, true)) {
            throw new RuntimeException(
                'decision_conseil doit être l\'une des valeurs : ' . implode(', ', self::DECISIONS_CONSEIL_VALIDES) . '.'
            );
        }

        return $valeur;
    }

    private function journaliser(Request $request, Bulletin $bulletin, string $champ): void
    {
        JournalGlobal::enregistrer(
            $request->user()->ecole_id,
            'bulletins',
            'correction',
            "Correction du champ '{$champ}' sur le bulletin #{$bulletin->id}.",
            $request->user()->id
        );
    }
}
