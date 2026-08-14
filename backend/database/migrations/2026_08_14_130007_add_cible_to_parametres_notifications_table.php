<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Le module Paramètres de l'École demandait une table
     * "parametres_notifications_ecole" (cible parents/enseignants,
     * type_evenement, actif) pour activer/désactiver les types de
     * notification. C'est exactement ce que fait déjà
     * parametres_notifications (module Notifications) avec ses colonnes
     * ecole_id + cle + valeur : on évite le doublon en y ajoutant juste la
     * dimension "cible", pour permettre de futurs déclencheurs orientés
     * enseignants (aujourd'hui tous les déclencheurs de
     * ParametreNotification::DECLENCHEURS ciblent les parents).
     *
     * On en profite pour corriger l'unicité : la table d'origine impose
     * unique(ecole_id, cle) sans la dimension cible, ce qui interdirait à
     * un type_evenement "enseignants" de porter la même clé technique
     * qu'un déclencheur "parents" (ex. notes_validees existe des deux
     * côtés avec un sens différent). L'unicité doit porter sur
     * (ecole_id, cible, cle).
     */
    public function up(): void
    {
        Schema::table('parametres_notifications', function (Blueprint $table) {
            $table->enum('cible', ['parents', 'enseignants'])->default('parents')->after('ecole_id');
        });

        // L'ancien index unique(ecole_id, cle) sert aussi d'index de support
        // à la clé étrangère ecole_id : il faut créer le nouvel index avant
        // de supprimer l'ancien (sinon MySQL refuse le drop, la colonne
        // ecole_id se retrouvant sans aucun index le temps de la transition).
        Schema::table('parametres_notifications', function (Blueprint $table) {
            $table->unique(['ecole_id', 'cible', 'cle'], 'parametres_notifications_ecole_cible_cle_unique');
        });

        Schema::table('parametres_notifications', function (Blueprint $table) {
            $table->dropUnique('parametres_notifications_ecole_cle_unique');
        });
    }

    public function down(): void
    {
        Schema::table('parametres_notifications', function (Blueprint $table) {
            $table->unique(['ecole_id', 'cle'], 'parametres_notifications_ecole_cle_unique');
        });

        Schema::table('parametres_notifications', function (Blueprint $table) {
            $table->dropUnique('parametres_notifications_ecole_cible_cle_unique');
        });

        Schema::table('parametres_notifications', function (Blueprint $table) {
            $table->dropColumn('cible');
        });
    }
};
