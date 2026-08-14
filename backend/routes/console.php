<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Relance automatique des impayés, chaque lundi matin (voir
// NotifierImpayesCommand pour les options --jours/--relance).
Schedule::command('notifications:impayes')->weeklyOn(1, '07:00');
