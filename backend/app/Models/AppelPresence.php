<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class AppelPresence extends Model
{
    use FiltreParEcole;

    protected $table = 'appels_presence';

    protected $fillable = [
        'ecole_id',
        'classe_id',
        'matiere_id',
        'enseignant_id',
        'annee_scolaire_id',
        'periode_id',
        'date_appel',
        'creneau_horaire_id',
        'statut',
    ];

    protected function casts(): array
    {
        return [
            'date_appel' => 'date',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
    }

    public function enseignant()
    {
        return $this->belongsTo(User::class, 'enseignant_id');
    }

    public function anneeScolaire()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_scolaire_id');
    }

    public function periode()
    {
        return $this->belongsTo(PeriodeAcademique::class, 'periode_id');
    }

    public function creneauHoraire()
    {
        return $this->belongsTo(CreneauHoraire::class, 'creneau_horaire_id');
    }

    public function presences()
    {
        return $this->hasMany(Presence::class, 'appel_presence_id');
    }
}
