<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'ecole_id',
        'mot_de_passe_change',
        'prenom',
        'sexe',
        'telephone',
        'adresse',
        'fonction',
        'photo_path',
        'actif',
        'derniere_connexion',
        'derniere_activite',
        'mot_de_passe_temporaire',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $appends = ['photo_url'];

    protected function casts(): array
    {
        return [
            'email_verified_at'    => 'datetime',
            'password'             => 'hashed',
            'mot_de_passe_change'  => 'boolean',
            'actif'                => 'boolean',
            'derniere_connexion'   => 'datetime',
            'derniere_activite'    => 'datetime',
        ];
    }

    public function getPhotoUrlAttribute()
    {
        return $this->photo_path
            ? asset('storage/' . $this->photo_path)
            : null;
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function permissions()
    {
        return $this->hasMany(PermissionModule::class, 'utilisateur_id');
    }

    public function notes()
    {
        return $this->hasMany(Note::class, 'enseignant_id');
    }
}