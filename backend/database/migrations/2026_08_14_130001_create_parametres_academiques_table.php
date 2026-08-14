<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Réglages pédagogiques globaux de l'école (une ligne par école).
     * Le découpage trimestres/semestres reste géré par
     * annees_academiques.type_periodes (module Années & Périodes) : il
     * n'est pas dupliqué ici.
     */
    public function up(): void
    {
        Schema::create('parametres_academiques', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            $table->unsignedTinyInteger('bareme_note_max')->default(20);
            $table->boolean('coefficients_par_matiere')->default(true);
            $table->boolean('coefficients_par_classe')->default(false);
            $table->boolean('coefficients_par_niveau')->default(false);
            $table->enum('mode_calcul_moyenne_matiere', ['simple', 'ponderee'])->default('simple');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_academiques');
    }
};
