<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Un bulletin est un instantané figé au moment de sa génération : les FK
     * vers eleves/classes/annees_academiques/periodes_academiques ne sont
     * volontairement PAS en cascade (comportement RESTRICT par défaut), afin
     * qu'un bulletin déjà généré ne disparaisse jamais si les données source
     * changent ailleurs.
     */
    public function up(): void
    {
        Schema::create('bulletins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves');
            $table->foreignId('classe_id')->constrained('classes');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques');
            $table->foreignId('periode_id')->constrained('periodes_academiques');

            $table->decimal('moyenne_generale', 5, 2);
            $table->integer('rang')->nullable();
            $table->boolean('rang_ex_aequo')->default(false);
            $table->integer('effectif_classe');
            $table->decimal('total_coefficients', 6, 2);
            $table->decimal('total_points', 8, 2);

            $table->integer('absences_justifiees')->default(0);
            $table->integer('absences_non_justifiees')->default(0);
            $table->integer('retards')->default(0);

            $table->enum('decision_conseil', [
                'encouragements',
                'felicitations',
                'tableau_honneur',
                'avertissement_travail',
                'avertissement_conduite',
                'passage',
                'redoublement',
                'exclusion',
            ])->nullable();
            $table->text('appreciation_generale')->nullable();

            $table->enum('statut', ['genere', 'valide', 'verrouille'])->default('genere');
            $table->foreignId('genere_par')->constrained('users');
            $table->foreignId('valide_par')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('date_validation')->nullable();
            $table->foreignId('professeur_principal_id')->nullable()->constrained('users')->nullOnDelete();

            $table->timestamps();

            $table->unique(['eleve_id', 'periode_id'], 'bulletins_eleve_periode_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bulletins');
    }
};
