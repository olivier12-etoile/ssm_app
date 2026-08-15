<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class Bulletin extends Model
{
    use FiltreParEcole;

    protected $table = 'bulletins';

    protected $fillable = [
        'ecole_id',
        'eleve_id',
        'classe_id',
        'annee_scolaire_id',
        'periode_id',
        'moyenne_generale',
        'rang',
        'rang_ex_aequo',
        'effectif_classe',
        'total_coefficients',
        'total_points',
        'absences_justifiees',
        'absences_non_justifiees',
        'retards',
        'decision_conseil',
        'appreciation_generale',
        'statut',
        'genere_par',
        'valide_par',
        'date_validation',
        'professeur_principal_id',
    ];

    protected function casts(): array
    {
        return [
            'moyenne_generale' => 'decimal:2',
            'total_coefficients' => 'decimal:2',
            'total_points' => 'decimal:2',
            'rang_ex_aequo' => 'boolean',
            'rang' => 'integer',
            'effectif_classe' => 'integer',
            'absences_justifiees' => 'integer',
            'absences_non_justifiees' => 'integer',
            'retards' => 'integer',
            'date_validation' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
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

    public function details()
    {
        return $this->hasMany(BulletinDetail::class, 'bulletin_id');
    }

    public function corrections()
    {
        return $this->hasMany(CorrectionBulletin::class, 'bulletin_id');
    }

    public function generePar()
    {
        return $this->belongsTo(User::class, 'genere_par');
    }

    public function validePar()
    {
        return $this->belongsTo(User::class, 'valide_par');
    }

    public function professeurPrincipal()
    {
        return $this->belongsTo(User::class, 'professeur_principal_id');
    }
}
