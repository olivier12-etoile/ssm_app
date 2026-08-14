<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\JournalGlobal;
use App\Models\ParametreAcademique;
use App\Models\ParametreBulletin;
use App\Models\ParametreClasse;
use App\Models\ParametreFrais;
use App\Models\ParametreMatiere;
use App\Models\ParametreValidationNote;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/**
 * Zone "actions avancées" : opérations sensibles à impact large, toutes
 * protégées par une reconfirmation du mot de passe du directeur (en plus du
 * token de session déjà vérifié par auth:sanctum) — voir motDePasseValide().
 */
class ActionAvanceeController extends Controller
{
    // POST /parametres/actions-avancees/archiver-annee (directeur uniquement)
    public function archiverAnnee(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json(['message' => 'Seul le directeur peut archiver une année scolaire.'], 403);
        }

        $data = $request->validate([
            'annee_scolaire_id'         => 'required|integer',
            'mot_de_passe_confirmation' => 'required|string',
        ]);

        if (!$this->motDePasseValide($request, $data['mot_de_passe_confirmation'])) {
            return response()->json(['message' => 'Mot de passe incorrect.'], 403);
        }

        // Réutilise directement AnneeAcademiqueController::archiver() : même
        // invariant (l'année doit déjà être "cloturee"), même bascule de
        // statut vers "archivee" (annees_academiques.statut — pas de
        // colonne "archivee" séparée, pour ne pas dupliquer l'état), et son
        // propre JournalAction. On ajoute seulement la reconfirmation par
        // mot de passe et la trace dans journal_global ci-dessous.
        $reponse = app(AnneeAcademiqueController::class)->archiver($request, $data['annee_scolaire_id']);

        if ($reponse->getStatusCode() >= 400) {
            return $reponse;
        }

        JournalGlobal::enregistrer(
            $request->user()->ecole_id,
            'annees_academiques',
            'archivage',
            "Année scolaire #{$data['annee_scolaire_id']} archivée depuis les actions avancées.",
            $request->user()->id
        );

        return $reponse;
    }

    // POST /parametres/actions-avancees/reinitialiser-parametres (directeur uniquement)
    public function reinitialiserParametres(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json(['message' => 'Seul le directeur peut réinitialiser les paramètres.'], 403);
        }

        $data = $request->validate([
            'mot_de_passe_confirmation' => 'required|string',
        ]);

        if (!$this->motDePasseValide($request, $data['mot_de_passe_confirmation'])) {
            return response()->json(['message' => 'Mot de passe incorrect.'], 403);
        }

        $ecoleId = $request->user()->ecole_id;

        // Uniquement les tables de configuration parametres_* propres à ce
        // module. Explicitement exclues :
        // - parametres_notifications (module Notifications : déclencheurs +
        //   types) — la réinitialiser réactiverait silencieusement des
        //   notifications qu'un directeur avait délibérément désactivées.
        // - permissions_roles — a son propre endpoint dédié
        //   (PermissionRoleController::reinitialiserDefauts()).
        // - ecoles (identité/marque blanche) et données métier (élèves,
        //   notes, paiements) — jamais touchées ici, comme demandé.
        foreach ([
            ParametreAcademique::class,
            ParametreBulletin::class,
            ParametreValidationNote::class,
            ParametreClasse::class,
            ParametreMatiere::class,
            ParametreFrais::class,
        ] as $modele) {
            $modele::where('ecole_id', $ecoleId)->delete();
        }

        JournalGlobal::enregistrer(
            $ecoleId,
            'parametres',
            'reinitialisation',
            'Réinitialisation de tous les paramètres de configuration aux valeurs par défaut.',
            $request->user()->id
        );

        return response()->json(['message' => 'Paramètres réinitialisés aux valeurs par défaut avec succès']);
    }

    private function motDePasseValide(Request $request, string $motDePasse): bool
    {
        return Hash::check($motDePasse, $request->user()->password);
    }
}
