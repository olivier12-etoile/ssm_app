<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * État de verrouillage d'une saisie de notes (empêche toute
     * modification par l'enseignant une fois la période close, jusqu'à
     * déverrouillage explicite par le directeur).
     */
    public function up(): void
    {
        Schema::create('verrouillages_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('saisie_note_id')->constrained('saisies_notes')->onDelete('cascade');
            $table->boolean('verrouille')->default(true);
            $table->foreignId('deverrouille_par')->nullable()->constrained('users')->nullOnDelete();
            $table->text('motif_deverrouillage')->nullable();
            $table->timestamp('date_deverrouillage')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('verrouillages_notes');
    }
};
