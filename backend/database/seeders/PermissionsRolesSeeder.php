<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\PermissionRole;
use Illuminate\Database\Seeder;

class PermissionsRolesSeeder extends Seeder
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
     * Crée la matrice de permissions par défaut (tous rôles × tous
     * modules) d'une école — réutilisable pour toute nouvelle école, ex. à
     * appeler depuis Auth\InscriptionEcoleController::inscrire() lors de
     * l'onboarding, en plus de cet appel via DatabaseSeeder. Idempotent :
     * n'écrase pas une ligne déjà personnalisée par le directeur.
     */
    public static function pourEcole(int $ecoleId): void
    {
        foreach (PermissionRole::lignesDefaut($ecoleId) as $ligne) {
            PermissionRole::firstOrCreate(
                ['ecole_id' => $ligne['ecole_id'], 'role' => $ligne['role'], 'module' => $ligne['module']],
                $ligne
            );
        }
    }
}
