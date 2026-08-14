<?php

namespace App\Helpers;

use App\Models\Ecole;

/**
 * Point d'entrée unique pour la marque blanche (logos, couleurs, cachet,
 * signature) d'une école, utilisé par les modules qui génèrent des PDF
 * (Frais Scolaires, Notes & Évaluations, ...). Ces modules construisaient
 * jusqu'ici leur propre tableau 'ecole' à la main (voir BulletinController,
 * RapportPaiementService) : les clés renvoyées ici sont volontairement les
 * mêmes (couleur_primaire, telephone, adresse, ...) pour pouvoir remplacer
 * ce code dupliqué par un simple array_merge(IdentiteEcoleHelper::getIdentiteEcole($ecoleId), [...]).
 */
class IdentiteEcoleHelper
{
    public static function getIdentiteEcole(int $ecoleId): array
    {
        $ecole = Ecole::find($ecoleId);

        if (!$ecole) {
            return [];
        }

        return [
            'nom'                     => $ecole->nom,
            'nom_court'               => $ecole->nom_court,
            'sigle'                   => $ecole->sigle,
            'code_ecole'              => $ecole->code_ecole,
            'devise'                  => $ecole->devise,
            'telephone'               => $ecole->telephone,
            'email'                   => $ecole->email,
            'adresse'                 => $ecole->adresse,
            'ville'                   => $ecole->ville,

            'logo'                    => $ecole->logo_principal_url,
            'logo_secondaire'         => $ecole->logo_secondaire_url,
            'cachet'                  => $ecole->cachet_numerique_url,
            'signature_directeur'     => $ecole->signature_directeur_url,

            'couleur_primaire'        => $ecole->couleur_primaire,
            'couleur_secondaire'      => $ecole->couleur_secondaire,
            'couleur_boutons'         => $ecole->couleur_boutons ?: $ecole->couleur_primaire,
            'couleur_entetes'         => $ecole->couleur_entetes ?: $ecole->couleur_primaire,

            'directeur_nom'           => trim(($ecole->directeur_prenom ?? '') . ' ' . ($ecole->directeur_nom ?? '')),
            'directeur_fonction'      => $ecole->directeur_fonction,
        ];
    }
}
