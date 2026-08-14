<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Réglages par défaut appliqués à la création d'une classe. Ne remplace
     * pas classes.capacite_max, qui reste l'effectif réel (modifiable) de
     * chaque classe une fois créée.
     */
    public function up(): void
    {
        Schema::create('parametres_classes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            $table->unsignedSmallInteger('effectif_max_par_classe')->default(50);
            $table->string('format_code_classe', 50)->default('{niveau}{lettre}');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_classes');
    }
};
