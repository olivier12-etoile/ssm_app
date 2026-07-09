<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Eleve extends Model
{
    protected $table = 'eleves';

    protected $fillable = [
        'ecole_id',
        'nom',
        'prenom',
        'date_naissance',
        'sexe',
        'matricule',
        'telephone_parent',
        'photo_path'
    ];

    protected $appends = ['photo_url'];

public function getPhotoUrlAttribute()
{
    return $this->photo_path
        ? asset('storage/' . $this->photo_path)
        : null;
}

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function inscriptions()
    {
        return $this->hasMany(Inscription::class, 'eleve_id');
    }

    public function notes()
    {
        return $this->hasMany(Note::class, 'eleve_id');
    }

    public function paiements()
    {
        return $this->hasMany(Paiement::class, 'eleve_id');
    }

    public function absences()
    {
        return $this->hasMany(Absence::class, 'eleve_id');
    }
}