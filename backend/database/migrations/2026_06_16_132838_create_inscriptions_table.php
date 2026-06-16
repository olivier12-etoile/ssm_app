<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('annee_academique_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('statut', ['inscrit', 'admis', 'redoublant', 'diplome', 'abandonne'])->default('inscrit');
            $table->timestamps();

            $table->unique(['eleve_id', 'annee_academique_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inscriptions');
    }
};