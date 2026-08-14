<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('modeles_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('nom');
            $table->enum('categorie', [
                'scolarite',
                'finances',
                'presence',
                'administration',
                'discipline',
                'vie_scolaire',
            ]);
            $table->text('contenu');
            $table->json('variables_disponibles')->nullable();
            $table->boolean('actif')->default(true);
            $table->boolean('modifiable')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('modeles_messages');
    }
};
