<?php

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;

/**
 * Ajoute un scope global "parEcole" qui filtre automatiquement toutes les
 * requêtes du modèle sur l'ecole_id de l'utilisateur connecté, et
 * pré-remplit ecole_id à la création si non fourni.
 */
trait FiltreParEcole
{
    protected static function bootFiltreParEcole(): void
    {
        static::addGlobalScope('parEcole', function (Builder $builder) {
            if (auth()->check() && auth()->user()->ecole_id) {
                $builder->where((new static())->getTable() . '.ecole_id', auth()->user()->ecole_id);
            }
        });

        static::creating(function ($model) {
            if (empty($model->ecole_id) && auth()->check()) {
                $model->ecole_id = auth()->user()->ecole_id;
            }
        });
    }
}
