<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use App\Http\Middleware\VerifierPermissionMiddleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        // ← CORS pour Flutter
        $middleware->validateCsrfTokens(except: ['api/*']);

        // Complément progressif aux contrôles de rôle en dur — voir le
        // commentaire de classe de VerifierPermissionMiddleware. Non câblé
        // sur les routes existantes pour l'instant.
        $middleware->alias(['permission' => VerifierPermissionMiddleware::class]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();