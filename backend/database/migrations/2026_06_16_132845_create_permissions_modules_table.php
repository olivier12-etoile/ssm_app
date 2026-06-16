<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('permissions_modules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->constrained('users')->onDelete('cascade');
            $table->string('nom_module', 50); // ex: notes_validation
            $table->boolean('autorise')->default(true);
            $table->timestamps();

            $table->unique(['utilisateur_id', 'nom_module']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('permissions_modules');
    }
};