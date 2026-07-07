<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\Matiere;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class MatiereSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        $matieres = [
            ['nom' => 'Mathématiques', 'code' => 'MATH', 'coefficient' => 4],
            ['nom' => 'Français', 'code' => 'FR', 'coefficient' => 3],
            ['nom' => 'Anglais', 'code' => 'ANG', 'coefficient' => 2],
            ['nom' => 'SVT', 'code' => 'SVT', 'coefficient' => 2],
            ['nom' => 'Physique-Chimie', 'code' => 'PC', 'coefficient' => 3],
            ['nom' => 'Histoire-Géographie', 'code' => 'HG', 'coefficient' => 2],
            ['nom' => 'Philosophie', 'code' => 'PHILO', 'coefficient' => 2],
            ['nom' => 'EPS', 'code' => 'EPS', 'coefficient' => 1],
            ['nom' => 'Informatique', 'code' => 'INFO', 'coefficient' => 2],
            ['nom' => 'Espagnol', 'code' => 'ESP', 'coefficient' => 1],
        ];

        foreach ($matieres as $matiere) {
            Matiere::firstOrCreate(
                [
                    'ecole_id' => $ecole->id,
                    'nom' => $matiere['nom'],
                ],
                [
                    'code' => $matiere['code'],
                    'coefficient' => $matiere['coefficient'],
                ]
            );
        }
    }
}
