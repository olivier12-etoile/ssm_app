<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class HistoriqueEmploiDuTemps extends Model
{
    protected $table = 'historique_emploi_du_temps';

    public $timestamps = false;

    protected $fillable = [
        'emploi_du_temps_id',
        'action',
        'effectue_par',
        'details',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function emploiDuTemps()
    {
        return $this->belongsTo(EmploiDuTemps::class, 'emploi_du_temps_id');
    }

    public function effectuePar()
    {
        return $this->belongsTo(User::class, 'effectue_par');
    }
}
