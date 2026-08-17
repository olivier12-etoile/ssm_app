<?php

namespace App\Services;

use App\Models\ClasseMatiere;
use App\Models\Eleve;
use App\Models\FraisScolaire;
use App\Models\ModeleMessage;
use App\Models\Paiement;
use App\Models\ParametreNotification;
use App\Models\Presence;
use App\Models\SaisieNote;
use App\Models\User;
use Illuminate\Support\Facades\Log;

/**
 * Relie les modules existants (Notes, Paiements, Frais Scolaires, Absences)
 * au module Notifications : pour chaque type d'événement, choisit le modèle
 * de message et la cible à notifier, puis délègue l'envoi réel à
 * EnvoiNotificationService (qui réutilise notifications_attente pour le
 * canal whatsapp).
 *
 * Chaque méthode est un no-op silencieux (avec log) si :
 * - le déclencheur est désactivé pour l'école (ParametreNotification)
 * - le modèle de message correspondant est introuvable/inactif
 * - il n'y a aucun destinataire joignable
 * Un événement métier existant (validation de notes, paiement...) ne doit
 * jamais échouer à cause d'une notification qui ne part pas.
 */
class DeclencheurNotificationService
{
    private const CLE_NOTES_VALIDEES      = 'notes_validees';
    private const CLE_PAIEMENT_ENREGISTRE = 'paiement_enregistre';
    private const CLE_IMPAYE              = 'impaye';
    private const CLE_BULLETIN            = 'bulletin_disponible';
    private const CLE_ABSENCE             = 'absence';

    public function __construct(private EnvoiNotificationService $envoiService)
    {
    }

    /**
     * À appeler après qu'une SaisieNote passe au statut "validee"
     * (ValidationNoteController->valider()). Ne notifie que si TOUTES les
     * matières de la classe sont désormais validées pour cette période —
     * sinon on attendrait juste la prochaine validation de matière.
     */
    public function surNotesValidees(int $saisieNoteId, ?int $declenchePar = null): void
    {
        $saisie = SaisieNote::findOrFail($saisieNoteId);

        if ($saisie->statut !== 'validee') {
            return;
        }

        if (!ParametreNotification::estActif($saisie->ecole_id, self::CLE_NOTES_VALIDEES)) {
            return;
        }

        if (!$this->classeCompletementValidee($saisie->classe_id, $saisie->periode_id)) {
            return;
        }

        $modele = $this->modele($saisie->ecole_id, 'Résultats disponibles');
        if (!$modele) {
            return;
        }

        $auteur = $this->resoudreAuteur($saisie->ecole_id, $declenchePar);
        if (!$auteur) {
            return;
        }

        $notification = $this->envoiService->creerNotification($saisie->ecole_id, $auteur, [
            'titre'             => $modele->nom,
            'message'           => $modele->contenu,
            'modele_message_id' => $modele->id,
            'type_cible'        => 'classe',
            // periode_id (en plus de classe_id) permet à EnvoiNotificationService
            // de calculer {moyenne}/{periode} sur LA période validée, pas sur
            // la période active courante de l'école (voir VariableNotificationService).
            'cibles'            => ['classe_id' => $saisie->classe_id, 'periode_id' => $saisie->periode_id],
            'canal'             => 'whatsapp',
        ]);

        $this->envoiService->envoyerMaintenant($notification->id);
    }

    /**
     * À appeler après l'enregistrement réussi d'un paiement
     * (PaiementController->store()), en remplacement de l'ancien appel
     * direct à NotificationAttente::create() (voir note d'intégration).
     */
    public function surPaiementEnregistre(int $paiementId, ?int $declenchePar = null): void
    {
        $paiement = Paiement::with('eleve')->findOrFail($paiementId);

        if ($paiement->statut !== 'valide' || !$paiement->eleve) {
            return;
        }

        $ecoleId = $paiement->eleve->ecole_id;

        if (!ParametreNotification::estActif($ecoleId, self::CLE_PAIEMENT_ENREGISTRE)) {
            return;
        }

        if (!$paiement->eleve->telephone_parent) {
            return;
        }

        $this->notifierEleve(
            $ecoleId,
            $paiement->eleve_id,
            'Paiement reçu',
            $declenchePar
        );
    }

