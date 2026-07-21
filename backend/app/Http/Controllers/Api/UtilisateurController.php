<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\PermissionModule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Barryvdh\DomPDF\Facade\Pdf;
use PhpOffice\PhpSpreadsheet\IOFactory;

class UtilisateurController extends Controller
{
    private const ROLES_GERES = ['censeur', 'secretaire', 'enseignant'];

    // ── 1. Tableau de bord des utilisateurs ─────────────────────
    public function tableau_de_bord(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $base = User::where('ecole_id', $ecoleId)->where('id', '!=', $request->user()->id);

        $parRole = (clone $base)
            ->select('role', DB::raw('count(*) as total'))
            ->groupBy('role')
            ->pluck('total', 'role');

        return response()->json([
            'total'     => (clone $base)->count(),
            'par_role'  => [
                'directeur'  => $parRole['directeur']  ?? 0,
                'censeur'    => $parRole['censeur']    ?? 0,
                'secretaire' => $parRole['secretaire'] ?? 0,
                'enseignant' => $parRole['enseignant'] ?? 0,
            ],
            'actifs'            => (clone $base)->where('actif', true)->count(),
            'desactives'        => (clone $base)->where('actif', false)->count(),
            'nouveaux_ce_mois'  => (clone $base)
                ->whereMonth('created_at', now()->month)
                ->whereYear('created_at', now()->year)
                ->count(),
        ]);
    }

    // ── 1bis. Fiche d'un utilisateur ─────────────────────────────
    public function show($id, Request $request)
    {
        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        return response()->json($utilisateur);
    }

    // ── 2. Liste des utilisateurs de l'école ────────────────────
    public function index(Request $request)
    {
        $colonnesTri = ['created_at', 'name', 'role', 'derniere_connexion'];
        $tri = in_array($request->get('tri'), $colonnesTri) ? $request->get('tri') : 'created_at';
        $direction = $request->get('direction') === 'asc' ? 'asc' : 'desc';

        $utilisateurs = User::where('ecole_id', $request->user()->ecole_id)
            ->where('id', '!=', $request->user()->id)
            ->when($request->role, fn($q) => $q->where('role', $request->role))
            ->when($request->has('actif'), fn($q) => $q->where('actif', $request->boolean('actif')))
            ->when($request->search, function ($q) use ($request) {
                $recherche = $request->search;
                $q->where(function ($qq) use ($recherche) {
                    $qq->where('name', 'like', "%{$recherche}%")
                       ->orWhere('email', 'like', "%{$recherche}%")
                       ->orWhere('telephone', 'like', "%{$recherche}%");
                });
            })
            ->orderBy($tri, $direction)
            ->paginate(20);

        return response()->json($utilisateurs);
    }

