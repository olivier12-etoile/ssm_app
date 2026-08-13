<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;

class EmploiDuTemps extends Model
{
    use FiltreParEcole;

    protected $table = 'emplois_du_temps';

    protected $fillable = [
        'ecole_id',
        'classe_id',
        'annee_scolaire_id',
        'periode_id',
        'statut',
        'cree_par',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function anneeScolaire()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_scolaire_id');
    }

    public function periode()
    {
        return $this->belongsTo(PeriodeAcademique::class, 'periode_id');
    }

    public function creePar()
    {
        return $this->belongsTo(User::class, 'cree_par');
    }

    public function seances()
    {
        return $this->hasMany(Seance::class, 'emploi_du_temps_id');
    }

    public function historique()
    {
        return $this->hasMany(HistoriqueEmploiDuTemps::class, 'emploi_du_temps_id');
    }

    // Volume horaire programmé par matière (en heures), à comparer au
    // volume attendu défini sur classe_matiere. Seules les séances sur un
    // créneau de type "cours" comptent (récréations/pauses exclues).
    protected function volumeHoraireParMatiere(): Attribute
    {
        return Attribute::get(function () {
            return $this->seances()
                ->with(['matiere:id,nom', 'creneauHoraire'])
                ->get()
                ->filter(fn (Seance $s) => $s->creneauHoraire?->type === 'cours')
                ->groupBy('matiere_id')
                ->map(function ($groupe) {
                    $matiere = $groupe->first()->matiere;

                    $minutes = $groupe->sum(function (Seance $s) {
                        $debut = $s->creneauHoraire?->heure_debut;
                        $fin = $s->creneauHoraire?->heure_fin;

                        return ($debut && $fin) ? $fin->diffInMinutes($debut, true) : 0;
                    });

                    return [
                        'matiere_id' => $matiere?->id,
                        'matiere_nom' => $matiere?->nom,
                        'nombre_seances' => $groupe->count(),
                        'volume_horaire' => round($minutes / 60, 2),
                    ];
                })
                ->values();
        });
    }
}
