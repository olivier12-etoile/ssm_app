<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('classes', function (Blueprint $table) {
            $table->string('serie')->nullable();
            $table->string('salle')->nullable();
            $table->enum('statut', ['active', 'inactive'])->default('active');
            $table->foreignId('professeur_principal_id')
                  ->nullable()
                  ->constrained('users')
                  ->onDelete('cascade');
            $table->foreignId('annee_academique_id')
                  ->nullable()
                  ->constrained('annees_academiques');
        });
    }

    public function down(): void
    {
        Schema::table('classes', function (Blueprint $table) {
            $table->dropForeign(['professeur_principal_id']);
            $table->dropForeign(['annee_academique_id']);
            $table->dropColumn([
                'serie',
                'salle',
                'statut',
                'professeur_principal_id',
                'annee_academique_id',
            ]);
        });
    }
};
