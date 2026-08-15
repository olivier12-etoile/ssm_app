<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CorrectionBulletin extends Model
{
    protected $table = 'corrections_bulletins';

    public $timestamps = false;

    protected $fillable = [
        'bulletin_id',
        'bulletin_detail_id',
        'champ_modifie',
        'ancienne_valeur',
        'nouvelle_valeur',
        'motif',
        'demande_par',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function bulletin()
    {
        return $this->belongsTo(Bulletin::class, 'bulletin_id');
    }

    public function bulletinDetail()
    {
        return $this->belongsTo(BulletinDetail::class, 'bulletin_detail_id');
    }

    public function demandePar()
    {
        return $this->belongsTo(User::class, 'demande_par');
    }
}
