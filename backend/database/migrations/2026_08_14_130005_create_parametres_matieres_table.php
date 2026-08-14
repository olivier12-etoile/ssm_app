<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parametres_matieres', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            $table->enum('systeme_coefficients', ['fixe', 'variable'])->default('fixe');
            $table->boolean('matieres_facultatives_autorisees')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_matieres');
    }
};
