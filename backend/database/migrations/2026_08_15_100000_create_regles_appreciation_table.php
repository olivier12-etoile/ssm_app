<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Barème d'appréciation configurable par école, utilisé pour associer
     * automatiquement un libellé (ex: "Excellent") à une note de bulletin.
     */
    public function up(): void
    {
        Schema::create('regles_appreciation', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->decimal('note_min', 4, 2);
            $table->decimal('note_max', 4, 2);
            $table->string('libelle_appreciation', 50);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('regles_appreciation');
    }
};
