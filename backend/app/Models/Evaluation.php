<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Evaluation extends Model
{
    protected $table = 'evaluations';

    protected $fillable = [
        'classe_id',
        'matiere_id',
        'periode_id',
        'enseignant_id',
        'type',
        'numero',
        'libelle',
        'date_evaluation',
    ];

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

    public function enseignant()
    {
        return $this->belongsTo(User::class, 'enseignant_id');
    }

    public function notes()
    {
        return $this->hasMany(NoteEvaluation::class, 'evaluation_id');
    }
}
