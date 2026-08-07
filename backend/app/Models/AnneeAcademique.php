<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AnneeAcademique extends Model
{
    protected $table = 'annees_academiques';

    protected $fillable = [
        'ecole_id',
        'libelle',
        'date_debut',
        'date_fin',
        'statut',
        'type_periodes',
        'cree_par',
        'active_par',
        'active_le',
        'cloture_par',
        'cloture_le',
        'regle_passage_moyenne',
    ];

    protected function casts(): array
    {
        return [
            'date_debut'             => 'date',
            'date_fin'               => 'date',
            'active_le'              => 'datetime',
            'cloture_le'             => 'datetime',
            'regle_passage_moyenne'  => 'decimal:2',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function periodes()
    {
        return $this->hasMany(PeriodeAcademique::class, 'annee_academique_id')->orderBy('ordre');
    }

    public function classes()
    {
        return $this->hasMany(Classe::class, 'annee_academique_id');
    }

    public function inscriptions()
    {
        return $this->hasMany(Inscription::class, 'annee_academique_id');
    }

    public function creePar()
    {
        return $this->belongsTo(User::class, 'cree_par');
    }

    // Alias explicitement demandé par le cahier des charges.
    public function createurCompte()
    {
        return $this->creePar();
    }

    public function activePar()
    {
        return $this->belongsTo(User::class, 'active_par');
    }

    public function cloturePar()
    {
        return $this->belongsTo(User::class, 'cloture_par');
    }

    public function historique()
    {
        return $this->hasMany(HistoriqueAnnee::class, 'annee_id');
    }

    public function journalActions()
    {
        return JournalAction::where('entite_type', 'AnneeAcademique')->where('entite_id', $this->id);
    }

    /**
     * Retourne la période "ouverte", sinon la période "en_veille" la plus récente.
     */
    public function periodeActive(): ?PeriodeAcademique
    {
        return $this->periodes()->where('statut', 'ouverte')->first()
            ?? $this->periodes()->where('statut', 'en_veille')->orderByDesc('ouverte_le')->first();
    }

    /**
     * Nombre de jours restants avant la date_fin de la période active.
     * Négatif si la date de fin est dépassée, null si aucune période active.
     */
    public function joursRestantsPeriode(): ?int
    {
        $periode = $this->periodeActive();

        if (!$periode) {
            return null;
        }

        return (int) now()->startOfDay()->diffInDays($periode->date_fin, false);
    }
}
