<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NoteEvaluation extends Model
{
    protected $table = 'notes_evaluations';

    protected $fillable = [
        'evaluation_id',
        'eleve_id',
        'valeur',
    ];

    public function evaluation()
    {
        return $this->belongsTo(Evaluation::class, 'evaluation_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }
}
