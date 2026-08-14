<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ConnexionUtilisateur;
use App\Models\JournalGlobal;
use App\Models\ParametreSecurite;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class SecuriteController extends Controller
{
    /**
     * POST /parametres/securite/changer-mot-de-passe
     *
     * Équivalent de ChangerMotDePasseController::changer() /
     * ProfilController::changerMotDePasse() (déjà existants), exposé ici
     * dans la section "Sécurité" des Paramètres de l'école avec une règle
     * de force explicite (l'ancien endpoint acceptait n'importe quel mot
     * de passe de 6 caractères). Les trois routes restent actives : elles
     * couvrent des écrans différents (changement forcé post-première
     * connexion, profil, sécurité) mais mettent à jour le même compte.
     */
    public function changerMotDePasse(Request $request)
    {
        $data = $request->validate([
            'ancien_mot_de_passe'   => 'required|string',
            'nouveau_mot_de_passe'  => ['required', 'confirmed', Password::min(8)->mixedCase()->numbers()],
        ]);

        $utilisateur = $request->user();

        if (!Hash::check($data['ancien_mot_de_passe'], $utilisateur->password)) {
            return response()->json(['message' => 'Ancien mot de passe incorrect'], 401);
        }

        $utilisateur->update([
            'password'            => bcrypt($data['nouveau_mot_de_passe']),
            'mot_de_passe_change' => true,
        ]);

        return response()->json(['message' => 'Mot de passe changé avec succès']);
    }

    // GET /parametres/securite/sessions
    public function sessionsActives(Request $request)
    {
        $utilisateur = $request->user();
        $tokenActuelId = $utilisateur->currentAccessToken()?->id;

        // Aujourd'hui ConnexionController::connecter() fait
        // $utilisateur->tokens()->delete() avant de créer le nouveau token :
        // une seule session active à la fois en pratique. Cette liste reste
        // générique (0..n) si ce comportement de "session unique" change un jour.
        $sessions = $utilisateur->tokens()
            ->orderByDesc('last_used_at')
            ->get()
            ->map(fn ($token) => [
                'id'             => $token->id,
                'nom'            => $token->name,
                'derniere_utilisation' => $token->last_used_at,
                'creee_le'       => $token->created_at,
                'est_actuelle'   => $token->id === $tokenActuelId,
            ]);

        return response()->json(['sessions' => $sessions]);
    }

    // DELETE /parametres/securite/sessions/{tokenId}
    public function revoquerSession(Request $request, $tokenId)
    {
        $token = $request->user()->tokens()->where('id', $tokenId)->first();

        if (!$token) {
            return response()->json(['message' => 'Session introuvable.'], 404);
        }

        $token->delete();

        return response()->json(['message' => 'Session révoquée avec succès']);
    }

    // GET /parametres/securite/deconnexion-auto
    public function afficherDeconnexionAuto(Request $request)
    {
        $parametre = ParametreSecurite::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);

        return response()->json(['parametre' => $parametre]);
    }

    // PUT /parametres/securite/deconnexion-auto (directeur uniquement)
    public function modifierDeconnexionAuto(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier ce paramètre.',
            ], 403);
        }

        $data = $request->validate([
            // null/absent = pas de déconnexion automatique.
            'delai_inactivite_minutes' => 'nullable|integer|min:1|max:1440',
        ]);

        $parametre = ParametreSecurite::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);
        $parametre->update($data);

        return response()->json([
            'message'   => 'Paramètre mis à jour avec succès',
            'parametre' => $parametre->fresh(),
        ]);
    }

    // GET /parametres/securite/historique-connexions
    public function historiqueConnexions(Request $request)
    {
        $data = $request->validate([
            'user_id' => 'nullable|integer',
        ]);

        $estDirecteur = $request->user()->role === 'directeur';

        // FiltreParEcole (sur ConnexionUtilisateur) applique déjà le filtre
        // ecole_id : seule la restriction par utilisateur reste à gérer ici.
        $connexions = ConnexionUtilisateur::query()
            ->when(!$estDirecteur, fn ($q) => $q->where('user_id', $request->user()->id))
            ->when($estDirecteur && !empty($data['user_id']), fn ($q) => $q->where('user_id', $data['user_id']))
            ->with('utilisateur:id,name,role')
            ->orderByDesc('date_connexion')
            ->paginate(30);

        return response()->json($connexions);
    }

    // GET /parametres/securite/journal-actions (directeur/censeur uniquement)
    public function journalActions(Request $request)
    {
        if (!in_array($request->user()->role, ['directeur', 'censeur'], true)) {
            return response()->json([
                'message' => 'Seuls le directeur ou le censeur peuvent consulter le journal des actions.',
            ], 403);
        }

        $data = $request->validate([
            'date_debut' => 'nullable|date',
            'date_fin'   => 'nullable|date',
            'user_id'    => 'nullable|integer',
            'module'     => 'nullable|string',
        ]);

        // JournalGlobal n'utilise pas FiltreParEcole (comme JournalAction,
        // son équivalent par module) : filtre ecole_id explicite ici.
        $journal = JournalGlobal::where('ecole_id', $request->user()->ecole_id)
            ->when(!empty($data['date_debut']), fn ($q) => $q->whereDate('created_at', '>=', $data['date_debut']))
            ->when(!empty($data['date_fin']), fn ($q) => $q->whereDate('created_at', '<=', $data['date_fin']))
            ->when(!empty($data['user_id']), fn ($q) => $q->where('user_id', $data['user_id']))
            ->when(!empty($data['module']), fn ($q) => $q->where('module', $data['module']))
            ->with('utilisateur:id,name,role')
            ->orderByDesc('created_at')
            ->paginate(30);

        return response()->json($journal);
    }
}
