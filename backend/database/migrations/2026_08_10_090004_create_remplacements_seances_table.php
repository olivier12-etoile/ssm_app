<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Remplacement ponctuel d'un enseignant sur une séance, pour une date
     * précise (l'emploi du temps type de la séance n'est pas modifié).
     * Rattaché à seances, qui porte déjà ecole_id — pas de colonne
     * ecole_id directe ici (même principe que historique_validations_notes).
     */
    public function up(): void
    {
        Schema::create('remplacements_seances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seance_id')->constrained('seances')->onDelete('cascade');
            $table->date('date_remplacement');
            $table->foreignId('enseignant_remplacant_id')->constrained('users');
            $table->text('motif')->nullable();
            $table->foreignId('enregistre_par')->constrained('users');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('remplacements_seances');
    }
};