    /**
     * À appeler manuellement ou via la commande notifications:impayes
     * (voir NotifierImpayesCommand) pour un élève avec un solde impayé sur
     * un frais donné.
     */
    public function surImpaye(int $eleveId, int $fraisScolaireId, ?int $declenchePar = null): void
    {
        $eleve = Eleve::findOrFail($eleveId);
        FraisScolaire::findOrFail($fraisScolaireId);

        if (!ParametreNotification::estActif($eleve->ecole_id, self::CLE_IMPAYE)) {
            return;
        }

        if (!$eleve->telephone_parent) {
            return;
        }

        // frais_scolaire_id est porté dans cibles pour permettre la
        // déduplication par NotifierImpayesCommand (voir dejaNotifieRecemment).
        $this->notifierEleve(
            $eleve->ecole_id,
            $eleve->id,
            "Rappel d'impayé",
            $declenchePar,
            ['frais_scolaire_id' => $fraisScolaireId]
        );
    }

    /**
     * À appeler quand un bulletin est officiellement validé (pas seulement
     * généré : on ne notifie le parent qu'une fois le bulletin figé par
     * ValidationBulletinController, pas à chaque brouillon régénéré).
     * Câblée dans ValidationBulletinController::validerBulletin() (module
     * Bulletins, Phase 3/5), juste après le passage du statut à "valide" —
     * ce point unique couvre à la fois la validation individuelle
     * (valider()) et la validation en masse (validerEnMasse()).
     *
     * Il existe encore une ancienne route /bulletins/notifier
     * (BulletinController::notifierBulletin()) qui crée sa propre
     * NotificationAttente à la main : elle repose sur le modèle Evaluation
     * désormais supprimé (voir migration drop_evaluations_tables) et est
     * donc déjà inopérante — pas de risque de double notification avec ce
     * nouveau câblage.
     */
    public function surBulletinDisponible(int $eleveId, int $periodeId, ?int $declenchePar = null): void
    {
        $eleve = Eleve::findOrFail($eleveId);

        if (!ParametreNotification::estActif($eleve->ecole_id, self::CLE_BULLETIN)) {
            return;
        }

        if (!$eleve->telephone_parent) {
            return;
        }

        $modele = $this->modele($eleve->ecole_id, 'Bulletin disponible');
        if (!$modele) {
            return;
        }

        $auteur = $this->resoudreAuteur($eleve->ecole_id, $declenchePar);
        if (!$auteur) {
            return;
        }

        $notification = $this->envoiService->creerNotification($eleve->ecole_id, $auteur, [
            'titre'             => $modele->nom,
            'message'           => $modele->contenu,
            'modele_message_id' => $modele->id,
            'type_cible'        => 'eleve',
            'cibles'            => ['eleve_id' => $eleve->id, 'periode_id' => $periodeId],
            'canal'             => 'whatsapp',
        ]);

        $this->envoiService->envoyerMaintenant($notification->id);
    }

    /**
     * À appeler après qu'un appel de présence est terminé
     * (PresenceService->terminerAppel()), pour chaque élève marqué absent
     * (ou en retard, selon le paramétrage) pas encore notifié. $presenceId
     * référence une ligne de la table presences (module Présences), pas
     * l'ancien module Absences (App\Models\Absence, resté isolé — voir
     * AbsenceController qui compose son propre message via
     * MessageTemplateService et ne passe pas par ce déclencheur).
     *
     * Utilise le modèle « Retard signalé » pour un retard, « Absence
     * signalée » sinon (avec repli sur « Absence signalée » si le modèle
     * de retard n'est pas encore paramétré pour l'école).
     */
    public function surAbsence(int $presenceId, ?int $declenchePar = null): void
    {
        $presence = Presence::with(['eleve', 'appelPresence.classe', 'appelPresence.matiere'])->findOrFail($presenceId);

        if (!$presence->eleve) {
            return;
        }

        $ecoleId = $presence->eleve->ecole_id;

        if (!ParametreNotification::estActif($ecoleId, self::CLE_ABSENCE)) {
            return;
        }

        if (!$presence->eleve->telephone_parent) {
            return;
        }

        $nomModele = $presence->statut === 'retard' ? 'Retard signalé' : 'Absence signalée';
        $modele = $this->modele($ecoleId, $nomModele) ?? $this->modele($ecoleId, 'Absence signalée');
        if (!$modele) {
            return;
        }

        $auteur = $this->resoudreAuteur($ecoleId, $declenchePar);
        if (!$auteur) {
            return;
        }

        $appel = $presence->appelPresence;

        // classe/matiere/date sont portées dans cibles pour qu'EnvoiNotificationService
        // les substitue aux variables {classe}/{matiere}/{date} du modèle à la
        // place des valeurs par défaut (classe d'inscription courante, date du
        // jour) — voir VariableNotificationService::remplacerVariables().
        $notification = $this->envoiService->creerNotification($ecoleId, $auteur, [
            'titre'             => $modele->nom,
            'message'           => $modele->contenu,
            'modele_message_id' => $modele->id,
            'type_cible'        => 'eleve',
            'cibles'            => [
                'eleve_id' => $presence->eleve_id,
                'classe'   => $appel?->classe?->nom,
                'matiere'  => $appel?->matiere?->nom,
                'date'     => $appel?->date_appel?->format('d/m/Y'),
            ],
            'canal' => 'whatsapp',
        ]);

        $this->envoiService->envoyerMaintenant($notification->id);
    }

