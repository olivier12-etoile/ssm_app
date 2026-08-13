<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Grille horaire réutilisable de l'école pour une année scolaire
     * (ex: "Heure 1" 07h00-08h00, "Récréation" 10h00-10h15...). Les
     * séances de tous les emplois du temps de l'année s'appuient sur ces
     * créneaux communs plutôt que de porter chacune leurs propres heures.
     */
    public function up(): void
    {
        Schema::create('creneaux_horaires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('libelle');
            $table->time('heure_debut');
            $table->time('heure_fin');
            $table->integer('ordre');
            $table->enum('type', ['cours', 'recreation', 'pause']);
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('creneaux_horaires');
    }
};
