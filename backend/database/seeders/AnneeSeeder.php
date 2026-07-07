<?php

namespace Database\Seeders;

use App\Models\AnneeAcademique;
use App\Models\Ecole;
use App\Models\PeriodeAcademique;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class AnneeSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        $annee = AnneeAcademique::firstOrCreate(
            [
                'ecole_id' => $ecole->id,
                'libelle' => '2024-2025',
            ],
            [
                'date_debut' => '2024-09-01',
                'date_fin' => '2025-07-31',
                'statut' => 'en_cours',
            ]
        );

        $periodes = [
            ['nom' => '1er Trimestre', 'date_debut' => '2024-09-01', 'date_fin' => '2024-12-20', 'statut' => 'cloture'],
            ['nom' => '2ème Trimestre', 'date_debut' => '2025-01-06', 'date_fin' => '2025-03-28', 'statut' => 'actif'],
            ['nom' => '3ème Trimestre', 'date_debut' => '2025-04-07', 'date_fin' => '2025-07-11', 'statut' => 'planifie'],
        ];

        foreach ($periodes as $periode) {
            PeriodeAcademique::firstOrCreate(
                [
                    'annee_academique_id' => $annee->id,
                    'nom' => $periode['nom'],
                ],
                [
                    'date_debut' => $periode['date_debut'],
                    'date_fin' => $periode['date_fin'],
                    'statut' => $periode['statut'],
                ]
            );
        }
    }
}
