<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class JournalAction extends Model
{
    protected $table = 'journal_actions';

    public $timestamps = false;

    protected $fillable = [
        'ecole_id',
        'entite_type',
        'entite_id',
        'action',
        'fait_par',
        'details',
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

    public function auteur()
    {
        return $this->belongsTo(User::class, 'fait_par');
    }

    /**
     * Enregistre une action dans le journal.
     */
    public static function enregistrer(string $entiteType, int $entiteId, string $action, int $faitPar, int $ecoleId, ?array $details = null): self
    {
        return self::create([
            'ecole_id'    => $ecoleId,
            'entite_type' => $entiteType,
            'entite_id'   => $entiteId,
            'action'      => $action,
            'fait_par'    => $faitPar,
            'details'     => $details ? json_encode($details) : null,
        ]);
    }
}
