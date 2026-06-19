<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('absences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('eleve_id')->constrained('eleves')->onDelete('cascade');
            $table->foreignId('classe_id')->constrained('classes')->onDelete('cascade');
            $table->date('date_absence');
            $table->boolean('justifiee')->default(false);
            $table->text('motif')->nullable();
            $table->foreignId('marque_par')->constrained('users')->onDelete('cascade');
            $table->boolean('notifie')->default(false);
            $table->timestamps();

            // Un élève ne peut avoir qu'une seule absence par jour
            $table->unique(['eleve_id', 'date_absence'], 'absence_eleve_date_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('absences');
    }
};