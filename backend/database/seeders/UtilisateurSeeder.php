<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class UtilisateurSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        $utilisateurs = [
            ['email' => 'censeur@afrinova.tg', 'name' => 'Censeur AfriNova', 'role' => 'censeur'],
            ['email' => 'secretaire@afrinova.tg', 'name' => 'Secrétaire AfriNova', 'role' => 'secretaire'],
            ['email' => 'prof.maths@afrinova.tg', 'name' => 'Kofi Mensah', 'role' => 'enseignant'],
            ['email' => 'prof.francais@afrinova.tg', 'name' => 'Ama Koffi', 'role' => 'enseignant'],
            ['email' => 'prof.anglais@afrinova.tg', 'name' => 'Edem Agbeko', 'role' => 'enseignant'],
            ['email' => 'prof.svt@afrinova.tg', 'name' => 'Akosua Dovi', 'role' => 'enseignant'],
            ['email' => 'prof.physique@afrinova.tg', 'name' => 'Kwame Atsu', 'role' => 'enseignant'],
            ['email' => 'prof.histgeo@afrinova.tg', 'name' => 'Abena Adzoa', 'role' => 'enseignant'],
            ['email' => 'prof.info@afrinova.tg', 'name' => 'Selom Agbenyega', 'role' => 'enseignant'],
        ];

        foreach ($utilisateurs as $utilisateur) {
            User::firstOrCreate(
                ['email' => $utilisateur['email']],
                [
                    'name' => $utilisateur['name'],
                    'password' => 'password123',
                    'role' => $utilisateur['role'],
                    'ecole_id' => $ecole->id,
                    'mot_de_passe_change' => true,
                ]
            );
        }
    }
}
