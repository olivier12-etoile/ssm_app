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
        Schema::table('periodes_academiques', function (Blueprint $table) {
            $table->string('couleur', 10)->nullable()->after('code');
            $table->unsignedTinyInteger('ordre')->default(1)->after('couleur');
        });

        // Élargit temporairement l'enum pour couvrir anciennes ET nouvelles
        // valeurs, le temps de remapper les lignes existantes.
        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','ouvert','en_veille','ferme','archive','preparation','ouverte','en_validation','cloturee','archivee') NOT NULL DEFAULT 'planifie'");

        DB::table('periodes_academiques')->where('statut', 'planifie')->update(['statut' => 'preparation']);
        DB::table('periodes_academiques')->where('statut', 'ouvert')->update(['statut' => 'ouverte']);
        DB::table('periodes_academiques')->where('statut', 'ferme')->update(['statut' => 'cloturee']);
        DB::table('periodes_academiques')->where('statut', 'archive')->update(['statut' => 'archivee']);

        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('preparation','ouverte','en_veille','en_validation','cloturee','archivee') NOT NULL DEFAULT 'preparation'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('preparation','ouverte','en_veille','en_validation','cloturee','archivee','planifie','ouvert','ferme','archive') NOT NULL DEFAULT 'preparation'");

        DB::table('periodes_academiques')->where('statut', 'preparation')->update(['statut' => 'planifie']);
        DB::table('periodes_academiques')->where('statut', 'ouverte')->update(['statut' => 'ouvert']);
        DB::table('periodes_academiques')->where('statut', 'en_validation')->update(['statut' => 'ouvert']);
        DB::table('periodes_academiques')->where('statut', 'cloturee')->update(['statut' => 'ferme']);
        DB::table('periodes_academiques')->where('statut', 'archivee')->update(['statut' => 'archive']);

        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','ouvert','en_veille','ferme','archive') NOT NULL DEFAULT 'planifie'");

        Schema::table('periodes_academiques', function (Blueprint $table) {
            $table->dropColumn(['couleur', 'ordre']);
        });
    }
};
