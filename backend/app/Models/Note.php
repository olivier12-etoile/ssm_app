<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;

class Note extends Model
{
    use FiltreParEcole;

    protected $table = 'notes';

    protected $fillable = [
        'ecole_id',
        'eleve_id',
        'matiere_id',
        'classe_id',
        'annee_scolaire_id',
        'periode_id',
        'valeur',
        'type_evaluation',
        'coefficient',
        'saisi_par',
        'statut',
        'valide_par',
        'date_validation',
        'motif_rejet',
    ];

    protected function casts(): array
    {
        return [
            'valeur' => 'decimal:2',
            'coefficient' => 'decimal:2',
            'date_validation' => 'datetime',
        ];
    }

    // Une note n'est modifiable par l'enseignant que si elle est encore en
    // brouillon ET que la saisie (classe/matière/période) à laquelle elle
    // appartient n'est pas verrouillée. Il n'y a pas de clé étrangère
    // directe vers saisies_notes : la correspondance se fait par contexte
    // (ecole/classe/matiere/periode/enseignant), voir saisieAssociee().
    protected function modifiable(): Attribute
    {
        return Attribute::get(function () {
            if ($this->statut !== 'brouillon') {
                return false;
            }

            return !($this->saisieAssociee()?->estVerrouillee() ?? false);
        });
    }

    public function saisieAssociee(): ?SaisieNote
    {
        return SaisieNote::where('ecole_id', $this->ecole_id)
            ->where('enseignant_id', $this->saisi_par)
            ->where('classe_id', $this->classe_id)
            ->where('matiere_id', $this->matiere_id)
            ->where('periode_id', $this->periode_id)
            ->first();
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
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

    public function saisiPar()
    {
        return $this->belongsTo(User::class, 'saisi_par');
    }

    public function validePar()
    {
        return $this->belongsTo(User::class, 'valide_par');
    }
}
