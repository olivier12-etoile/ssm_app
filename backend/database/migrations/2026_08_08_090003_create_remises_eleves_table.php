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
        Schema::create('remises_eleves', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('frais_scolaire_id')->constrained('frais_scolaires')->onDelete('cascade');
            $table->enum('type', ['bourse', 'reduction_familiale', 'reduction_exceptionnelle', 'remise_administrative']);
            $table->decimal('montant', 10, 2)->nullable();
            $table->decimal('pourcentage', 5, 2)->nullable();
            $table->text('motif');
            $table->foreignId('autorise_par')->constrained('users');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('remises_eleves');
    }
};
