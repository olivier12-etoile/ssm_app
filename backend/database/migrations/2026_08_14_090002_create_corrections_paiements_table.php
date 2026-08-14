<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('corrections_paiements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('paiement_id')->constrained('paiements')->onDelete('cascade');
            $table->foreignId('corrige_par')->constrained('users');
            $table->decimal('ancien_montant', 10, 2);
            $table->decimal('nouveau_montant', 10, 2);
            $table->string('ancien_mode_paiement')->nullable();
            $table->string('nouveau_mode_paiement')->nullable();
            $table->text('motif');
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('corrections_paiements');
    }
};
