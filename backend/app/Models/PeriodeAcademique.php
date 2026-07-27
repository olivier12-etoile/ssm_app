<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PeriodeAcademique extends Model
{
    protected $table = 'periodes_academiques';

    protected $fillable = [
        'annee_academique_id',
        'nom',
        'code',
        'date_debut',
        'date_fin',
        'statut',
        'ouverte_par',
        'ouverte_le',
        'fermee_par',
        'fermee_le',
        'alerte_envoyee',
    ];

    protected function casts(): array
    {
        return [
            'ouverte_le'     => 'datetime',
            'fermee_le'      => 'datetime',
            'alerte_envoyee' => 'boolean',
        ];
    }

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_academique_id');
    }

    public function notes()
    {
        return $this->hasMany(Note::class, 'periode_id');
    }

    public function ouvertePar()
    {
        return $this->belongsTo(User::class, 'ouverte_par');
    }

    public function fermeePar()
    {
        return $this->belongsTo(User::class, 'fermee_par');
    }
}