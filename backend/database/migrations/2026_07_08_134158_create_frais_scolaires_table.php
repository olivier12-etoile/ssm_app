<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('frais_scolaires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('annee_academique_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('type', ['inscription', 'scolarite']);
            $table->decimal('montant_total', 10, 2); // montant total dû pour l'année
            $table->decimal('montant_tranche_1', 10, 2)->nullable();
            $table->decimal('montant_tranche_2', 10, 2)->nullable();
            $table->decimal('montant_tranche_3', 10, 2)->nullable();
            $table->timestamps();

            $table->unique(
                ['classe_id', 'annee_academique_id', 'type'],
                'frais_classe_annee_type_unique'
            );
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('frais_scolaires');
    }
};
