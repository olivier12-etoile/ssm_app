<?php

namespace App\Services;

use App\Models\Bulletin;
use Illuminate\Support\Collection;

/**
 * Statistiques calculées à partir des bulletins déjà générés (donc figées
 * au moment de la génération, comme le reste du module) -- pas à partir des
 * notes en direct comme NoteCalculService.
 */
class StatistiqueBulletinService
{
    private const SEUIL_REUSSITE = 10.0;

    public function parClasse(int $classeId, int $periodeId): array
    {
        $moyennes = $this->moyennesClasse($classeId, $periodeId);
        $effectif = $moyennes->count();

        $nombreAdmis = $moyennes->filter(fn (float $m) => $m >= self::SEUIL_REUSSITE)->count();

        return [
            'classe_id' => $classeId,
            'periode_id' => $periodeId,
            'effectif' => $effectif,
            'moyenne_classe' => $effectif > 0 ? round($moyennes->avg(), 2) : null,
            'meilleure_moyenne' => $effectif > 0 ? round($moyennes->max(), 2) : null,
            'plus_faible_moyenne' => $effectif > 0 ? round($moyennes->min(), 2) : null,
            'nombre_eleves_superieur_egal_10' => $nombreAdmis,
            'nombre_eleves_inferieur_10' => $effectif - $nombreAdmis,
            'taux_reussite' => $effectif > 0 ? round($nombreAdmis / $effectif * 100, 1) : 0.0,
        ];
    }

    public function distributionMoyennes(int $classeId, int $periodeId): array
    {
        $moyennes = $this->moyennesClasse($classeId, $periodeId);
        $effectif = $moyennes->count();

        $tranches = [
            '< 10' => fn (float $m) => $m < 10,
            '10-12' => fn (float $m) => $m >= 10 && $m < 12,
            '12-14' => fn (float $m) => $m >= 12 && $m < 14,
            '14-16' => fn (float $m) => $m >= 14 && $m < 16,
            '16-20' => fn (float $m) => $m >= 16,
        ];

        $distribution = collect($tranches)->map(function (callable $filtre, string $libelle) use ($moyennes, $effectif) {
            $nombre = $moyennes->filter($filtre)->count();

            return [
                'tranche' => $libelle,
                'nombre_eleves' => $nombre,
                'pourcentage' => $effectif > 0 ? round($nombre / $effectif * 100, 1) : 0.0,
            ];
        })->values();

        return [
            'classe_id' => $classeId,
            'periode_id' => $periodeId,
            'effectif' => $effectif,
            'distribution' => $distribution,
        ];
    }

    public function comparaisonPeriodes(int $classeId, int $periodeId1, int $periodeId2): array
    {
        $statsPeriode1 = $this->parClasse($classeId, $periodeId1);
        $statsPeriode2 = $this->parClasse($classeId, $periodeId2);

        $evolution = ($statsPeriode1['moyenne_classe'] !== null && $statsPeriode2['moyenne_classe'] !== null)
            ? round($statsPeriode2['moyenne_classe'] - $statsPeriode1['moyenne_classe'], 2)
            : null;

        return [
            'classe_id' => $classeId,
            'periode_1' => $statsPeriode1,
            'periode_2' => $statsPeriode2,
            'evolution_moyenne_classe' => $evolution,
            'progression' => match (true) {
                $evolution === null => null,
                $evolution > 0 => 'hausse',
                $evolution < 0 => 'baisse',
                default => 'stable',
            },
        ];
    }

    private function moyennesClasse(int $classeId, int $periodeId): Collection
    {
        return Bulletin::where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->pluck('moyenne_generale')
            ->map(fn ($m) => (float) $m);
    }
}
