<?php

namespace Database\Seeders;

use App\Models\AnneeAcademique;
use App\Models\Ecole;
use App\Models\Eleve;
use App\Models\Inscription;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class EleveSeeder extends Seeder
{
    private const ELEVES_PAR_CLASSE = 18;

    private array $prenomsGarcons = [
        'Kofi', 'Kwame', 'Kwesi', 'Yao', 'Komi', 'Edem', 'Selom', 'Mawuli',
        'Elom', 'Kwabena', 'Kojo', 'Kobla', 'Fiifi', 'Yawo', 'Dodji',
        'Messan', 'Komlan', 'Enam', 'Sena', 'Dieudonné',
    ];

    private array $prenomsFilles = [
        'Ama', 'Akosua', 'Abena', 'Efua', 'Adjoa', 'Akua', 'Afi', 'Ablavi',
        'Akpene', 'Enyonam', 'Afiba', 'Delali', 'Sitou', 'Yawa', 'Adjovi',
        'Abra', 'Perpétue', 'Rachelle', 'Akouvi', 'Mawusi',
    ];

    private array $noms = [
        'Mensah', 'Koffi', 'Agbeko', 'Dovi', 'Atsu', 'Adzoa', 'Agbenyega',
        'Amegan', 'Kponton', 'Lawson', 'Sedjro', 'Amoussou', 'Gnansounou',
        'Houngbo', 'Adjahoui', 'Toklo', 'Ayivi', 'Agbodjan', 'Nyamador',
        'Tchamie', 'Kpogbe', 'Adom', 'Djobo', 'Assogba', 'Zinsou',
        'Padonou', 'Hounkpatin', 'Amewu', 'Klu', 'Bativi',
    ];

    private array $agesParNiveau = [
        '6ème' => 11,
        '5ème' => 12,
        '4ème' => 13,
        '3ème' => 14,
        'Seconde' => 15,
        'Première' => 16,
        'Terminale' => 17,
    ];

    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();
        $annee = AnneeAcademique::where('ecole_id', $ecole->id)
            ->where('libelle', '2024-2025')
            ->firstOrFail();

        $classes = $ecole->classes()->orderBy('id')->get();

        foreach ($classes as $ci => $classe) {
            $ageBase = $this->agesParNiveau[$classe->niveau] ?? 12;

            for ($i = 0; $i < self::ELEVES_PAR_CLASSE; $i++) {
                $sexe = $i % 2 === 0 ? 'M' : 'F';
                $rangGenre = intdiv($i, 2);

                $prenom = $sexe === 'M'
                    ? $this->prenomsGarcons[($ci * 9 + $rangGenre) % count($this->prenomsGarcons)]
                    : $this->prenomsFilles[($ci * 9 + $rangGenre) % count($this->prenomsFilles)];

                $nom = $this->noms[($ci * self::ELEVES_PAR_CLASSE + $i) % count($this->noms)];

                $matricule = sprintf('ELV%02d%03d', $ci + 1, $i + 1);

                $dateNaissance = now()
                    ->subYears($ageBase)
                    ->subMonths(($ci + $i) % 12)
                    ->subDays(($ci * 3 + $i * 5) % 28)
                    ->format('Y-m-d');

                $telephoneParent = sprintf('+2289%08d', (10000000 + $ci * 1000 + $i * 37) % 100000000);

                $eleve = Eleve::firstOrCreate(
                    ['matricule' => $matricule],
                    [
                        'ecole_id' => $ecole->id,
                        'nom' => $nom,
                        'prenom' => $prenom,
                        'date_naissance' => $dateNaissance,
                        'sexe' => $sexe,
                        'telephone_parent' => $telephoneParent,
                    ]
                );

                Inscription::firstOrCreate(
                    [
                        'eleve_id' => $eleve->id,
                        'annee_academique_id' => $annee->id,
                    ],
                    [
                        'classe_id' => $classe->id,
                        'statut' => 'inscrit',
                    ]
                );
            }
        }
    }
}
