<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Événements du calendrier scolaire (vacances, jours fériés, examens,
     * compositions, conseils de classe) pour une année scolaire.
     */
    public function up(): void
    {
        Schema::create('evenements_calendrier', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('type', ['vacances', 'ferie', 'examen', 'composition', 'conseil_classe']);
            $table->string('libelle');
            $table->date('date_debut');
            $table->date('date_fin');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('evenements_calendrier');
    }
};
