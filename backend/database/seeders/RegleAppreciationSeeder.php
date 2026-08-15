<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\RegleAppreciation;
use Illuminate\Database\Seeder;

class RegleAppreciationSeeder extends Seeder
{
    /**
     * Barème par défaut : note_min/note_max => libellé.
     */
    private const BAREME_DEFAUT = [
        ['note_min' => 16, 'note_max' => 20, 'libelle_appreciation' => 'Excellent'],
        ['note_min' => 14, 'note_max' => 15.99, 'libelle_appreciation' => 'Très bien'],
        ['note_min' => 12, 'note_max' => 13.99, 'libelle_appreciation' => 'Bien'],
        ['note_min' => 10, 'note_max' => 11.99, 'libelle_appreciation' => 'Passable'],
        ['note_min' => 0, 'note_max' => 9.99, 'libelle_appreciation' => 'Insuffisant'],
    ];

    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        self::pourEcole($ecole->id);
    }

    /**
     * Crée le barème d'appréciation par défaut d'une école — réutilisable
     * pour toute nouvelle école, ex. à appeler depuis
     * Auth\InscriptionEcoleController::inscrire() lors de l'onboarding, en
     * plus de cet appel via DatabaseSeeder.
     */
    public static function pourEcole(int $ecoleId): void
    {
        foreach (self::BAREME_DEFAUT as $regle) {
            RegleAppreciation::firstOrCreate(
                [
                    'ecole_id' => $ecoleId,
                    'note_min' => $regle['note_min'],
                    'note_max' => $regle['note_max'],
                ],
                ['libelle_appreciation' => $regle['libelle_appreciation']]
            );
        }
    }
}
