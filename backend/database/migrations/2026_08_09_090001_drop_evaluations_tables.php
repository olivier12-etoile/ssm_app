<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Supprime l'ancien système d'évaluations parallèle (evaluations +
     * notes_evaluations), devenu redondant : le nouveau modèle "notes"
     * porte directement type_evaluation (devoir|composition), ce qui
     * couvre le même besoin dans un schéma unique et cohérent.
     */
    public function up(): void
    {
        Schema::dropIfExists('notes_evaluations');
        Schema::dropIfExists('evaluations');
    }

    public function down(): void
    {
        Schema::create('evaluations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->foreignId('enseignant_id')->constrained('users')->onDelete('cascade');
            $table->enum('type', ['devoir', 'composition']);
            $table->integer('numero')->default(1);
            $table->string('libelle');
            $table->date('date_evaluation');
            $table->timestamps();
        });

        Schema::create('notes_evaluations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('evaluation_id')->constrained('evaluations')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->decimal('valeur', 5, 2);
            $table->timestamps();

            $table->unique(['evaluation_id', 'eleve_id'], 'note_eval_unique');
        });
    }
};
