<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Journal d'audit des actions sur un emploi du temps (création,
     * modification, validation, duplication). Rattaché à emplois_du_temps,
     * qui porte déjà ecole_id — pas de colonne ecole_id directe ici (même
     * principe que historique_validations_notes).
     */
    public function up(): void
    {
        Schema::create('historique_emploi_du_temps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('emploi_du_temps_id')->constrained('emplois_du_temps')->onDelete('cascade');
            $table->enum('action', ['creation', 'modification', 'validation', 'duplication']);
            $table->foreignId('effectue_par')->constrained('users');
            $table->text('details')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('historique_emploi_du_temps');
    }
};
