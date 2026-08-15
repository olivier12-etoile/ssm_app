<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Historique des corrections apportées à un bulletin après validation
     * (une note, la décision du conseil, une appréciation, ...).
     */
    public function up(): void
    {
        Schema::create('corrections_bulletins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bulletin_id')->constrained('bulletins')->onDelete('cascade');
            $table->foreignId('bulletin_detail_id')->nullable()->constrained('bulletin_details')->nullOnDelete();

            $table->string('champ_modifie', 100);
            $table->text('ancienne_valeur')->nullable();
            $table->text('nouvelle_valeur')->nullable();
            $table->text('motif');
            $table->foreignId('demande_par')->constrained('users');

            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('corrections_bulletins');
    }
};
