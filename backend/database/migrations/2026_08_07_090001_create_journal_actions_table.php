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
        Schema::create('journal_actions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('entite_type', 30);
            $table->unsignedBigInteger('entite_id');
            $table->enum('action', [
                'creation',
                'activation',
                'ouverture',
                'cloture',
                'reouverture',
                'generation_bulletins',
                'passage_eleves',
                'archivage',
            ]);
            $table->foreignId('fait_par')->constrained('users')->onDelete('cascade');
            $table->text('details')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['ecole_id', 'entite_type', 'entite_id'], 'journal_actions_entite_idx');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('journal_actions');
    }
};
