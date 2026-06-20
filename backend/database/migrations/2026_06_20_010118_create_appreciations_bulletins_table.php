<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('appreciations_bulletins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->text('appreciation_enseignant')->nullable();
            $table->text('appreciation_directeur')->nullable();
            $table->string('observation', 100)->nullable(); // Félicitations, Encouragements, etc.
            $table->timestamps();

            $table->unique(['eleve_id', 'periode_id'], 'appreciation_eleve_periode_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('appreciations_bulletins');
    }
};