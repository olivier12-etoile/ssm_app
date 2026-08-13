<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RemplacementSeance extends Model
{
    protected $table = 'remplacements_seances';

    protected $fillable = [
        'seance_id',
        'date_remplacement',
        'enseignant_remplacant_id',
        'motif',
        'enregistre_par',
    ];

    protected function casts(): array
    {
        return [
            'date_remplacement' => 'date',
        ];
    }

    public function seance()
    {
        return $this->belongsTo(Seance::class, 'seance_id');
    }

    public function enseignantRemplacant()
    {
        return $this->belongsTo(User::class, 'enseignant_remplacant_id');
    }

    public function enregistrePar()
    {
        return $this->belongsTo(User::class, 'enregistre_par');
    }
}
