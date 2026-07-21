<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('prenom')->nullable();
            $table->enum('sexe', ['M', 'F'])->nullable();
            $table->string('telephone', 20)->nullable();
            $table->text('adresse')->nullable();
            $table->string('fonction')->nullable();
            $table->string('photo_path')->nullable();
            $table->boolean('actif')->default(true);
            $table->timestamp('derniere_connexion')->nullable();
            $table->timestamp('derniere_activite')->nullable();
            $table->string('mot_de_passe_temporaire')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'prenom',
                'sexe',
                'telephone',
                'adresse',
                'fonction',
                'photo_path',
                'actif',
                'derniere_connexion',
                'derniere_activite',
                'mot_de_passe_temporaire',
            ]);
        });
    }
};
