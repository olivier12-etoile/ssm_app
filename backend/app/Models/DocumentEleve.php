<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DocumentEleve extends Model
{
    protected $table = 'documents_eleves';

    protected $fillable = [
        'eleve_id',
        'nom',
        'type',
        'chemin_fichier',
        'taille',
    ];

    protected $appends = ['url_fichier'];

    public function getUrlFichierAttribute()
    {
        return asset('storage/' . $this->chemin_fichier);
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }
}
