<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class HistoriqueAnnee extends Model
{
    protected $table = 'historique_annees';

    public $timestamps = false;

    protected $fillable = [
        'annee_id',
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

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_id');
    }

    public function utilisateur()
    {
        return $this->belongsTo(User::class, 'fait_par');
    }
}