<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ChronologieEleve extends Model
{
    protected $table = 'chronologie_eleves';

    public $timestamps = false;

    protected $fillable = [
        'eleve_id',
        'type',
        'titre',
        'description',
        'icone',
        'couleur',
        'reference_id',
        'reference_type',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }
}
