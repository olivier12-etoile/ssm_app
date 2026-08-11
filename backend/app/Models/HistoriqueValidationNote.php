<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class HistoriqueValidationNote extends Model
{
    protected $table = 'historique_validations_notes';

    public $timestamps = false;

    protected $fillable = [
        'saisie_note_id',
        'action',
        'effectue_par',
        'motif',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function saisieNote()
    {
        return $this->belongsTo(SaisieNote::class, 'saisie_note_id');
    }

    public function effectuePar()
    {
        return $this->belongsTo(User::class, 'effectue_par');
    }
}
