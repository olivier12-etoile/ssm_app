<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class EcoleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::firstOrCreate(
            ['code_ecole' => '4DTI5X'],
            [
                'nom' => 'Institut AfriNova',
                'couleur_primaire' => '#1565C0',
                'telephone' => '+22890000000',
                'adresse' => 'Lomé Togo',
            ]
        );

        User::firstOrCreate(
            ['email' => 'directeur@afrinova.tg'],
            [
                'name' => 'Directeur AfriNova',
                'password' => 'password123',
                'role' => 'directeur',
                'ecole_id' => $ecole->id,
                'mot_de_passe_change' => true,
            ]
        );
    }
}
