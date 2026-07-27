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
        Schema::create('historique_annees', function (Blueprint $table) {
            $table->id();
            $table->foreignId('annee_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('action', ['creation', 'activation', 'cloture', 'archivage', 'passage_eleves']);
            $table->foreignId('fait_par')->constrained('users')->onDelete('cascade');
            $table->text('details')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('historique_annees');
    }
};
