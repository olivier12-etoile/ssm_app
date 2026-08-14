<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Statut affiché côté app pour rassurer le directeur ; la sauvegarde
     * réelle de la base est gérée par l'infra (Railway), pas par ce module.
     */
    public function up(): void
    {
        Schema::create('sauvegardes_info', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->timestamp('date_derniere_sauvegarde')->nullable();
            $table->enum('statut', ['reussie', 'echouee', 'en_cours'])->default('en_cours');
            $table->unsignedBigInteger('taille_fichier')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sauvegardes_info');
    }
};
