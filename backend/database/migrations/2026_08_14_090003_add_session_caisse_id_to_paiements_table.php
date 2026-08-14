<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Renseigné uniquement pour un paiement en espèces enregistré pendant
     * qu'une session de caisse est ouverte — voir CaisseService et
     * PaiementController::store().
     */
    public function up(): void
    {
        Schema::table('paiements', function (Blueprint $table) {
            $table->foreignId('session_caisse_id')
                ->nullable()
                ->after('mode_paiement')
                ->constrained('sessions_caisse')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('paiements', function (Blueprint $table) {
            $table->dropConstrainedForeignId('session_caisse_id');
        });
    }
};
