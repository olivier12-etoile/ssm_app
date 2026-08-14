<?php

namespace App\Console\Commands;

use App\Models\Ecole;
use App\Models\Eleve;
use App\Models\FraisScolaire;
use App\Models\Notification;
use App\Models\ParametreNotification;
use App\Services\DeclencheurNotificationService;
use App\Services\FraisCalculService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class NotifierImpayesCommand extends Command
{
    protected $signature = 'notifications:impayes
        {--jours=7 : Nombre de jours après la date limite avant de considérer un frais en retard}
        {--relance=7 : Délai minimum (en jours) avant de renotifier le même élève pour le même frais}';

    protected $description = "Notifie les parents des élèves dont un frais scolaire est impayé au-delà du seuil configuré";

    public function __construct(
        private DeclencheurNotificationService $declencheurService,
        private FraisCalculService $fraisCalculService,
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $joursRetard  = (int) $this->option('jours');
        $joursRelance = (int) $this->option('relance');
        $dateLimiteMax = now()->subDays($joursRetard)->toDateString();

        $totalNotifications = 0;
        $totalEcoles        = 0;

        Ecole::chunk(50, function ($ecoles) use ($dateLimiteMax, $joursRelance, &$totalNotifications, &$totalEcoles) {
            foreach ($ecoles as $ecole) {
                if (!ParametreNotification::estActif($ecole->id, 'impaye')) {
                    continue;
                }

                $totalEcoles++;

                $fraisEnRetard = FraisScolaire::where('ecole_id', $ecole->id)
                    ->where('actif', true)
                    ->whereDate('date_limite', '<=', $dateLimiteMax)
                    ->get();

                foreach ($fraisEnRetard as $frais) {
                    $totalNotifications += $this->notifierPourFrais($frais, $joursRelance);
                }
            }
        });

        $resume = "notifications:impayes : {$totalNotifications} notification(s) créée(s) sur {$totalEcoles} école(s) traitée(s) "
            . "(retard > {$joursRetard}j, relance > {$joursRelance}j).";

        Log::info($resume);
        $this->info($resume);

        return self::SUCCESS;
    }

    // Notifie chaque élève concerné par un frais donné (encore dû, pas déjà
    // relancé récemment) et retourne le nombre de notifications créées.
    private function notifierPourFrais(FraisScolaire $frais, int $joursRelance): int
    {
        $eleves = Eleve::where('ecole_id', $frais->ecole_id)
            ->where('statut', 'actif')
            ->whereHas('inscriptions', fn($q) => $q->where('annee_academique_id', $frais->annee_scolaire_id))
            ->get();

        $nombreNotifies = 0;

        foreach ($eleves as $eleve) {
            $resteAPayer = $this->fraisCalculService->resteAPayer($eleve, $frais);

            if ($resteAPayer <= 0) {
                continue;
            }

            if ($this->dejaNotifieRecemment($eleve->id, $frais->id, $joursRelance)) {
                continue;
            }

            $this->declencheurService->surImpaye($eleve->id, $frais->id);
            $nombreNotifies++;
        }

        return $nombreNotifies;
    }

    // Évite de renotifier le même élève pour le même frais à chaque
    // exécution de la commande : on regarde s'il existe déjà une
    // notification "Rappel d'impayé" pour ce couple (élève, frais) dans la
    // fenêtre de relance.
    private function dejaNotifieRecemment(int $eleveId, int $fraisScolaireId, int $joursRelance): bool
    {
        return Notification::withoutGlobalScope('parEcole')
            ->where('titre', "Rappel d'impayé")
            ->where('cibles->eleve_id', $eleveId)
            ->where('cibles->frais_scolaire_id', $fraisScolaireId)
            ->where('created_at', '>=', now()->subDays($joursRelance))
            ->exists();
    }
}
