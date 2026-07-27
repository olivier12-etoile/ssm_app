<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','ouvert','en_veille','ferme','archive') NOT NULL DEFAULT 'planifie'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::table('periodes_academiques')->where('statut', 'en_veille')->update(['statut' => 'ouvert']);

        DB::statement("ALTER TABLE periodes_academiques MODIFY COLUMN statut ENUM('planifie','ouvert','ferme','archive') NOT NULL DEFAULT 'planifie'");
    }
};