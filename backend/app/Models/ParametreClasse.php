<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreClasse extends Model
{
    protected $table = 'parametres_classes';

    protected $fillable = [
        'ecole_id',
        'effectif_max_par_classe',
        'format_code_classe',
    ];

    protected function casts(): array
    {
        return [
            'effectif_max_par_classe' => 'integer',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
