<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sessions_caisse', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('caisse_id')->constrained('caisses')->onDelete('cascade');
            $table->foreignId('ouvert_par')->constrained('users');
            $table->decimal('montant_initial', 10, 2);
            $table->dateTime('date_ouverture');
            $table->foreignId('ferme_par')->nullable()->constrained('users')->nullOnDelete();
            $table->dateTime('date_fermeture')->nullable();
            // Calculé à la fermeture : montant_initial + somme des paiements
            // espèces rattachés à cette session (session_caisse_id).
            $table->decimal('montant_theorique', 10, 2)->nullable();
            // Saisi manuellement par l'utilisateur à la fermeture (comptage physique).
            $table->decimal('montant_reel', 10, 2)->nullable();
            // ecart = montant_reel - montant_theorique
            $table->decimal('ecart', 10, 2)->nullable();
            $table->text('observation_fermeture')->nullable();
            $table->enum('statut', ['ouverte', 'fermee'])->default('ouverte');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions_caisse');
    }
};
