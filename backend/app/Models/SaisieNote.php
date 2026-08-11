<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class SaisieNote extends Model
{
    use FiltreParEcole;

    protected $table = 'saisies_notes';

    protected $fillable = [
        'ecole_id',
        'enseignant_id',
        'classe_id',
        'matiere_id',
        'periode_id',
        'annee_scolaire_id',
        'statut',
        'date_debut',
        'date_fin_saisie',
        'date_soumission',
    ];

    protected function casts(): array
    {
        return [
            'date_debut' => 'date',
            'date_fin_saisie' => 'date',
            'date_soumission' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function enseignant()
    {
        return $this->belongsTo(User::class, 'enseignant_id');
    }

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
    }

    public function periode()
    {
        return $this->belongsTo(PeriodeAcademique::class, 'periode_id');
    }

    public function anneeScolaire()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_scolaire_id');
    }

    public function historiqueValidations()
    {
        return $this->hasMany(HistoriqueValidationNote::class, 'saisie_note_id');
    }

    public function verrouillages()
    {
        return $this->hasMany(VerrouillageNote::class, 'saisie_note_id');
    }

    // Notes rattachées à cette saisie. Pas de clé étrangère directe entre
    // notes et saisies_notes : la correspondance se fait par contexte
    // (ecole/classe/matiere/periode/enseignant).
    public function notes(): Builder
    {
        return Note::where('ecole_id', $this->ecole_id)
            ->where('classe_id', $this->classe_id)
            ->where('matiere_id', $this->matiere_id)
            ->where('periode_id', $this->periode_id)
            ->where('saisi_par', $this->enseignant_id);
    }

    public function verrouillageActuel(): ?VerrouillageNote
    {
        return $this->verrouillages()->latest('id')->first();
    }

    public function estVerrouillee(): bool
    {
        return $this->verrouillageActuel()?->verrouille ?? false;
    }
}