    // ── 3. Créer un utilisateur ──────────────────────────────────
    public function creer(Request $request)
    {
        $request->validate([
            'name'      => 'required|string|max:191',
            'prenom'    => 'nullable|string|max:191',
            'email'     => 'required|email|unique:users,email',
            'sexe'      => 'nullable|in:M,F',
            'telephone' => 'nullable|string|max:20',
            'adresse'   => 'nullable|string',
            'fonction'  => 'nullable|string|max:191',
            'role'      => 'required|in:' . implode(',', self::ROLES_GERES),
            'photo'     => 'nullable|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        $motDePasse = $this->genererMotDePasseTemporaire();

        $cheminPhoto = $request->hasFile('photo')
            ? $request->file('photo')->store('users/photos', 'public')
            : null;

        $utilisateur = User::create([
            'name'                    => $request->name,
            'prenom'                  => $request->prenom,
            'email'                   => $request->email,
            'password'                => bcrypt($motDePasse),
            'mot_de_passe_temporaire' => $motDePasse,
            'sexe'                    => $request->sexe,
            'telephone'               => $request->telephone,
            'adresse'                 => $request->adresse,
            'fonction'                => $request->fonction,
            'role'                    => $request->role,
            'photo_path'              => $cheminPhoto,
            'ecole_id'                => $request->user()->ecole_id,
            'mot_de_passe_change'     => false,
            'actif'                   => true,
        ]);

        return response()->json([
            'message'      => 'Utilisateur créé avec succès',
            'utilisateur'  => $utilisateur,
            'mot_de_passe' => $motDePasse,
        ], 201);
    }

    // ── 4. Modifier un utilisateur ───────────────────────────────
    public function modifier(Request $request, $id)
    {
        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $request->validate([
            'name'      => 'sometimes|string|max:191',
            'prenom'    => 'nullable|string|max:191',
            'telephone' => 'nullable|string|max:20',
            'email'     => 'sometimes|email|unique:users,email,' . $utilisateur->id,
            'role'      => 'sometimes|in:' . implode(',', self::ROLES_GERES),
            'adresse'   => 'nullable|string',
            'fonction'  => 'nullable|string|max:191',
            'photo'     => 'nullable|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        $donnees = $request->only(['name', 'prenom', 'telephone', 'email', 'role', 'adresse', 'fonction']);

        if ($request->hasFile('photo')) {
            if ($utilisateur->photo_path) {
                Storage::disk('public')->delete($utilisateur->photo_path);
            }
            $donnees['photo_path'] = $request->file('photo')->store('users/photos', 'public');
        }

        $utilisateur->update($donnees);

        return response()->json([
            'message'     => 'Utilisateur modifié avec succès',
            'utilisateur' => $utilisateur,
        ]);
    }

    // ── 5. Désactiver un utilisateur ─────────────────────────────
    public function desactiver($id, Request $request)
    {
        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $utilisateur->update(['actif' => false]);
        $utilisateur->tokens()->delete();

        return response()->json(['message' => 'Utilisateur désactivé']);
    }

    // ── 6. Réactiver un utilisateur ───────────────────────────────
    public function reactiver($id, Request $request)
    {
        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $utilisateur->update(['actif' => true]);

        return response()->json(['message' => 'Utilisateur réactivé']);
    }

    // ── 7. Réinitialiser le mot de passe ─────────────────────────
    public function reinitialiserMotDePasse($id, Request $request)
    {
        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $motDePasse = $this->genererMotDePasseTemporaire();

        $utilisateur->update([
            'password'                => bcrypt($motDePasse),
            'mot_de_passe_temporaire' => $motDePasse,
            'mot_de_passe_change'     => false,
        ]);
        $utilisateur->tokens()->delete();

        return response()->json([
            'message'      => 'Mot de passe réinitialisé',
            'mot_de_passe' => $motDePasse,
        ]);
    }

    // ── 8. Importer des utilisateurs depuis un fichier Excel ────
    public function importerExcel(Request $request)
    {
        $request->validate([
            'fichier' => 'required|file|mimes:xlsx,xls',
        ]);

        $lignes = IOFactory::load($request->file('fichier')->getRealPath())
            ->getActiveSheet()
            ->toArray();

        // Ligne 1 = en-têtes : nom, prenom, email, role, sexe, telephone, fonction
        $entetes = array_map(fn($e) => strtolower(trim((string) $e)), array_shift($lignes) ?? []);

        $crees   = [];
        $ignores = [];
        $erreurs = [];

        foreach ($lignes as $index => $ligne) {
            if (empty(array_filter($ligne, fn($v) => trim((string) $v) !== ''))) {
                continue;
            }

            $numeroLigne = $index + 2; // +2 : ligne 1 = en-têtes, $index base 0
            $donnees = array_combine($entetes, array_pad($ligne, count($entetes), null));

            $nom   = trim((string) ($donnees['nom'] ?? ''));
            $email = trim((string) ($donnees['email'] ?? ''));
            $role  = strtolower(trim((string) ($donnees['role'] ?? '')));
            $sexe  = strtoupper(trim((string) ($donnees['sexe'] ?? '')));

            if ($nom === '' || $email === '' || !in_array($role, self::ROLES_GERES)) {
                $erreurs[] = ['ligne' => $numeroLigne, 'message' => 'Nom, email ou rôle invalide'];
                continue;
            }

            if (User::where('email', $email)->exists()) {
                $ignores[] = ['ligne' => $numeroLigne, 'email' => $email, 'message' => 'Email déjà existant'];
                continue;
            }

            $motDePasse = $this->genererMotDePasseTemporaire();

            $utilisateur = User::create([
                'name'                    => $nom,
                'prenom'                  => $donnees['prenom'] ?? null,
                'email'                   => $email,
                'password'                => bcrypt($motDePasse),
                'mot_de_passe_temporaire' => $motDePasse,
                'role'                    => $role,
                'sexe'                    => in_array($sexe, ['M', 'F']) ? $sexe : null,
                'telephone'               => $donnees['telephone'] ?? null,
                'fonction'                => $donnees['fonction'] ?? null,
                'ecole_id'                => $request->user()->ecole_id,
                'mot_de_passe_change'     => false,
                'actif'                   => true,
            ]);

            $crees[] = ['id' => $utilisateur->id, 'nom' => $nom, 'email' => $email];
        }

        return response()->json([
            'message' => 'Import terminé',
            'crees'   => $crees,
            'ignores' => $ignores,
            'erreurs' => $erreurs,
        ]);
    }

    // ── 9. Exporter la liste des utilisateurs en PDF ─────────────
    public function exporterPdf(Request $request)
    {
        $ecole = $request->user()->ecole;

        $utilisateurs = User::where('ecole_id', $request->user()->ecole_id)
            ->where('id', '!=', $request->user()->id)
            ->when($request->role, fn($q) => $q->where('role', $request->role))
            ->when($request->has('actif'), fn($q) => $q->where('actif', $request->boolean('actif')))
            ->orderBy('name')
            ->get();

        $parRole = $utilisateurs->groupBy('role')->map->count();

        $pdf = Pdf::loadView('pdf.utilisateurs', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'utilisateurs' => $utilisateurs,
            'filtres'      => [
                'role'  => $request->role,
                'actif' => $request->has('actif') ? $request->boolean('actif') : null,
            ],
            'par_role'  => [
                'directeur'  => $parRole['directeur']  ?? 0,
                'censeur'    => $parRole['censeur']    ?? 0,
                'secretaire' => $parRole['secretaire'] ?? 0,
                'enseignant' => $parRole['enseignant'] ?? 0,
            ],
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('utilisateurs.pdf');
    }

    // ── 10. Exporter la liste des utilisateurs en Excel (CSV) ────
    public function exporterExcel(Request $request)
    {
        $utilisateurs = User::where('ecole_id', $request->user()->ecole_id)
            ->where('id', '!=', $request->user()->id)
            ->when($request->role, fn($q) => $q->where('role', $request->role))
            ->when($request->has('actif'), fn($q) => $q->where('actif', $request->boolean('actif')))
            ->orderBy('name')
            ->get();

        $callback = function () use ($utilisateurs) {
            $fichier = fopen('php://output', 'w');
            fwrite($fichier, "\xEF\xBB\xBF"); // BOM UTF-8 pour Excel
            fputcsv($fichier, ['Nom', 'Prénom', 'Email', 'Rôle', 'Téléphone', 'Fonction', 'Actif']);

            foreach ($utilisateurs as $u) {
                fputcsv($fichier, [
                    $u->name,
                    $u->prenom,
                    $u->email,
                    $u->role,
                    $u->telephone,
                    $u->fonction,
                    $u->actif ? 'Oui' : 'Non',
                ]);
            }

            fclose($fichier);
        };

        return response()->stream($callback, 200, [
            'Content-Type'        => 'text/csv',
            'Content-Disposition' => 'attachment; filename="utilisateurs.csv"',
        ]);
    }

    // ── Génère un mot de passe temporaire (4 lettres + 4 chiffres) ─
    private function genererMotDePasseTemporaire(): string
    {
        $lettres  = collect(range('A', 'Z'))->shuffle()->take(4)->implode('');
        $chiffres = collect(range(0, 9))->shuffle()->take(4)->implode('');
        return $lettres . $chiffres;
    }

    // ── Conservées pour compatibilité avec l'app Flutter existante ─

    // Modifier uniquement le rôle (utilisé par gestion_utilisateurs_screen.dart)
    public function modifierRole(Request $request, $id)
    {
        $request->validate([
            'role' => 'required|in:' . implode(',', self::ROLES_GERES),
        ]);

        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $utilisateur->update(['role' => $request->role]);

        return response()->json(['message' => 'Rôle mis à jour']);
    }

    // Modifier les permissions modules
    public function modifierModules(Request $request, $id)
    {
        $request->validate([
            'permissions'              => 'required|array',
            'permissions.*.nom_module' => 'required|string',
            'permissions.*.autorise'   => 'required|boolean',
        ]);

        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        foreach ($request->permissions as $perm) {
            PermissionModule::updateOrCreate(
                [
                    'utilisateur_id' => $utilisateur->id,
                    'nom_module'     => $perm['nom_module'],
                ],
                ['autorise' => $perm['autorise']]
            );
        }

        return response()->json(['message' => 'Permissions mises à jour']);
    }
}
