<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class Presence extends Model
{
    protected $table = 'presences';

    protected $fillable = [
        'appel_presence_id',
        'eleve_id',
        'statut',
        'justifie',
        'motif_justification',
        'minutes_retard',
        'notifie_parent',
    ];

    protected function casts(): array
    {
        return [
            'justifie' => 'boolean',
            'notifie_parent' => 'boolean',
            'minutes_retard' => 'integer',
        ];
    }

    public function appelPresence()
    {
        return $this->belongsTo(AppelPresence::class, 'appel_presence_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    /**
     * Totaux d'absences justifiées/non justifiées et de retards d'un élève
     * sur une période, calculés uniquement sur les appels terminés (un appel
     * "en_cours" n'est pas encore fiable). Réutilisé par Eleve::statistiquesPresence()
     * et par GenerationBulletinService pour remplir absences_justifiees/
     * absences_non_justifiees/retards à la génération du bulletin.
     */
    public static function totauxPourEleve(int $eleveId, int $periodeId): array
    {
        $lignes = static::query()
            ->select('presences.statut', 'presences.justifie', DB::raw('count(*) as total'))
            ->join('appels_presence', 'appels_presence.id', '=', 'presences.appel_presence_id')
            ->where('presences.eleve_id', $eleveId)
            ->where('appels_presence.periode_id', $periodeId)
            ->where('appels_presence.statut', 'termine')
            ->groupBy('presences.statut', 'presences.justifie')
            ->get();

        $absencesJustifiees = 0;
        $absencesNonJustifiees = 0;
        $retards = 0;
        $presents = 0;

        foreach ($lignes as $ligne) {
            match ($ligne->statut) {
                'absent' => $ligne->justifie ? $absencesJustifiees += $ligne->total : $absencesNonJustifiees += $ligne->total,
                'retard' => $retards += $ligne->total,
                'present' => $presents += $ligne->total,
                default => null,
            };
        }

        $totalAppels = $absencesJustifiees + $absencesNonJustifiees + $retards + $presents;

        return [
            'absences_justifiees' => $absencesJustifiees,
            'absences_non_justifiees' => $absencesNonJustifiees,
            'retards' => $retards,
            'presents' => $presents,
            'total_appels' => $totalAppels,
            'taux_presence' => $totalAppels > 0 ? round((($presents + $retards) / $totalAppels) * 100, 2) : 0.0,
        ];
    }
}
