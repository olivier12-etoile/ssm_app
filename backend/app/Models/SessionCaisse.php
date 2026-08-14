<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class SessionCaisse extends Model
{
    use FiltreParEcole;

    protected $table = 'sessions_caisse';

    protected $fillable = [
        'ecole_id',
        'caisse_id',
        'ouvert_par',
        'montant_initial',
        'date_ouverture',
        'ferme_par',
        'date_fermeture',
        'montant_theorique',
        'montant_reel',
        'ecart',
        'observation_fermeture',
        'statut',
    ];

    protected function casts(): array
    {
        return [
            'montant_initial'   => 'decimal:2',
            'date_ouverture'    => 'datetime',
            'date_fermeture'    => 'datetime',
            'montant_theorique' => 'decimal:2',
            'montant_reel'      => 'decimal:2',
            'ecart'             => 'decimal:2',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function caisse()
    {
        return $this->belongsTo(Caisse::class, 'caisse_id');
    }

    public function ouvertPar()
    {
        return $this->belongsTo(User::class, 'ouvert_par');
    }

    public function fermePar()
    {
        return $this->belongsTo(User::class, 'ferme_par');
    }

    public function paiements()
    {
        return $this->hasMany(Paiement::class, 'session_caisse_id');
    }
}
