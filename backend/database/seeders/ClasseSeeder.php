<?php

namespace Database\Seeders;

use App\Models\Classe;
use App\Models\Ecole;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class ClasseSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        $classes = [
            ['nom' => '6ème A', 'niveau' => '6ème'],
            ['nom' => '5ème A', 'niveau' => '5ème'],
            ['nom' => '4ème A', 'niveau' => '4ème'],
            ['nom' => '3ème A', 'niveau' => '3ème'],
            ['nom' => 'Seconde A', 'niveau' => 'Seconde'],
            ['nom' => 'Première A', 'niveau' => 'Première'],
            ['nom' => 'Terminale A', 'niveau' => 'Terminale'],
        ];

        foreach ($classes as $classe) {
            Classe::firstOrCreate(
                [
                    'ecole_id' => $ecole->id,
                    'nom' => $classe['nom'],
                ],
                [
                    'niveau' => $classe['niveau'],
                    'capacite_max' => 40,
                ]
            );
        }
    }
}
