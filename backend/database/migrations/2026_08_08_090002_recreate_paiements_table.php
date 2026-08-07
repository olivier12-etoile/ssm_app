<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Remplace l'ancienne table paiements (liée directement à
     * annee_academique_id, tranche libre en texte) par le nouveau modèle du
     * module Frais Scolaires : chaque paiement est rattaché à un frais
     * scolaire précis (et éventuellement une échéance), avec numéro de
     * reçu auto-généré et gestion de l'annulation.
     */
    public function up(): void
    {
        Schema::dropIfExists('paiements');

        Schema::create('paiements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('frais_scolaire_id')->constrained('frais_scolaires')->onDelete('cascade');
            $table->foreignId('echeance_id')->nullable()->constrained('echeances_frais')->nullOnDelete();
            $table->decimal('montant', 10, 2);
            $table->enum('mode_paiement', ['especes', 'moov_money', 'wave', 'virement', 'cheque']);
            $table->string('reference')->nullable();
            $table->date('date_paiement');
            $table->text('observation')->nullable();
            $table->string('numero_recu')->unique();
            $table->enum('statut', ['valide', 'annule'])->default('valide');
            $table->foreignId('annule_par')->nullable()->constrained('users')->nullOnDelete();
            $table->text('motif_annulation')->nullable();
            $table->foreignId('created_by')->constrained('users');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('paiements');

        Schema::create('paiements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('annee_academique_id')->constrained('annees_academiques')->onDelete('cascade');
            $table->decimal('montant', 10, 2);
            $table->string('tranche', 50);
            $table->date('date_paiement');
            $table->string('reference', 50)->nullable();
            $table->foreignId('enregistre_par')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }
};
