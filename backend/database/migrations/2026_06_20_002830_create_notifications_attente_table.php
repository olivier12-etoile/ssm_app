<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications_attente', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->enum('type', ['absence', 'paiement', 'bulletin']);
            $table->string('telephone_parent', 30)->nullable();
            $table->text('message');
            $table->enum('statut', ['en_attente', 'envoyee'])->default('en_attente');
            $table->timestamp('envoyee_le')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications_attente');
    }
};