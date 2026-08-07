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
        Schema::table('eleves', function (Blueprint $table) {
            $table->string('lieu_naissance')->nullable()->after('date_naissance');
            $table->string('nationalite')->nullable()->default('Togolaise')->after('lieu_naissance');
            $table->integer('numero_appel')->nullable()->after('matricule');
            $table->enum('statut', ['actif', 'suspendu', 'exclu', 'transfere', 'diplome', 'abandon'])
                  ->default('actif')
                  ->after('numero_appel');
            $table->date('date_inscription')->nullable()->after('statut');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('eleves', function (Blueprint $table) {
            $table->dropColumn(['lieu_naissance', 'nationalite', 'numero_appel', 'statut', 'date_inscription']);
        });
    }
};
