<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreSecurite extends Model
{
    protected $table = 'parametres_securite';

    protected $fillable = [
        'ecole_id',
        'delai_inactivite_minutes',
    ];

    protected function casts(): array
    {
        return [
            'delai_inactivite_minutes' => 'integer',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
