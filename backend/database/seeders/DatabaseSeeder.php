<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            EcoleSeeder::class,
            ClasseSeeder::class,
            MatiereSeeder::class,
            UtilisateurSeeder::class,
            AnneeSeeder::class,
            EleveSeeder::class,
            AffectationSeeder::class,
        ]);
    }
}
