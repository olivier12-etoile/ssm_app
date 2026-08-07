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
        Schema::create('parents_eleves', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->string('nom');
            $table->string('prenom')->nullable();
            $table->enum('lien_parente', ['pere', 'mere', 'tuteur', 'autre']);
            $table->string('telephone_principal')->nullable();
            $table->string('telephone_secondaire')->nullable();
            $table->string('adresse')->nullable();
            $table->string('profession')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('parents_eleves');
    }
};
