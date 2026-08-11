<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Remplace l'ancienne table notes (sans ecole_id, sans classe_id/
     * annee_scolaire_id, sans coefficient) par le nouveau modèle du module
     * Notes & Évaluations : chaque note est rattachée à son contexte complet
     * (école, classe, année scolaire), porte le coefficient au moment de la
     * saisie, et suit un workflow de validation directeur (brouillon →
     * en_attente_validation → validee|rejetee).
     */
    public function up(): void
    {
        Schema::dropIfExists('notes');

        Schema::create('notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->decimal('valeur', 4, 2);
            $table->enum('type_evaluation', ['devoir', 'composition']);
            $table->decimal('coefficient', 4, 2);
            $table->foreignId('saisi_par')->constrained('users');
            $table->enum('statut', ['brouillon', 'en_attente_validation', 'validee', 'rejetee'])->default('brouillon');
            $table->foreignId('valide_par')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('date_validation')->nullable();
            $table->text('motif_rejet')->nullable();
            $table->timestamps();

            $table->unique(
                ['eleve_id', 'matiere_id', 'periode_id', 'type_evaluation'],
                'notes_eleve_matiere_periode_type_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notes');

        Schema::create('notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->foreignId('enseignant_id')->constrained('users')->onDelete('cascade');
            $table->decimal('valeur', 5, 2);
            $table->enum('statut', ['brouillon', 'soumis', 'valide', 'rejete'])->default('brouillon');
            $table->text('motif_rejet')->nullable();
            $table->timestamps();

            $table->unique(['eleve_id', 'matiere_id', 'periode_id']);
        });
    }
};
