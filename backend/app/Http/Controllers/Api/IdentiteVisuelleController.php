<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class IdentiteVisuelleController extends Controller
{
    // Colonne "ecoles" correspondant à chaque type de logo accepté par
    // uploadLogo()/supprimerLogo() (route /identite-visuelle/logo[/{type}]).
    private const COLONNES_LOGO = [
        'principal'   => 'chemin_logo',
        'secondaire'  => 'logo_secondaire',
    ];

    // GET /parametres/identite-visuelle
    public function show(Request $request)
    {
        $ecole = $request->user()->ecole;

        return response()->json([
            'logos' => [
                'principal'   => ['chemin' => $ecole->chemin_logo, 'url' => $ecole->logo_principal_url],
                'secondaire'  => ['chemin' => $ecole->logo_secondaire, 'url' => $ecole->logo_secondaire_url],
            ],
            'cachet'    => ['chemin' => $ecole->cachet_numerique, 'url' => $ecole->cachet_numerique_url],
            'signature' => ['chemin' => $ecole->signature_directeur, 'url' => $ecole->signature_directeur_url],
            'couleurs'  => [
                'couleur_principale'   => $ecole->couleur_primaire,
                'couleur_secondaire'   => $ecole->couleur_secondaire,
                'couleur_boutons'      => $ecole->couleur_boutons,
                'couleur_entetes'      => $ecole->couleur_entetes,
            ],
        ]);
    }

    // POST /parametres/identite-visuelle/logo (directeur uniquement)
    public function uploadLogo(Request $request)
    {
        if ($reponse = $this->refuserSiPasDirecteur($request)) {
            return $reponse;
        }

        $data = $request->validate([
            'type' => 'required|in:principal,secondaire',
            'logo' => 'required|file|mimes:jpg,jpeg,png,svg|max:2048',
        ]);

        $ecole   = $request->user()->ecole;
        $colonne = self::COLONNES_LOGO[$data['type']];

        if ($ecole->{$colonne}) {
            Storage::disk('public')->delete($ecole->{$colonne});
        }

        $chemin = $request->file('logo')->store("ecoles/{$ecole->id}/logos", 'public');
        $ecole->update([$colonne => $chemin]);

        return response()->json([
            'message' => 'Logo mis à jour avec succès',
            'chemin'  => $chemin,
            'url'     => asset('storage/' . $chemin),
        ]);
    }

    // POST /parametres/identite-visuelle/cachet (directeur uniquement)
    public function uploadCachet(Request $request)
    {
        if ($reponse = $this->refuserSiPasDirecteur($request)) {
            return $reponse;
        }

        $request->validate([
            'cachet' => 'required|file|mimes:jpg,jpeg,png,svg|max:2048',
        ]);

        $ecole = $request->user()->ecole;

        if ($ecole->cachet_numerique) {
            Storage::disk('public')->delete($ecole->cachet_numerique);
        }

        $chemin = $request->file('cachet')->store("ecoles/{$ecole->id}/cachet", 'public');
        $ecole->update(['cachet_numerique' => $chemin]);

        return response()->json([
            'message' => 'Cachet numérique mis à jour avec succès',
            'chemin'  => $chemin,
            'url'     => asset('storage/' . $chemin),
        ]);
    }

    // POST /parametres/identite-visuelle/signature (directeur uniquement)
    public function uploadSignature(Request $request)
    {
        if ($reponse = $this->refuserSiPasDirecteur($request)) {
            return $reponse;
        }

        $request->validate([
            'signature' => 'required|file|mimes:jpg,jpeg,png,svg|max:2048',
        ]);

        $ecole = $request->user()->ecole;

        if ($ecole->signature_directeur) {
            Storage::disk('public')->delete($ecole->signature_directeur);
        }

        $chemin = $request->file('signature')->store("ecoles/{$ecole->id}/signature", 'public');
        $ecole->update(['signature_directeur' => $chemin]);

        return response()->json([
            'message' => 'Signature du directeur mise à jour avec succès',
            'chemin'  => $chemin,
            'url'     => asset('storage/' . $chemin),
        ]);
    }

    // PUT /parametres/identite-visuelle/couleurs (directeur uniquement)
    public function updateCouleurs(Request $request)
    {
        if ($reponse = $this->refuserSiPasDirecteur($request)) {
            return $reponse;
        }

        $hex = 'regex:/^#[0-9A-Fa-f]{6}$/';

        $data = $request->validate([
            'couleur_principale' => "sometimes|string|{$hex}",
            'couleur_secondaire' => "sometimes|string|{$hex}",
            'couleur_boutons'    => "sometimes|string|{$hex}",
            'couleur_entetes'    => "sometimes|string|{$hex}",
        ]);

        // couleur_principale est le nom historique de la colonne "couleur_primaire".
        if (array_key_exists('couleur_principale', $data)) {
            $data['couleur_primaire'] = $data['couleur_principale'];
            unset($data['couleur_principale']);
        }

        $ecole = $request->user()->ecole;
        $ecole->update($data);

        return response()->json([
            'message'  => 'Couleurs mises à jour avec succès',
            'couleurs' => [
                'couleur_principale' => $ecole->couleur_primaire,
                'couleur_secondaire' => $ecole->couleur_secondaire,
                'couleur_boutons'    => $ecole->couleur_boutons,
                'couleur_entetes'    => $ecole->couleur_entetes,
            ],
        ]);
    }

    // DELETE /parametres/identite-visuelle/logo/{type} (directeur uniquement)
    public function supprimerLogo(Request $request, string $type)
    {
        if ($reponse = $this->refuserSiPasDirecteur($request)) {
            return $reponse;
        }

        if (!array_key_exists($type, self::COLONNES_LOGO)) {
            return response()->json(['message' => 'Type de logo invalide.'], 422);
        }

        $ecole   = $request->user()->ecole;
        $colonne = self::COLONNES_LOGO[$type];

        if ($ecole->{$colonne}) {
            Storage::disk('public')->delete($ecole->{$colonne});
            $ecole->update([$colonne => null]);
        }

        return response()->json(['message' => 'Logo supprimé avec succès']);
    }

    private function refuserSiPasDirecteur(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier l\'identité visuelle de l\'établissement.',
            ], 403);
        }

        return null;
    }
}
