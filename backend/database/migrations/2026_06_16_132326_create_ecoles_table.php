<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ecoles', function (Blueprint $table) {
            $table->id();
            $table->string('nom');
            $table->string('code_ecole', 6)->unique();
            $table->string('chemin_logo')->nullable();
            $table->string('couleur_primaire', 7)->default('#1565C0');
            $table->string('couleur_secondaire', 7)->default('#E3F2FD');
            $table->string('telephone', 20)->nullable();
            $table->string('adresse', 191)->nullable();
            $table->enum('statut_abonnement', ['essai', 'actif', 'expire'])->default('essai');
            $table->timestamp('expire_le')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ecoles');
    }
};