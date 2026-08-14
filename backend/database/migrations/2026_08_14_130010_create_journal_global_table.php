<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Journal transversal du module Paramètres de l'École : agrège les
     * actions importantes de tous les modules (frais, notes, emploi du
     * temps, etc. ont chacun déjà leur propre journal détaillé). Le
     * branchement automatique depuis ces journaux existants via un système
     * d'événements centralisé est prévu en Phase 4 ; pour l'instant la
     * table est prête à recevoir des écritures manuelles ou ponctuelles.
     */
    public function up(): void
    {
        Schema::create('journal_global', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('module', 50);
            $table->string('action', 100);
            $table->text('description')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['ecole_id', 'module'], 'journal_global_ecole_module_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('journal_global');
    }
};
