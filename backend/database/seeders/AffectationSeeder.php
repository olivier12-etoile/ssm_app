<?php

namespace Database\Seeders;

use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\Ecole;
use App\Models\Matiere;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class AffectationSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        $matieres = Matiere::where('ecole_id', $ecole->id)->get()->keyBy('nom');
        $classes = Classe::where('ecole_id', $ecole->id)->get()->keyBy('nom');
        $enseignants = User::where('ecole_id', $ecole->id)
            ->where('role', 'enseignant')
            ->get()
            ->keyBy('email');

        $affectations = [
            'prof.maths@afrinova.tg' => [
                'matiere' => 'Mathématiques',
                'classes' => ['6ème A', '5ème A', '4ème A'],
            ],
            'prof.francais@afrinova.tg' => [
                'matiere' => 'Français',
                'classes' => ['6ème A', '3ème A', 'Seconde A'],
            ],
            'prof.anglais@afrinova.tg' => [
                'matiere' => 'Anglais',
                'classes' => ['5ème A', 'Première A', 'Terminale A'],
            ],
            'prof.svt@afrinova.tg' => [
                'matiere' => 'SVT',
                'classes' => ['6ème A', '4ème A', '3ème A'],
            ],
            'prof.physique@afrinova.tg' => [
                'matiere' => 'Physique-Chimie',
                'classes' => ['Seconde A', 'Première A', 'Terminale A'],
            ],
            'prof.histgeo@afrinova.tg' => [
                'matiere' => 'Histoire-Géographie',
                'classes' => ['5ème A', '3ème A', 'Première A'],
            ],
            'prof.info@afrinova.tg' => [
                'matiere' => 'Informatique',
                'classes' => ['4ème A', 'Seconde A', 'Terminale A'],
            ],
        ];

        foreach ($affectations as $email => $affectation) {
            $enseignant = $enseignants->get($email);
            $matiere = $matieres->get($affectation['matiere']);

            if (!$enseignant || !$matiere) {
                continue;
            }

            foreach ($affectation['classes'] as $nomClasse) {
                $classe = $classes->get($nomClasse);

                if (!$classe) {
                    continue;
                }

                $existe = DB::table('enseignant_classe_matiere')
                    ->where('enseignant_id', $enseignant->id)
                    ->where('classe_id', $classe->id)
                    ->where('matiere_id', $matiere->id)
                    ->exists();

                if ($existe) {
                    continue;
                }

                DB::table('enseignant_classe_matiere')->insert([
                    'enseignant_id' => $enseignant->id,
                    'classe_id' => $classe->id,
                    'matiere_id' => $matiere->id,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }

        $coefficientsCollege = [
            'Mathématiques' => 3,
            'Français' => 3,
            'Anglais' => 2,
            'SVT' => 2,
            'Histoire-Géographie' => 2,
            'EPS' => 1,
            'Informatique' => 2,
        ];

        $coefficientsParClasse = [
            '6ème A' => $coefficientsCollege,
            '5ème A' => $coefficientsCollege,
            '4ème A' => $coefficientsCollege,
            '3ème A' => $coefficientsCollege,
            'Seconde A' => [
                'Mathématiques' => 4,
                'Français' => 3,
                'Anglais' => 2,
                'SVT' => 2,
                'Physique-Chimie' => 3,
                'Histoire-Géographie' => 2,
                'EPS' => 1,
                'Informatique' => 2,
            ],
            'Première A' => [
                'Mathématiques' => 4,
                'Français' => 3,
                'Anglais' => 2,
                'SVT' => 2,
                'Physique-Chimie' => 3,
                'Histoire-Géographie' => 2,
                'Philosophie' => 2,
                'EPS' => 1,
                'Informatique' => 2,
                'Espagnol' => 1,
            ],
            'Terminale A' => [
                'Mathématiques' => 5,
                'Français' => 3,
                'Anglais' => 2,
                'SVT' => 2,
                'Physique-Chimie' => 3,
                'Histoire-Géographie' => 2,
                'Philosophie' => 3,
                'EPS' => 1,
                'Informatique' => 2,
                'Espagnol' => 1,
            ],
        ];

        foreach ($coefficientsParClasse as $nomClasse => $matieresCoefficients) {
            $classe = $classes->get($nomClasse);

            if (!$classe) {
                continue;
            }

            foreach ($matieresCoefficients as $nomMatiere => $coefficient) {
                $matiere = $matieres->get($nomMatiere);

                if (!$matiere) {
                    continue;
                }

                ClasseMatiere::firstOrCreate(
                    [
                        'classe_id' => $classe->id,
                        'matiere_id' => $matiere->id,
                    ],
                    [
                        'coefficient' => $coefficient,
                    ]
                );
            }
        }
    }
}
