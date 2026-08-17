<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Détail par élève d'un appel : une ligne "presente" est créée pour
     * chaque élève de la classe dès la création de l'appel
     * (PresenceService::creerAppel) — l'enseignant ne fait ensuite que
     * signaler les absents/retards, jamais l'inverse.
     */
    public function up(): void
    {
        Schema::create('presences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('appel_presence_id')->constrained('appels_presence')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->enum('statut', ['present', 'absent', 'retard'])->default('present');
            $table->boolean('justifie')->default(false);
            $table->string('motif_justification')->nullable();
            $table->integer('minutes_retard')->nullable();
            $table->boolean('notifie_parent')->default(false);
            $table->timestamps();

            $table->unique(['appel_presence_id', 'eleve_id'], 'presences_appel_eleve_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('presences');
    }
};
