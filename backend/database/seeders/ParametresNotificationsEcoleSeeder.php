<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\ParametreNotification;
use Illuminate\Database\Seeder;

class ParametresNotificationsEcoleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        self::pourEcole($ecole->id);
    }

    /**
     * Crée (tous actifs) les types de notifications par défaut d'une
     * école — réutilisable pour toute nouvelle école, ex. à appeler
     * depuis Auth\InscriptionEcoleController::inscrire() lors de
     * l'onboarding, en plus de cet appel via DatabaseSeeder.
     */
    public static function pourEcole(int $ecoleId): void
    {
        foreach (ParametreNotification::TYPES_NOTIFICATIONS as $cible => $types) {
            foreach (array_keys($types) as $cle) {
                ParametreNotification::firstOrCreate(
                    ['ecole_id' => $ecoleId, 'cible' => $cible, 'cle' => $cle],
                    ['valeur' => true]
                );
            }
        }
    }
}
