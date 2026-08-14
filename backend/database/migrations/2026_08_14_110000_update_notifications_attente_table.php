<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Le module Notifications peut cibler des enseignants/personnel (pas
     * seulement des élèves) : eleve_id doit devenir nullable et on ajoute
     * user_id. Le type "notification" couvre les envois génériques créés
     * par ce module (en plus de absence/paiement/bulletin déjà utilisés).
     */
    public function up(): void
    {
        Schema::table('notifications_attente', function (Blueprint $table) {
            $table->dropForeign(['eleve_id']);
        });

        Schema::table('notifications_attente', function (Blueprint $table) {
            $table->foreignId('eleve_id')->nullable()->change();
            $table->foreignId('user_id')->nullable()->after('eleve_id')->constrained('users')->onDelete('cascade');
            $table->enum('type', ['absence', 'paiement', 'bulletin', 'notification'])->change();
        });

        Schema::table('notifications_attente', function (Blueprint $table) {
            $table->foreign('eleve_id')->references('id')->on('eleves')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::table('notifications_attente', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->dropColumn('user_id');
            $table->dropForeign(['eleve_id']);
        });

        Schema::table('notifications_attente', function (Blueprint $table) {
            $table->foreignId('eleve_id')->nullable(false)->change();
            $table->enum('type', ['absence', 'paiement', 'bulletin'])->change();
        });

        Schema::table('notifications_attente', function (Blueprint $table) {
            $table->foreign('eleve_id')->references('id')->on('eleves')->onDelete('cascade');
        });
    }
};
