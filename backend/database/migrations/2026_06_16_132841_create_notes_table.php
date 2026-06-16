<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->foreignId('enseignant_id')->constrained('users')->onDelete('cascade');
            $table->decimal('valeur', 5, 2); // ex: 14.50
            $table->enum('statut', ['brouillon', 'soumis', 'valide', 'rejete'])->default('brouillon');
            $table->text('motif_rejet')->nullable();
            $table->timestamps();

            $table->unique(['eleve_id', 'matiere_id', 'periode_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notes');
    }
};