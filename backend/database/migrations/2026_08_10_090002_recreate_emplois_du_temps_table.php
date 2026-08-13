<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Remplace l'ancienne table emplois_du_temps (une ligne = une séance,
     * heures libres par ligne, pas de workflow) par le nouveau modèle du
     * module Emploi du Temps : emplois_du_temps devient un conteneur par
     * classe/période avec un statut brouillon/valide, et ses séances
     * (table séparée) s'appuient sur la grille horaire commune
     * (creneaux_horaires) plutôt que de porter leurs propres heures.
     */
    public function up(): void
    {
        Schema::dropIfExists('emplois_du_temps');

        Schema::create('emplois_du_temps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->enum('statut', ['brouillon', 'valide'])->default('brouillon');
            $table->foreignId('cree_par')->constrained('users');
            $table->timestamps();

            $table->unique(['classe_id', 'periode_id'], 'emplois_du_temps_classe_periode_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('emplois_du_temps');

        Schema::create('emplois_du_temps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('annee_academique_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('jour', ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi']);
            $table->time('heure_debut');
            $table->time('heure_fin');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('enseignant_id')->constrained('users')->onDelete('cascade');
            $table->string('salle')->nullable();
            $table->timestamps();

            $table->unique(
                ['classe_id', 'annee_academique_id', 'jour', 'heure_debut'],
                'edt_unique'
            );
        });
    }
};
