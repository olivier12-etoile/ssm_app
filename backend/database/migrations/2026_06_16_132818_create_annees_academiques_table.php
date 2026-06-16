<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('annees_academiques', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('libelle', 20); // ex: 2024-2025
            $table->date('date_debut');
            $table->date('date_fin');
            $table->enum('statut', ['en_cours', 'terminee'])->default('en_cours');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('annees_academiques');
    }
};