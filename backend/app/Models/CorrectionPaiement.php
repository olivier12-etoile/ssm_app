<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CorrectionPaiement extends Model
{
    protected $table = 'corrections_paiements';

    public $timestamps = false;

    protected $fillable = [
        'paiement_id',
        'corrige_par',
        'ancien_montant',
        'nouveau_montant',
        'ancien_mode_paiement',
        'nouveau_mode_paiement',
        'motif',
    ];

    protected function casts(): array
    {
        return [
            'ancien_montant'  => 'decimal:2',
            'nouveau_montant' => 'decimal:2',
            'created_at'      => 'datetime',
        ];
    }

    public function paiement()
    {
        return $this->belongsTo(Paiement::class, 'paiement_id');
    }

    public function corrigePar()
    {
        return $this->belongsTo(User::class, 'corrige_par');
    }
}
