<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Historique des connexions (une ligne par connexion), en complément
     * de users.derniere_connexion qui ne garde que la dernière.
     */
    public function up(): void
    {
        Schema::create('connexions_utilisateurs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->timestamp('date_connexion')->useCurrent();
            $table->string('ip', 45)->nullable();
            $table->string('appareil')->nullable();
            $table->timestamps();

            $table->index(['ecole_id', 'user_id'], 'connexions_utilisateurs_ecole_user_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('connexions_utilisateurs');
    }
};
