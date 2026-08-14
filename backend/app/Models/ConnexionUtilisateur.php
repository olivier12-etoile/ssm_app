<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class ConnexionUtilisateur extends Model
{
    use FiltreParEcole;

    protected $table = 'connexions_utilisateurs';

    protected $fillable = [
        'user_id',
        'ecole_id',
        'date_connexion',
        'ip',
        'appareil',
    ];

    protected function casts(): array
    {
        return [
            'date_connexion' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function utilisateur()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
