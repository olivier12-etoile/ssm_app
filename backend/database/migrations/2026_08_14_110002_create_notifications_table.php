<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('titre');
            $table->text('message');
            $table->foreignId('modele_message_id')->nullable()->constrained('modeles_messages')->nullOnDelete();
            $table->enum('type_cible', [
                'ecole_entiere',
                'classe',
                'plusieurs_classes',
                'eleve',
                'enseignants',
                'personnel_administratif',
            ]);
            $table->json('cibles')->nullable();
            $table->enum('canal', ['whatsapp', 'sms', 'interne', 'email']);
            $table->boolean('urgent')->default(false);
            $table->boolean('programmee')->default(false);
            $table->dateTime('date_envoi_prevue')->nullable();
            $table->enum('statut', [
                'preparation',
                'programmee',
                'en_cours',
                'envoyee',
                'echec_partiel',
                'echec',
            ])->default('preparation');
            $table->foreignId('cree_par')->constrained('users');
            $table->unsignedInteger('nombre_destinataires')->default(0);
            $table->unsignedInteger('nombre_envoyes')->default(0);
            $table->unsignedInteger('nombre_echoues')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
