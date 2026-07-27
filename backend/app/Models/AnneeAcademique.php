<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AnneeAcademique extends Model
{
    protected $table = 'annees_academiques';

    protected $fillable = [
        'ecole_id',
        'libelle',
        'date_debut',
        'date_fin',
        'statut',
        'cree_par',
        'active_par',
        'active_le',
        'cloture_par',
        'cloture_le',
        'regle_passage_moyenne',
        'type_periodes',
    ];

    protected function casts(): array
    {
        return [
            'active_le'              => 'datetime',
            'cloture_le'             => 'datetime',
            'regle_passage_moyenne'  => 'decimal:2',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function periodes()
    {
        return $this->hasMany(PeriodeAcademique::class, 'annee_academique_id');
    }

    public function inscriptions()
    {
        return $this->hasMany(Inscription::class, 'annee_academique_id');
    }

    public function creePar()
    {
        return $this->belongsTo(User::class, 'cree_par');
    }

    public function activePar()
    {
        return $this->belongsTo(User::class, 'active_par');
    }

    public function cloturePar()
    {
        return $this->belongsTo(User::class, 'cloture_par');
    }

    public function historique()
    {
        return $this->hasMany(HistoriqueAnnee::class, 'annee_id');
    }
}