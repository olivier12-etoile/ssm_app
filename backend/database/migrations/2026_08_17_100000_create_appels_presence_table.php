<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Une "session d'appel" = un cours (ou un appel général si matiere_id/
     * creneau_horaire_id sont nuls) à une date donnée pour une classe.
     * matiere_id et creneau_horaire_id sont nullables : matiere_id pour un
     * appel non lié à un cours précis, creneau_horaire_id tant que le module
     * Emploi du Temps n'identifie pas le créneau concerné.
     *
     * Note MySQL : l'unicité (classe_id, matiere_id, date_appel,
     * creneau_horaire_id) ne bloque pas les doublons quand matiere_id et/ou
     * creneau_horaire_id sont NULL (NULL != NULL dans un index unique) :
     * PresenceService::creerAppel() fait donc lui-même la vérification
     * applicative de doublon avant insertion.
     */
    public function up(): void
    {
        Schema::create('appels_presence', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('matiere_id')->nullable()->constrained('matieres')->nullOnDelete();
            $table->foreignId('enseignant_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->foreignId('periode_id')->constrained('periodes_academiques')->onDelete('cascade');
            $table->date('date_appel');
            $table->foreignId('creneau_horaire_id')->nullable()->constrained('creneaux_horaires')->nullOnDelete();
            $table->enum('statut', ['en_cours', 'termine'])->default('en_cours');
            $table->timestamps();

            $table->unique(
                ['classe_id', 'matiere_id', 'date_appel', 'creneau_horaire_id'],
                'appels_presence_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('appels_presence');
    }
};
