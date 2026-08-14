<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_destinataires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('notification_id')->constrained('notifications')->onDelete('cascade');
            $table->foreignId('eleve_id')->nullable()->constrained('eleves')->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('nom_destinataire');
            $table->string('telephone', 30)->nullable();
            $table->enum('statut', ['en_attente', 'envoye', 'delivre', 'echec'])->default('en_attente');
            $table->foreignId('notification_attente_id')->nullable()->constrained('notifications_attente')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_destinataires');
    }
};
