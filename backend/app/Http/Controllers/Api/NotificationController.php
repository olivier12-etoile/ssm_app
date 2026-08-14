<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ModeleMessage;
use App\Models\Notification;
use App\Services\CiblageNotificationService;
use App\Services\EnvoiNotificationService;
use App\Services\VariableNotificationService;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    // Catégories autorisées par rôle. directeur (et super_admin) n'ont pas
    // de restriction. Un enseignant ne peut pas envoyer de notification
    // libre (seul le signalement d'absence, géré par AbsenceController, lui
    // est ouvert).
    private const CATEGORIES_PAR_ROLE = [
        'censeur'    => ['scolarite'],
        'secretaire' => ['administration', 'presence'],
        'comptable'  => ['finances'],
    ];

    public function __construct(
        private CiblageNotificationService $ciblageService,
        private VariableNotificationService $variableService,
        private EnvoiNotificationService $envoiService,
    ) {
    }

    // Aperçu du nombre de destinataires réels avant confirmation d'envoi massif
    public function apercu(Request $request)
    {
        $data = $request->validate([
            'type_cible' => 'required|in:ecole_entiere,classe,plusieurs_classes,eleve,enseignants,personnel_administratif',
            'cibles'     => 'nullable|array',
        ]);

        $nombre = $this->ciblageService->compterDestinataires(
            $request->user()->ecole_id,
            $data['type_cible'],
            $data['cibles'] ?? null
        );

        return response()->json(['nombre_destinataires' => $nombre]);
    }

    // Aperçu du rendu d'un message avec les vraies données d'un élève exemple
    public function apercuMessage(Request $request)
    {
        $data = $request->validate([
            'contenu'          => 'required|string',
            'eleve_id_exemple' => 'required|integer|exists:eleves,id',
        ]);

        return response()->json(
            $this->variableService->genererApercu($data['contenu'], $data['eleve_id_exemple'])
        );
    }

    // Historique des notifications, filtrable par statut/canal/catégorie/date/titre
    public function index(Request $request)
    {
        $query = $this->requeteFiltree($request);

        return response()->json(['notifications' => $query->paginate(20)]);
    }

    // Export CSV (compatible Excel) de l'historique filtré — mêmes filtres
    // que index(), sans pagination.
    public function exporterExcel(Request $request)
    {
        $notifications = $this->requeteFiltree($request)->get();

        $callback = function () use ($notifications) {
            $fichier = fopen('php://output', 'w');
            fwrite($fichier, "\xEF\xBB\xBF");
            fputcsv($fichier, [
                'Titre', 'Catégorie', 'Cible', 'Canal', 'Statut', 'Urgent',
                'Destinataires', 'Envoyés', 'Échoués', 'Créée par', 'Date de création',
            ]);

            foreach ($notifications as $n) {
                fputcsv($fichier, [
                    $n->titre,
                    $n->modeleMessage?->categorie,
                    $n->type_cible,
                    $n->canal,
                    $n->statut,
                    $n->urgent ? 'Oui' : 'Non',
                    $n->nombre_destinataires,
                    $n->nombre_envoyes,
                    $n->nombre_echoues,
                    $n->auteur?->name,
                    $n->created_at?->format('d/m/Y H:i'),
                ]);
            }

            fclose($fichier);
        };

        return response()->stream($callback, 200, [
            'Content-Type'        => 'text/csv',
            'Content-Disposition' => 'attachment; filename="notifications.csv"',
        ]);
    }

    private function requeteFiltree(Request $request)
    {
        $query = Notification::where('ecole_id', $request->user()->ecole_id)
            ->with('modeleMessage', 'auteur');

        if ($request->filled('statut')) {
            $query->where('statut', $request->statut);
        }

        if ($request->filled('canal')) {
            $query->where('canal', $request->canal);
        }

        if ($request->filled('categorie')) {
            $query->whereHas('modeleMessage', fn($q) => $q->where('categorie', $request->categorie));
        }

        if ($request->filled('recherche')) {
            $query->where('titre', 'like', '%' . $request->recherche . '%');
        }

        if ($request->filled('date_debut')) {
            $query->whereDate('created_at', '>=', $request->date_debut);
        }

        if ($request->filled('date_fin')) {
            $query->whereDate('created_at', '<=', $request->date_fin);
        }

        return match ($request->input('tri', 'recent')) {
            'destinataires' => $query->orderByDesc('nombre_destinataires'),
            default          => $query->orderByDesc('created_at'),
        };
    }

    // Détail d'une notification avec la liste de ses destinataires et leur statut
    public function show(Request $request, $id)
    {
        $notification = Notification::where('ecole_id', $request->user()->ecole_id)
            ->with(['modeleMessage', 'auteur', 'destinataires'])
            ->findOrFail($id);

        return response()->json(['notification' => $notification]);
    }

    public function store(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $data = $request->validate([
            'titre'             => 'required|string|max:255',
            'message'           => 'required_without:modele_message_id|nullable|string',
            'modele_message_id' => 'nullable|integer|exists:modeles_messages,id',
            'type_cible'        => 'required|in:ecole_entiere,classe,plusieurs_classes,eleve,enseignants,personnel_administratif',
            'cibles'            => 'nullable|array',
            'canal'             => 'required|in:whatsapp,sms,interne,email',
            'urgent'            => 'boolean',
            'programmee'        => 'boolean',
            'date_envoi_prevue' => 'required_if:programmee,true|nullable|date',
        ]);

        $categorie = null;
        if (!empty($data['modele_message_id'])) {
            $modele = ModeleMessage::where('ecole_id', $ecoleId)->findOrFail($data['modele_message_id']);
            $categorie      = $modele->categorie;
            $data['message'] = $data['message'] ?? $modele->contenu;
        }

        $erreurPermission = $this->verifierPermission($request->user()->role, $categorie);
        if ($erreurPermission) {
            return response()->json(['message' => $erreurPermission], 403);
        }

        $notification = $this->envoiService->creerNotification($ecoleId, $request->user()->id, $data);

        if (empty($data['programmee'])) {
            $notification = $this->envoiService->envoyerMaintenant($notification->id);
        }

        return response()->json(['notification' => $notification], 201);
    }

    // Annule une notification programmée qui n'a pas encore été envoyée
    public function annulerProgrammee(Request $request, $id)
    {
        $notification = Notification::where('ecole_id', $request->user()->ecole_id)->findOrFail($id);

        if ($notification->statut !== 'programmee') {
            return response()->json([
                'message' => "Seule une notification programmée et non encore envoyée peut être annulée.",
            ], 422);
        }

        $notification->delete();

        return response()->json(['message' => 'Notification programmée annulée.']);
    }

    // Retourne un message d'erreur si le rôle n'est pas autorisé, ou null si l'envoi est permis.
    private function verifierPermission(string $role, ?string $categorie): ?string
    {
        if (in_array($role, ['directeur', 'super_admin'], true)) {
            return null;
        }

        if ($role === 'enseignant') {
            return "Les enseignants ne peuvent pas envoyer de notification libre.";
        }

        $categoriesAutorisees = self::CATEGORIES_PAR_ROLE[$role] ?? null;

        if (!$categoriesAutorisees) {
            return "Votre rôle n'est pas autorisé à envoyer des notifications.";
        }

        if (!$categorie || !in_array($categorie, $categoriesAutorisees, true)) {
            return 'Vous ne pouvez envoyer que des notifications de catégorie : '
                . implode(', ', $categoriesAutorisees) . '.';
        }

        return null;
    }
}
