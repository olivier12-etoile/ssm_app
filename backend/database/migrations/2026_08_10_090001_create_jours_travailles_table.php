<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Configuration des jours de la semaine effectivement travaillés par
     * l'école pour une année scolaire donnée (ex: samedi désactivé).
     */
    public function up(): void
    {
        Schema::create('jours_travailles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->enum('jour', ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi']);
            $table->boolean('actif')->default(true);
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->timestamps();

            $table->unique(['annee_scolaire_id', 'jour'], 'jours_travailles_annee_jour_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('jours_travailles');
    }
};
