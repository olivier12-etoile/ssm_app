<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('chronologie_eleves', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->enum('type', [
                'inscription',
                'paiement',
                'note_validee',
                'bulletin_genere',
                'absence',
                'sanction',
                'transfert',
                'passage',
                'document_ajoute',
                'message_envoye',
                'autre',
            ]);
            $table->string('titre');
            $table->text('description')->nullable();
            $table->string('icone')->nullable();
            $table->string('couleur')->nullable();
            $table->integer('reference_id')->nullable();
            $table->string('reference_type')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('chronologie_eleves');
    }
};
