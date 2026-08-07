<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Remplace complètement l'ancienne table frais_scolaires (montant_total +
     * 3 tranches fixes par classe/année/type) par le nouveau modèle du
     * module Frais Scolaires : un frais nommé, éventuellement rattaché à
     * une classe/série précise, avec des échéances libres (table
     * echeances_frais) plutôt que 3 tranches figées.
     */
    public function up(): void
    {
        Schema::dropIfExists('frais_scolaires');

        Schema::create('frais_scolaires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('nom');
            $table->text('description')->nullable();
            $table->decimal('montant', 10, 2);
            $table->foreignId('classe_id')->nullable()->constrained('classes')->nullOnDelete();
            $table->string('serie')->nullable();
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->date('date_limite');
            $table->boolean('obligatoire')->default(true);
            $table->boolean('actif')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('frais_scolaires');

        Schema::create('frais_scolaires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('annee_academique_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('type', ['inscription', 'scolarite']);
            $table->decimal('montant_total', 10, 2);
            $table->decimal('montant_tranche_1', 10, 2)->nullable();
            $table->decimal('montant_tranche_2', 10, 2)->nullable();
            $table->decimal('montant_tranche_3', 10, 2)->nullable();
            $table->timestamps();

            $table->unique(['classe_id', 'annee_academique_id', 'type'], 'frais_classe_annee_type_unique');
        });
    }
};
