<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Config::sanctum 'expiration' est à null (tokens sans expiration) et
     * aucune notion de délai d'inactivité n'existe ailleurs dans le
     * projet : ce paramètre ne rentre ni dans parametres_academiques
     * (pédagogique) ni sur ecoles (identité), d'où une table dédiée, sur
     * le même modèle que les autres parametres_* de ce module. Pour
     * l'instant seul le get/set est implémenté (SecuriteController) :
     * l'enforcement réel (comparer now() à users.derniere_activite et
     * révoquer le token) reste à câbler, probablement via un middleware
     * sur le groupe auth:sanctum.
     */
    public function up(): void
    {
        Schema::create('parametres_securite', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            // null = pas de déconnexion automatique.
            $table->unsignedSmallInteger('delai_inactivite_minutes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_securite');
    }
};
