<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Suit l'avancement de la saisie des notes par enseignant, pour une
     * classe/matière/période données (une ligne = une session de saisie).
     */
    public function up(): void
    {
        Schema::create('saisies_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('enseignant_id')->constrained('users');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('statut', ['en_cours', 'terminee', 'en_attente_validation', 'validee', 'rejetee'])
                ->default('en_cours');
            $table->date('date_debut');
            $table->date('date_fin_saisie')->nullable();
            $table->timestamp('date_soumission')->nullable();
            $table->timestamps();

            $table->unique(
                ['enseignant_id', 'classe_id', 'matiere_id', 'periode_id'],
                'saisies_notes_progression_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('saisies_notes');
    }
};