    // ── Aides internes ────────────────────────────────────────────

    // Crée puis envoie immédiatement une notification whatsapp mono-élève à
    // partir d'un modèle nommé existant. Factorisé car surPaiementEnregistre,
    // surImpaye et surAbsence ont exactement cette forme.
    private function notifierEleve(
        int $ecoleId,
        int $eleveId,
        string $nomModele,
        ?int $declenchePar,
        array $ciblesSupplementaires = []
    ): void {
        $modele = $this->modele($ecoleId, $nomModele);
        if (!$modele) {
            return;
        }

        $auteur = $this->resoudreAuteur($ecoleId, $declenchePar);
        if (!$auteur) {
            return;
        }

        $notification = $this->envoiService->creerNotification($ecoleId, $auteur, [
            'titre'             => $modele->nom,
            'message'           => $modele->contenu,
            'modele_message_id' => $modele->id,
            'type_cible'        => 'eleve',
            'cibles'            => array_merge(['eleve_id' => $eleveId], $ciblesSupplementaires),
            'canal'             => 'whatsapp',
        ]);

        $this->envoiService->envoyerMaintenant($notification->id);
    }

    private function modele(int $ecoleId, string $nom): ?ModeleMessage
    {
        $modele = ModeleMessage::where('ecole_id', $ecoleId)
            ->where('nom', $nom)
            ->where('actif', true)
            ->first();

        if (!$modele) {
            Log::warning("DeclencheurNotificationService : modèle « {$nom} » introuvable ou inactif pour l'école {$ecoleId}.");
        }

        return $modele;
    }

    // notifications.cree_par est obligatoire : on utilise l'utilisateur à
    // l'origine de l'action métier quand il est connu (ex: qui a validé les
    // notes / enregistré le paiement), sinon le directeur de l'école (cas
    // des déclencheurs lancés hors requête HTTP, ex: commande planifiée).
    private function resoudreAuteur(int $ecoleId, ?int $declenchePar): ?int
    {
        if ($declenchePar) {
            return $declenchePar;
        }

        $directeurId = User::where('ecole_id', $ecoleId)->where('role', 'directeur')->value('id');

        if (!$directeurId) {
            Log::warning("DeclencheurNotificationService : aucun directeur trouvé pour l'école {$ecoleId}, notification annulée.");
        }

        return $directeurId;
    }

    // Une classe est "complètement validée" pour une période quand toutes
    // les matières de son curriculum (classe_matiere) ont une SaisieNote
    // au statut "validee" pour cette période.
    private function classeCompletementValidee(int $classeId, int $periodeId): bool
    {
        $matiereIds = ClasseMatiere::where('classe_id', $classeId)->pluck('matiere_id');

        if ($matiereIds->isEmpty()) {
            return false;
        }

        $matieresValidees = SaisieNote::where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->where('statut', 'validee')
            ->whereIn('matiere_id', $matiereIds)
            ->pluck('matiere_id')
            ->unique();

        return $matiereIds->diff($matieresValidees)->isEmpty();
    }
}
