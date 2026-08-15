<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Détail par matière d'un bulletin, snapshot au moment de la génération :
     * nom_matiere et coefficient sont dupliqués ici pour que le bulletin
     * reste lisible même si la matière est renommée/recoefficientée plus
     * tard. matiere_id passe donc à NULL (au lieu d'être supprimé en
     * cascade) si la matière source est supprimée.
     */
    public function up(): void
    {
        Schema::create('bulletin_details', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bulletin_id')->constrained('bulletins')->onDelete('cascade');
            $table->foreignId('matiere_id')->nullable()->constrained('matieres')->nullOnDelete();

            $table->string('nom_matiere', 100);
            $table->decimal('coefficient', 4, 2);
            $table->decimal('note', 4, 2);
            $table->decimal('moyenne_matiere_classe', 4, 2)->nullable();
            $table->text('appreciation_matiere')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bulletin_details');
    }
};
