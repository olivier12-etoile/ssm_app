<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class PeriodeAcademique extends Model
{
    protected $table = 'periodes_academiques';

    protected $fillable = [
        'annee_academique_id',
        'nom',
        'code',
        'couleur',
        'ordre',
        'date_debut',
        'date_fin',
        'statut',
        'ouverte_par',
        'ouverte_le',
        'fermee_par',
        'fermee_le',
        'alerte_envoyee',
    ];

    protected function casts(): array
    {
        return [
            'date_debut'     => 'date',
            'date_fin'       => 'date',
            'ordre'          => 'integer',
            'ouverte_le'     => 'datetime',
            'fermee_le'      => 'datetime',
            'alerte_envoyee' => 'boolean',
        ];
    }

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_academique_id');
    }

    public function notes()
    {
        return $this->hasMany(Note::class, 'periode_id');
    }

    public function bulletins()
    {
        return $this->hasMany(Bulletin::class, 'periode_id');
    }

    public function ouvertePar()
    {
        return $this->belongsTo(User::class, 'ouverte_par');
    }

    public function fermeePar()
    {
        return $this->belongsTo(User::class, 'fermee_par');
    }

    /**
     * Pourcentage de la durée de la période déjà écoulé (0 à 100).
     */
    public function progressionJours(): int
    {
        $debut = $this->date_debut;
        $fin = $this->date_fin;

        $totalJours = max(1, $debut->diffInDays($fin));
        $joursPasses = min($totalJours, max(0, $debut->diffInDays(now()->startOfDay(), false)));

        return (int) round(($joursPasses / $totalJours) * 100);
    }

    /**
     * État de saisie des notes pour chaque affectation (enseignant, classe,
     * matière) de l'année de cette période : nombre de notes saisies sur le
     * nombre d'élèves attendus, et un statut termine|en_cours|pas_commence.
     */
    public function etatEnseignants()
    {
        $affectations = DB::table('enseignant_classe_matiere')
            ->join('classes', 'classes.id', '=', 'enseignant_classe_matiere.classe_id')
            ->join('users', 'users.id', '=', 'enseignant_classe_matiere.enseignant_id')
            ->join('matieres', 'matieres.id', '=', 'enseignant_classe_matiere.matiere_id')
            ->where('classes.annee_academique_id', $this->annee_academique_id)
            ->select(
                'enseignant_classe_matiere.enseignant_id',
                'users.name as enseignant_nom',
                'enseignant_classe_matiere.classe_id',
                'classes.nom as classe_nom',
                'enseignant_classe_matiere.matiere_id',
                'matieres.nom as matiere_nom'
            )
            ->distinct()
            ->get();

        return $affectations->map(function ($a) {
            $notesTotal = Inscription::where('classe_id', $a->classe_id)
                ->where('annee_academique_id', $this->annee_academique_id)
                ->count();

            $notesSaisies = Note::where('periode_id', $this->id)
                ->where('matiere_id', $a->matiere_id)
                ->where('enseignant_id', $a->enseignant_id)
                ->whereHas('eleve.inscriptions', fn($q) => $q->where('classe_id', $a->classe_id)
                    ->where('annee_academique_id', $this->annee_academique_id))
                ->count();

            $pourcentage = $notesTotal > 0 ? (int) round(($notesSaisies / $notesTotal) * 100) : 0;

            return [
                'enseignant_id'   => $a->enseignant_id,
                'enseignant_nom'  => $a->enseignant_nom,
                'classe_id'       => $a->classe_id,
                'classe_nom'      => $a->classe_nom,
                'matiere_id'      => $a->matiere_id,
                'matiere_nom'     => $a->matiere_nom,
                'notes_saisies'   => $notesSaisies,
                'notes_total'     => $notesTotal,
                'pourcentage'     => $pourcentage,
                'statut'          => $pourcentage >= 100 ? 'termine' : ($pourcentage > 0 ? 'en_cours' : 'pas_commence'),
            ];
        })->values();
    }
}
