<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('periodes_academiques', function (Blueprint $table) {
            $table->id();
            $table->foreignId('annee_academique_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->string('nom', 50); // ex: 1er Trimestre
            $table->date('date_debut');
            $table->date('date_fin');
            $table->enum('statut', ['planifie', 'actif', 'cloture'])->default('planifie');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('periodes_academiques');
    }
};