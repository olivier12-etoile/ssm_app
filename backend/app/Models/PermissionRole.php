<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class PermissionRole extends Model
{
    use FiltreParEcole;

    protected $table = 'permissions_roles';

    protected $fillable = [
        'ecole_id',
        'role',
        'module',
        'peut_consulter',
        'peut_creer',
        'peut_modifier',
        'peut_supprimer',
        'peut_valider',
    ];

    protected function casts(): array
    {
        return [
            'peut_consulter' => 'boolean',
            'peut_creer' => 'boolean',
            'peut_modifier' => 'boolean',
            'peut_supprimer' => 'boolean',
            'peut_valider' => 'boolean',
        ];
    }

    // Rôles concernés par la matrice (aligné sur l'enum users.role, hors
    // super_admin qui n'est pas une gestion propre à une école).
    public const ROLES = ['directeur', 'censeur', 'enseignant', 'secretaire', 'comptable'];

    // Modules couverts par la matrice : clé technique => libellé affiché.
    public const MODULES = [
        'classes'          => 'Classes',
        'matieres'         => 'Matières',
        'eleves'           => 'Élèves',
        'notes'            => 'Notes & Évaluations',
        'validation_notes' => 'Validation des notes',
        'statistiques'     => 'Statistiques',
        'emploi_du_temps'  => 'Emploi du temps',
        'absences'         => 'Absences',
        'frais'            => 'Frais scolaires',
        'paiements'        => 'Paiements',
        'recus'            => 'Reçus',
        'bulletins'        => 'Bulletins',
        'notifications'    => 'Notifications',
        'utilisateurs'     => 'Utilisateurs',
        'parametres'       => "Paramètres de l'école",
    ];

    private const CINQ_DROITS = ['peut_consulter', 'peut_creer', 'peut_modifier', 'peut_supprimer', 'peut_valider'];

    /**
     * Droits par défaut du brief, par rôle et par module. Le directeur n'y
     * figure pas : il a toujours accès complet (voir droitsParDefaut()) et
     * ses lignes sont immuables (PermissionRoleController::update() refuse
     * toute modification sur role=directeur, sécurité anti-blocage).
     */
    public static function defauts(): array
    {
        $eleveFraisPaiementsRecus = [
            'eleves'    => ['peut_consulter' => true, 'peut_creer' => true, 'peut_modifier' => true, 'peut_supprimer' => false, 'peut_valider' => false],
            'frais'     => ['peut_consulter' => true, 'peut_creer' => true, 'peut_modifier' => true, 'peut_supprimer' => false, 'peut_valider' => false],
            'paiements' => ['peut_consulter' => true, 'peut_creer' => true, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
            'recus'     => ['peut_consulter' => true, 'peut_creer' => true, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
        ];

        return [
            'censeur' => [
                'classes'          => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
                'eleves'           => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => true, 'peut_supprimer' => false, 'peut_valider' => false],
                'notes'            => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
                // Aligné sur ValidationNoteController::autoriserGestionnaire() : directeur+censeur.
                'validation_notes' => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => true],
                'statistiques'     => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
            ],
            'enseignant' => [
                'classes'         => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
                'matieres'        => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
                // "Saisie" : l'enseignant crée/modifie ses notes en brouillon.
                'notes'           => ['peut_consulter' => true, 'peut_creer' => true, 'peut_modifier' => true, 'peut_supprimer' => false, 'peut_valider' => false],
                'absences'        => ['peut_consulter' => true, 'peut_creer' => true, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
                'emploi_du_temps' => ['peut_consulter' => true, 'peut_creer' => false, 'peut_modifier' => false, 'peut_supprimer' => false, 'peut_valider' => false],
            ],
            'secretaire' => $eleveFraisPaiementsRecus,
            'comptable'  => $eleveFraisPaiementsRecus,
        ];
    }

    // Droits effectifs par défaut d'un rôle sur un module (les 5 booléens).
    public static function droitsParDefaut(string $role, string $module): array
    {
        if ($role === 'directeur') {
            return array_fill_keys(self::CINQ_DROITS, true);
        }

        return self::defauts()[$role][$module] ?? array_fill_keys(self::CINQ_DROITS, false);
    }

    /**
     * Matrice complète prête à insérer (une ligne par rôle × module) pour
     * une école — utilisée par PermissionsRolesSeeder et
     * PermissionRoleController::reinitialiserDefauts().
     */
    public static function lignesDefaut(int $ecoleId): array
    {
        $lignes = [];

        foreach (self::ROLES as $role) {
            foreach (array_keys(self::MODULES) as $module) {
                $lignes[] = array_merge(
                    ['ecole_id' => $ecoleId, 'role' => $role, 'module' => $module],
                    self::droitsParDefaut($role, $module)
                );
            }
        }

        return $lignes;
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
