<?php

namespace Database\Seeders;

use App\Models\Ecole;
use App\Models\ModeleMessage;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class ModeleMessageSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $ecole = Ecole::where('code_ecole', '4DTI5X')->firstOrFail();

        $modeles = [
            [
                'nom' => 'Bulletin disponible',
                'categorie' => 'scolarite',
                'contenu' => "Bonjour {parent},\n\n"
                    . "Le bulletin de {periode} de {eleve} ({classe}) est disponible.\n\n"
                    . "Moyenne : {moyenne}/20\n"
                    . "Mention : {mention}\n\n"
                    . "{ecole}",
                'variables_disponibles' => ['parent', 'eleve', 'classe', 'periode', 'moyenne', 'mention', 'ecole'],
            ],
            [
                'nom' => 'Résultats disponibles',
                'categorie' => 'scolarite',
                'contenu' => "Bonjour {parent},\n\n"
                    . "Les résultats de {periode} de {eleve} ({classe}) sont maintenant disponibles.\n\n"
                    . "Moyenne générale : {moyenne}/20\n\n"
                    . "{ecole}",
                'variables_disponibles' => ['parent', 'eleve', 'classe', 'periode', 'moyenne', 'ecole'],
            ],
            [
                'nom' => 'Paiement reçu',
                'categorie' => 'finances',
                'contenu' => "Bonjour {parent},\n\n"
                    . "Nous confirmons la réception du paiement de {montant} FCFA ({tranche}) pour {eleve}.\n"
                    . "Reste à payer : {montant_restant} FCFA.\n\n"
                    . "Merci pour votre confiance.\n\n"
                    . "{ecole}",
                'variables_disponibles' => ['parent', 'eleve', 'montant', 'tranche', 'montant_restant', 'ecole'],
            ],
            [
                'nom' => 'Rappel d\'impayé',
                'categorie' => 'finances',
                'contenu' => "Bonjour {parent},\n\n"
                    . "{eleve} ({classe}) présente un solde impayé de {montant_restant} FCFA, "
                    . "échéance le {date_echeance}.\n\n"
                    . "Merci de régulariser la situation auprès de l'administration.\n\n"
                    . "{ecole}",
                'variables_disponibles' => ['parent', 'eleve', 'classe', 'montant_restant', 'date_echeance', 'ecole'],
            ],
            [
                'nom' => 'Absence signalée',
                'categorie' => 'presence',
                'contenu' => "Bonjour {parent},\n\n"
                    . "Votre enfant {eleve} ({classe}) a été marqué absent le {date} à {heure}.\n\n"
                    . "Merci de justifier cette absence auprès de l'administration.\n\n"
                    . "{ecole}",
                'variables_disponibles' => ['parent', 'eleve', 'classe', 'date', 'heure', 'ecole'],
            ],
        ];

        foreach ($modeles as $modele) {
            ModeleMessage::firstOrCreate(
                [
                    'ecole_id' => $ecole->id,
                    'nom' => $modele['nom'],
                ],
                [
                    'categorie' => $modele['categorie'],
                    'contenu' => $modele['contenu'],
                    'variables_disponibles' => $modele['variables_disponibles'],
                    'actif' => true,
                    'modifiable' => false,
                ]
            );
        }
    }
}
