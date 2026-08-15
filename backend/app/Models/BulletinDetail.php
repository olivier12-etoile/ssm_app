<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BulletinDetail extends Model
{
    protected $table = 'bulletin_details';

    protected $fillable = [
        'bulletin_id',
        'matiere_id',
        'nom_matiere',
        'coefficient',
        'note',
        'moyenne_matiere_classe',
        'appreciation_matiere',
    ];

    protected function casts(): array
    {
        return [
            'coefficient' => 'decimal:2',
            'note' => 'decimal:2',
            'moyenne_matiere_classe' => 'decimal:2',
        ];
    }

    public function bulletin()
    {
        return $this->belongsTo(Bulletin::class, 'bulletin_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
    }

    public function corrections()
    {
        return $this->hasMany(CorrectionBulletin::class, 'bulletin_detail_id');
    }
}
