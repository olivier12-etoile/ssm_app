<?php

namespace App\Services;

use App\Models\Eleve;
use App\Models\Inscription;
use App\Models\ParentEleve;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Résout la liste réelle des destinataires d'une notification à partir de
 * son type_cible + cibles (JSON). Le téléphone d'un élève est toujours lu
 * sur eleve->telephone_parent, comme le fait déjà le reste de l'application
 * (Paiement/Absence/BulletinController) pour alimenter notifications_attente.
 */
class CiblageNotificationService
{
    private const ROLES_PERSONNEL_ADMINISTRATIF = ['directeur', 'censeur', 'secretaire', 'comptable'];

    public function resoudreDestinataires(int $ecoleId, string $typeCible, ?array $cibles): Collection
    {
        return match ($typeCible) {
            'ecole_entiere'           => $this->destinatairesElevesActifs($ecoleId),
            'classe'                  => $this->destinatairesClasses($ecoleId, $this->idsDepuis($cibles, 'classe_id', 'classe_ids')),
            'plusieurs_classes'       => $this->destinatairesClasses($ecoleId, $this->idsDepuis($cibles, 'classe_id', 'classe_ids')),
            'eleve'                   => $this->destinatairesEleves($ecoleId, $this->idsDepuis($cibles, 'eleve_id', 'eleve_ids')),
            'enseignants'             => $this->destinatairesParRole($ecoleId, ['enseignant']),
            'personnel_administratif' => $this->destinatairesParRole($ecoleId, self::ROLES_PERSONNEL_ADMINISTRATIF),
            default                   => collect(),
        };
    }

    public function compterDestinataires(int $ecoleId, string $typeCible, ?array $cibles): int
    {
        return $this->resoudreDestinataires($ecoleId, $typeCible, $cibles)->count();
    }

    // Accepte indifféremment une clé singulière ('classe_id') ou plurielle
    // ('classe_ids') dans le JSON cibles, pour rester tolérant sur le format
    // envoyé par le frontend.
    private function idsDepuis(?array $cibles, string $clesingulier, string $clepluriel): array
    {
        if (empty($cibles)) {
            return [];
        }

        if (!empty($cibles[$clepluriel]) && is_array($cibles[$clepluriel])) {
            return array_values(array_filter($cibles[$clepluriel]));
        }

        if (!empty($cibles[$clesingulier])) {
            return [$cibles[$clesingulier]];
        }

        return [];
    }

    private function destinatairesElevesActifs(int $ecoleId): Collection
    {
        return $this->destinatairesDepuisEleves(
            Eleve::where('ecole_id', $ecoleId)->where('statut', 'actif')->get()
        );
    }

    private function destinatairesClasses(int $ecoleId, array $classeIds): Collection
    {
        if (empty($classeIds)) {
            return collect();
        }

        $eleveIds = Inscription::whereIn('classe_id', $classeIds)
            ->whereHas('classe', fn($q) => $q->where('ecole_id', $ecoleId))
            ->pluck('eleve_id')
            ->unique();

        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereIn('id', $eleveIds)
            ->where('statut', 'actif')
            ->get();

        return $this->destinatairesDepuisEleves($eleves);
    }

    private function destinatairesEleves(int $ecoleId, array $eleveIds): Collection
    {
        if (empty($eleveIds)) {
            return collect();
        }

        $eleves = Eleve::where('ecole_id', $ecoleId)->whereIn('id', $eleveIds)->get();

        return $this->destinatairesDepuisEleves($eleves);
    }

    // Un élève sans numéro de parent n'est pas un destinataire "réel" :
    // il est exclu du comptage/de la liste plutôt que de produire une entrée
    // injoignable.
    private function destinatairesDepuisEleves(Collection $eleves): Collection
    {
        return $eleves
            ->filter(fn(Eleve $eleve) => !empty($eleve->telephone_parent))
            ->map(function (Eleve $eleve) {
                $parent = ParentEleve::where('eleve_id', $eleve->id)->first();

                return [
                    'nom'       => $parent
                        ? trim($parent->prenom . ' ' . $parent->nom)
                        : 'Parent de ' . trim($eleve->prenom . ' ' . $eleve->nom),
                    'telephone' => $eleve->telephone_parent,
                    'eleve_id'  => $eleve->id,
                    'user_id'   => null,
                ];
            })
            ->values();
    }

    private function destinatairesParRole(int $ecoleId, array $roles): Collection
    {
        return User::where('ecole_id', $ecoleId)
            ->whereIn('role', $roles)
            ->where('actif', true)
            ->get()
            ->map(fn(User $user) => [
                'nom'       => trim(($user->prenom ?? '') . ' ' . $user->name),
                'telephone' => $user->telephone,
                'eleve_id'  => null,
                'user_id'   => $user->id,
            ])
            ->values();
    }
}
