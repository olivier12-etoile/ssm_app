<?php

namespace App\Services;

class MoyenneCalculService
{
    // moyenne_finale = (moyenne_devoirs + note_composition) / 2, avec repli si l'un des deux manque
    public static function moyenneFinale(array $notesDevoirs, $noteComposition): ?float
    {
        $moyenneDevoirs = self::moyenneDevoirs($notesDevoirs);

        if ($moyenneDevoirs !== null && $noteComposition !== null) {
            return round(($moyenneDevoirs + (float) $noteComposition) / 2, 2);
        }

        if ($moyenneDevoirs !== null) {
            return $moyenneDevoirs;
        }

        if ($noteComposition !== null) {
            return round((float) $noteComposition, 2);
        }

        return null;
    }

    public static function moyenneDevoirs(array $notesDevoirs): ?float
    {
        if (count($notesDevoirs) === 0) {
            return null;
        }

        return round(array_sum($notesDevoirs) / count($notesDevoirs), 2);
    }
}
