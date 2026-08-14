<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Complète la fiche école existante (nom, code_ecole, chemin_logo,
     * couleur_primaire/secondaire, telephone, adresse) avec les champs
     * d'identité, de marque blanche étendue et de direction utilisés par
     * le module Paramètres de l'École. Les colonnes déjà présentes ne sont
     * pas renommées : elles sont utilisées partout dans l'app (bulletins,
     * reçus, dashboard) et restent la source de vérité pour le nom et le
     * logo/couleurs principaux.
     */
    public function up(): void
    {
        Schema::table('ecoles', function (Blueprint $table) {
            // Identité
            $table->string('nom_court')->nullable()->after('nom');
            $table->string('sigle', 20)->nullable()->after('nom_court');
            $table->enum('type_etablissement', ['primaire', 'college', 'lycee', 'complexe'])
                  ->default('complexe')->after('sigle');
            $table->string('ville')->nullable()->after('adresse');
            $table->string('region')->nullable()->after('ville');
            $table->string('pays')->default('Togo')->after('region');
            $table->string('email')->nullable()->after('telephone');
            $table->string('site_web')->nullable()->after('email');
            $table->string('devise', 10)->default('FCFA')->after('site_web');
            $table->unsignedSmallInteger('annee_creation')->nullable()->after('devise');

            // Marque blanche étendue
            $table->string('logo_secondaire')->nullable()->after('chemin_logo');
            $table->string('cachet_numerique')->nullable()->after('logo_secondaire');
            $table->string('signature_directeur')->nullable()->after('cachet_numerique');
            $table->string('couleur_boutons', 7)->nullable()->after('couleur_secondaire');
            $table->string('couleur_entetes', 7)->nullable()->after('couleur_boutons');

            // Direction
            $table->string('directeur_nom')->nullable();
            $table->string('directeur_prenom')->nullable();
            $table->string('directeur_fonction')->nullable();
            $table->string('directeur_telephone', 20)->nullable();
            $table->string('directeur_email')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('ecoles', function (Blueprint $table) {
            $table->dropColumn([
                'nom_court',
                'sigle',
                'type_etablissement',
                'ville',
                'region',
                'pays',
                'email',
                'site_web',
                'devise',
                'annee_creation',
                'logo_secondaire',
                'cachet_numerique',
                'signature_directeur',
                'couleur_boutons',
                'couleur_entetes',
                'directeur_nom',
                'directeur_prenom',
                'directeur_fonction',
                'directeur_telephone',
                'directeur_email',
            ]);
        });
    }
};
