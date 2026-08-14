<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class JournalGlobal extends Model
{
    protected $table = 'journal_global';

    public $timestamps = false;

    protected $fillable = [
        'ecole_id',
        'user_id',
        'module',
        'action',
        'description',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function utilisateur()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Enregistre une action cross-module dans le journal global. À terme
     * (Phase 4), les journaux existants (frais, notes, emploi du temps, ...)
     * appelleront ceci en plus de leur propre journal détaillé.
     */
    public static function enregistrer(int $ecoleId, string $module, string $action, ?string $description = null, ?int $userId = null): self
    {
        return self::create([
            'ecole_id'    => $ecoleId,
            'user_id'     => $userId,
            'module'      => $module,
            'action'      => $action,
            'description' => $description,
        ]);
    }
}
