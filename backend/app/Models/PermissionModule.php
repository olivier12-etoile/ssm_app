<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PermissionModule extends Model
{
    protected $table = 'permissions_modules';

    protected $fillable = [
        'utilisateur_id',
        'nom_module',
        'autorise',
    ];

    protected $casts = [
        'autorise' => 'boolean',
    ];

    public function utilisateur()
    {
        return $this->belongsTo(User::class, 'utilisateur_id');
    }
}