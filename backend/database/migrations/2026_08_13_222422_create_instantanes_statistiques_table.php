<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Historise un instantané des chiffres clés (effectifs, financier ou
     * pédagogique) pour une année scolaire donnée, afin de pouvoir comparer
     * deux années entre elles même après que l'année active a changé.
     */
    public function up(): void
    {
        Schema::create('instantanes_statistiques', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('annee_scolaire_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->enum('type', ['effectifs', 'financier', 'pedagogique']);
            $table->json('donnees');
            $table->timestamp('date_snapshot');
            $table->timestamps();

            $table->index(['ecole_id', 'annee_scolaire_id', 'type'], 'instantanes_stats_ecole_annee_type_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('instantanes_statistiques');
    }
};
