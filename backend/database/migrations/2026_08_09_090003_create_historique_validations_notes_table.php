<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Journal d'audit des actions de workflow sur une saisie de notes
     * (soumission, validation, rejet, déverrouillage). Rattaché à
     * saisies_notes, qui porte déjà ecole_id — pas de colonne ecole_id
     * directe ici (même principe que journal_operations_frais).
     */
    public function up(): void
    {
        Schema::create('historique_validations_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('saisie_note_id')->constrained('saisies_notes')->onDelete('cascade');
            $table->enum('action', ['soumission', 'validation', 'rejet', 'deverrouillage']);
            $table->foreignId('effectue_par')->constrained('users');
            $table->text('motif')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('historique_validations_notes');
    }
};
