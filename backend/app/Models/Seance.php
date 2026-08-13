<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class Seance extends Model
{
    use FiltreParEcole;

    protected $table = 'seances';

    protected $fillable = [
        'ecole_id',
        'emploi_du_temps_id',
        'creneau_horaire_id',
        'jour',
        'matiere_id',
        'enseignant_id',
        'salle',
        'couleur',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function emploiDuTemps()
    {
        return $this->belongsTo(EmploiDuTemps::class, 'emploi_du_temps_id');
    }

    public function creneauHoraire()
    {
        return $this->belongsTo(CreneauHoraire::class, 'creneau_horaire_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
    }

    public function enseignant()
    {
        return $this->belongsTo(User::class, 'enseignant_id');
    }

    public function remplacements()
    {
        return $this->hasMany(RemplacementSeance::class, 'seance_id');
    }
}
