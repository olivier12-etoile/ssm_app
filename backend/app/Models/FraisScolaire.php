<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class FraisScolaire extends Model
{
    use FiltreParEcole;

    protected $table = 'frais_scolaires';

    protected $fillable = [
        'ecole_id',
        'nom',
        'description',
        'montant',
        'classe_id',
        'serie',
        'annee_scolaire_id',
        'date_limite',
        'obligatoire',
        'actif',
    ];

    protected function casts(): array
    {
        return [
            'montant'     => 'decimal:2',
            'date_limite' => 'date',
            'obligatoire' => 'boolean',
            'actif'       => 'boolean',
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

    public function anneeScolaire()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_scolaire_id');
    }

    public function echeances()
    {
        return $this->hasMany(EcheanceFrais::class, 'frais_scolaire_id')->orderBy('ordre');
    }

    public function paiements()
    {
        return $this->hasMany(Paiement::class, 'frais_scolaire_id');
    }

    public function remises()
    {
        return $this->hasMany(RemiseEleve::class, 'frais_scolaire_id');
    }

    public function exonerations()
    {
        return $this->hasMany(ExonerationEleve::class, 'frais_scolaire_id');
    }
}
