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
        Schema::create('documents_eleves', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->string('nom');
            $table->enum('type', [
                'acte_naissance',
                'certificat_scolarite',
                'photo',
                'bulletin',
                'certificat_transfert',
                'autre',
            ]);
            $table->string('chemin_fichier');
            $table->integer('taille')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('documents_eleves');
    }
};
