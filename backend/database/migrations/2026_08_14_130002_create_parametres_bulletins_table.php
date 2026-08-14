<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parametres_bulletins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            $table->boolean('afficher_logo')->default(true);
            $table->boolean('afficher_matricule')->default(true);
            $table->boolean('afficher_effectif')->default(true);
            $table->boolean('afficher_coefficients')->default(true);
            $table->boolean('afficher_rang')->default(true);
            $table->boolean('afficher_appreciations')->default(true);
            $table->boolean('afficher_absences')->default(true);
            $table->boolean('afficher_retards')->default(true);
            $table->boolean('afficher_decision_conseil')->default(false);
            $table->boolean('afficher_signature_directeur')->default(true);
            $table->boolean('afficher_cachet')->default(true);
            $table->enum('modele_bulletin', ['standard', 'compact', 'detaille'])->default('standard');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_bulletins');
    }
};
