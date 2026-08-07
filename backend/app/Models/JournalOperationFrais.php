<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class JournalOperationFrais extends Model
{
    use FiltreParEcole;

    protected $table = 'journal_operations_frais';

    public $timestamps = false;

    protected $fillable = [
        'ecole_id',
        'user_id',
        'action',
        'description',
        'paiement_id',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function paiement()
    {
        return $this->belongsTo(Paiement::class, 'paiement_id');
    }
}
