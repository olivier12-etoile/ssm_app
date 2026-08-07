<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('echeances_frais', function (Blueprint $table) {
            $table->id();
            $table->foreignId('frais_scolaire_id')->constrained('frais_scolaires')->onDelete('cascade');
            $table->string('libelle');
            $table->decimal('montant', 10, 2);
            $table->date('date_limite');
            $table->unsignedTinyInteger('ordre')->default(1);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('echeances_frais');
    }
};
