<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // ── annees_academiques ──────────────────────────────────
        Schema::table('annees_academiques', function (Blueprint $table) {
            $table->foreignId('cree_par')
                  ->nullable()
                  ->constrained('users')
                  ->nullOnDelete();
            $table->foreignId('active_par')
                  ->nullable()
                  ->constrained('users')
                  ->nullOnDelete();
            $table->timestamp('active_le')->nullable();
            $table->foreignId('cloture_par')
                  ->nullable()
                  ->constrained('users')
                  ->nullOnDelete();
            $table->timestamp('cloture_le')->nullable();
            $table->decimal('regle_passage_moyenne', 4, 2)->default(10.00);
        });

        // Élargit temporairement l'enum pour couvrir anciennes ET nouvelles
        // valeurs, le temps de remapper les lignes existantes.
        DB::statement("ALTER TABLE annees_academiques MODIFY COLUMN statut ENUM('en_cours','terminee','en_preparation','active','cloturee','archivee') NOT NULL DEFAULT 'en_cours'");

        DB::table('annees_academiques')->where('statut', 'en_cours')->update(['statut' => 'active']);
        DB::table('annees_academiques')->where('statut', 'terminee')->update(['statut' => 'cloturee']);

        DB::statement("ALTER TABLE annees_academiques MODIFY COLUMN statut ENUM('en_preparation','active','cloturee','archivee') NOT NULL DEFAULT 'en_preparation'");

        // ── periodes_academiques ─────────────────────────────────
        Schema::table('periodes_academiques', function (Blueprint $table) {
            $table->string('code', 10)->nullable();
            $table->foreignId('ouverte_par')
                  ->nullable()
                  ->constrained('users')
                  ->nullOnDelete();
            $table->timestamp('ouverte_le')->nullable();
            $table->foreignId('fermee_par')
                  ->nullable()
                  ->constrained('users')
                  ->nullOnDelete();
            $table->timestamp('fermee_le')->nullable();
            $table->boolean('alerte_envoyee')->default(false);
        });

        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','actif','cloture','ouvert','ferme','archive') NOT NULL DEFAULT 'planifie'");

        DB::table('periodes_academiques')->where('statut', 'actif')->update(['statut' => 'ouvert']);
        DB::table('periodes_academiques')->where('statut', 'cloture')->update(['statut' => 'ferme']);

        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','ouvert','ferme','archive') NOT NULL DEFAULT 'planifie'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // ── periodes_academiques ─────────────────────────────────
        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','ouvert','ferme','archive','actif','cloture') NOT NULL DEFAULT 'planifie'");

        DB::table('periodes_academiques')->where('statut', 'ouvert')->update(['statut' => 'actif']);
        DB::table('periodes_academiques')->where('statut', 'ferme')->update(['statut' => 'cloture']);
        DB::table('periodes_academiques')->where('statut', 'archive')->update(['statut' => 'planifie']);

        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','actif','cloture') NOT NULL DEFAULT 'planifie'");

        Schema::table('periodes_academiques', function (Blueprint $table) {
            $table->dropConstrainedForeignId('ouverte_par');
            $table->dropConstrainedForeignId('fermee_par');
            $table->dropColumn(['code', 'ouverte_le', 'fermee_le', 'alerte_envoyee']);
        });

        // ── annees_academiques ──────────────────────────────────
        DB::statement("ALTER TABLE annees_academiques MODIFY COLUMN statut ENUM('en_preparation','active','cloturee','archivee','en_cours','terminee') NOT NULL DEFAULT 'en_preparation'");

        DB::table('annees_academiques')->where('statut', 'active')->update(['statut' => 'en_cours']);
        DB::table('annees_academiques')->where('statut', 'cloturee')->update(['statut' => 'terminee']);
        DB::table('annees_academiques')->where('statut', 'archivee')->update(['statut' => 'terminee']);
        DB::table('annees_academiques')->where('statut', 'en_preparation')->update(['statut' => 'en_cours']);

        DB::statement("ALTER TABLE annees_academiques MODIFY COLUMN statut ENUM('en_cours','terminee') NOT NULL DEFAULT 'en_cours'");

        Schema::table('annees_academiques', function (Blueprint $table) {
            $table->dropConstrainedForeignId('cree_par');
            $table->dropConstrainedForeignId('active_par');
            $table->dropConstrainedForeignId('cloture_par');
            $table->dropColumn(['active_le', 'cloture_le', 'regle_passage_moyenne']);
        });
    }
};