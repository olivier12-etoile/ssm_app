<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('enseignant_classe_matiere', function (Blueprint $table) {
            $table->id();
            $table->foreignId('enseignant_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->foreignId('matiere_id')->constrained('matieres')->onDelete('cascade');
            $table->timestamps();

            // ✅ Nom court pour éviter la limite MySQL
            $table->unique(['enseignant_id', 'classe_id', 'matiere_id'], 'ecm_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('enseignant_classe_matiere');
    }
};