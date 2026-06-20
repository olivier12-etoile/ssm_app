<?php

namespace App\Services;

class MessageTemplateService
{
    public static function absence(string $nomEleve, string $classe, string $heure, string $nomEcole): string
    {
        return "Bonjour,\n\n"
            . "Votre enfant {$nomEleve} ({$classe}) a été marqué absent ce jour à {$heure}.\n\n"
            . "Merci de justifier cette absence auprès de l'administration.\n\n"
            . "{$nomEcole}";
    }

    public static function paiement(string $nomEleve, string $montant, string $tranche, string $nomEcole): string
    {
        return "Bonjour,\n\n"
            . "Nous confirmons la réception du paiement de {$montant} FCFA ({$tranche}) "
            . "pour {$nomEleve}.\n\n"
            . "Merci pour votre confiance.\n\n"
            . "{$nomEcole}";
    }

    public static function bulletin(string $nomEleve, string $periode, string $moyenne, string $mention, string $nomEcole): string
    {
        return "Bonjour,\n\n"
            . "Le bulletin de {$periode} de votre enfant {$nomEleve} est disponible.\n\n"
            . "Moyenne : {$moyenne}/20\n"
            . "Mention : {$mention}\n\n"
            . "{$nomEcole}";
    }
}