<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parametres_frais', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            $table->string('devise', 10)->default('FCFA');
            $table->unsignedTinyInteger('nombre_tranches_defaut')->default(3);
            $table->boolean('penalites_actives')->default(false);
            $table->decimal('montant_penalite_retard', 10, 2)->nullable();
            $table->boolean('paiement_partiel_autorise')->default(true);
            // Nombre de jours de retard tolérés avant qu'un solde restant
            // dû ne bascule l'élève en "non en règle" (0 = immédiat).
            $table->unsignedSmallInteger('seuil_jours_retard_non_en_regle')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_frais');
    }
};
