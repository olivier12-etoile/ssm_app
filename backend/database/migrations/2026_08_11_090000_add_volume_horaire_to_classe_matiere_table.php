<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Le module Emploi du Temps doit comparer le volume horaire programmé
     * (calculé depuis les séances) au volume horaire attendu — mais
     * classe_matiere ne portait jusqu'ici que le coefficient. Ajout du
     * volume horaire hebdomadaire attendu, nécessaire à
     * ConflitEmploiDuTempsService::volumeHoraireMatiere() et à l'accessor
     * EmploiDuTemps::volumeHoraireParMatiere.
     */
    public function up(): void
    {
        Schema::table('classe_matiere', function (Blueprint $table) {
            $table->decimal('volume_horaire_hebdomadaire', 4, 2)->nullable()->after('coefficient');
        });
    }

    public function down(): void
    {
        Schema::table('classe_matiere', function (Blueprint $table) {
            $table->dropColumn('volume_horaire_hebdomadaire');
        });
    }
};
