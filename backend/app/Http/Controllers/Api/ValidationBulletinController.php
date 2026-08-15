<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Bulletin;
use App\Models\JournalGlobal;
use App\Models\ParametreValidationNote;
use App\Services\DeclencheurNotificationService;
use Illuminate\Http\Request;

/**
 * Workflow des statuts d'un bulletin : genere → valide → verrouille.
 *
 * "valide" (via valider()/validerEnMasse()) fige officiellement le
 * bulletin : à partir de là, seules des corrections tracées
 * (CorrectionBulletinController) peuvent encore le modifier.
 *
 * "verrouille" (via verrouiller()) est une étape volontairement distincte
 * et plus stricte : un bulletin verrouillé n'accepte plus aucune
 * correction via CorrectionBulletinController (voir le garde-fou dans ce
 * contrôleur) -- utile une fois les bulletins imprimés/distribués, où toute
 * modification ultérieure doit passer par une procédure manuelle hors
 * application plutôt que par l'API. On ne fusionne donc pas valide et
 * verrouille : un bulletin "valide" reste corrigible, un bulletin
 * "verrouille" ne l'est plus.
 */
class ValidationBulletinController extends Controller
{
    public function __construct(private DeclencheurNotificationService $declencheurNotification)
    {
    }

    // POST /bulletins/validation/valider
    // Accepte soit { bulletin_id }, soit { classe_id, periode_id } pour
    // valider tous les bulletins "genere" de la classe en une seule fois
    // (équivalent à validerEnMasse()).
    public function valider(Request $request)
    {
        $data = $request->validate([
            'bulletin_id' => 'nullable|integer',
            'classe_id' => 'nullable|integer',
            'periode_id' => 'nullable|integer',
        ]);

        if (empty($data['bulletin_id']) && (empty($data['classe_id']) || empty($data['periode_id']))) {
            return response()->json([
                'message' => 'Fournir soit bulletin_id, soit classe_id et periode_id.',
            ], 422);
        }

        $this->autoriserValidation($request);

        if (!empty($data['bulletin_id'])) {
            $bulletin = Bulletin::where('id', $data['bulletin_id'])
                ->where('ecole_id', $request->user()->ecole_id)
                ->firstOrFail();

            if ($bulletin->statut !== 'genere') {
                return response()->json([
                    'message' => "Ce bulletin ne peut pas être validé (statut actuel : {$bulletin->statut}).",
                ], 422);
            }

            $this->validerBulletin($bulletin, $request->user()->id);

            $this->journaliser($request, 'validation', "Bulletin #{$bulletin->id} validé.");

            return response()->json([
                'message' => 'Bulletin validé avec succès',
                'bulletin' => $bulletin->fresh(),
            ]);
        }

        return $this->validerEnMasseInterne($request, (int) $data['classe_id'], (int) $data['periode_id']);
    }

    // POST /bulletins/validation/valider-masse
    public function validerEnMasse(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $this->autoriserValidation($request);

        return $this->validerEnMasseInterne($request, $data['classe_id'], $data['periode_id']);
    }

    // POST /bulletins/validation/verrouiller/{id}
    public function verrouiller(Request $request, int $id)
    {
        $this->autoriserValidation($request);

        $bulletin = Bulletin::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        if ($bulletin->statut !== 'valide') {
            return response()->json([
                'message' => "Seul un bulletin validé peut être verrouillé (statut actuel : {$bulletin->statut}).",
            ], 422);
        }

        $bulletin->update(['statut' => 'verrouille']);

        $this->journaliser($request, 'verrouillage', "Bulletin #{$bulletin->id} verrouillé.");

        return response()->json([
            'message' => 'Bulletin verrouillé avec succès',
            'bulletin' => $bulletin->fresh(),
        ]);
    }

    private function validerEnMasseInterne(Request $request, int $classeId, int $periodeId)
    {
        $bulletins = Bulletin::where('ecole_id', $request->user()->ecole_id)
            ->where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->where('statut', 'genere')
            ->get();

        $idsValides = [];
        foreach ($bulletins as $bulletin) {
            $this->validerBulletin($bulletin, $request->user()->id);
            $idsValides[] = $bulletin->id;
        }

        $this->journaliser(
            $request,
            'validation_masse',
            count($idsValides) . " bulletin(s) validé(s) pour la classe #{$classeId}, période #{$periodeId}."
        );

        return response()->json([
            'message' => count($idsValides) . ' bulletin(s) validé(s)',
            'nombre_valides' => count($idsValides),
            'bulletin_ids' => $idsValides,
        ]);
    }

    private function validerBulletin(Bulletin $bulletin, int $userId): void
    {
        $bulletin->update([
            'statut' => 'valide',
            'valide_par' => $userId,
            'date_validation' => now(),
        ]);

        // Point de câblage demandé (module Notifications, Phase 4) : notifie
        // le parent que le bulletin est disponible. Placé ici (plutôt que
        // dans valider()/validerEnMasse() séparément) pour que les deux
        // parcours de validation déclenchent la notification une seule fois,
        // au même endroit. Ne doit jamais faire échouer la validation :
        // DeclencheurNotificationService::surBulletinDisponible() est déjà
        // un no-op silencieux (avec log) si le déclencheur est désactivé, si
        // le modèle de message est introuvable, ou si le parent n'a pas de
        // téléphone enregistré.
        $this->declencheurNotification->surBulletinDisponible($bulletin->eleve_id, $bulletin->periode_id, $userId);
    }

    private function journaliser(Request $request, string $action, string $description): void
    {
        JournalGlobal::enregistrer(
            $request->user()->ecole_id,
            'bulletins',
            $action,
            $description,
            $request->user()->id
        );
    }

    private function autoriserValidation(Request $request): void
    {
        $roles = ParametreValidationNote::where('ecole_id', $request->user()->ecole_id)->first()
            ?->rolesAutorisesOuDefaut()
            ?? ParametreValidationNote::ROLES_VALIDATION_DEFAUT;

        abort_unless(
            in_array($request->user()->role, $roles, true),
            403,
            'Seuls les rôles autorisés à valider (' . implode(', ', $roles) . ') peuvent effectuer cette action.'
        );
    }
}
