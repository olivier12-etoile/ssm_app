<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Une séance = une matière/enseignant affecté à un créneau horaire
     * précis, un jour donné, dans un emploi du temps (classe/période).
     */
    public function up(): void
    {
        Schema::create('seances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('emploi_du_temps_id')->constrained('emplois_du_temps')->onDelete('cascade');
            $table->foreignId('creneau_horaire_id')->constrained('creneaux_horaires')->onDelete('cascade');
            $table->enum('jour', ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi']);
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->foreignId('enseignant_id')->constrained('users');
            $table->string('salle')->nullable();
            $table->string('couleur', 7)->nullable();
            $table->timestamps();

            $table->unique(
                ['emploi_du_temps_id', 'creneau_horaire_id', 'jour'],
                'seances_creneau_jour_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('seances');
    }
};
