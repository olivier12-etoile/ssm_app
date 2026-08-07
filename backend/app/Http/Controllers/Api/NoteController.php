<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use Illuminate\Http\Request;

class NoteController extends Controller
{
    // Notes d'une classe pour une période
    public function index(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'periode_id' => 'required|integer',
            'matiere_id' => 'required|integer',
        ]);

        $notes = Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->whereHas('eleve', function ($q) use ($request) {
                $q->whereHas('inscriptions', function ($q2) use ($request) {
                    $q2->where('classe_id', $request->classe_id);
                });
            })
            ->with('eleve')
            ->get();

        return response()->json($notes);
    }

    // Sauvegarder une note (brouillon)
    public function sauvegarder(Request $request)
    {
        $request->validate([
            'eleve_id'   => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
            'valeur'     => 'required|numeric|min:0|max:20',
        ]);

        if ($erreur = $this->verifierPeriodeOuverte($request, $request->periode_id)) {
            return $erreur;
        }

        $note = Note::updateOrCreate(
            [
                'eleve_id'    => $request->eleve_id,
                'matiere_id'  => $request->matiere_id,
                'periode_id'  => $request->periode_id,
            ],
            [
                'enseignant_id' => $request->user()->id,
                'valeur'        => $request->valeur,
                'statut'        => 'brouillon',
            ]
        );

        return response()->json([
            'message' => 'Note sauvegardée',
            'note'    => $note,
        ]);
    }

    // Soumettre les notes (enseignant verrouille)
    public function soumettre(Request $request)
    {
        $request->validate([
            'periode_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'classe_id'  => 'required|integer',
        ]);

        if ($erreur = $this->verifierPeriodeOuverte($request, $request->periode_id)) {
            return $erreur;
        }

        Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->where('enseignant_id', $request->user()->id)
            ->where('statut', 'brouillon')
            ->update(['statut' => 'soumis']);

        return response()->json(['message' => 'Notes soumises pour validation']);
    }

    // Valider les notes (directeur/censeur)
    public function valider(Request $request)
    {
        $request->validate([
            'periode_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'classe_id'  => 'required|integer',
        ]);

        if ($erreur = $this->verifierPeriodeOuverte($request, $request->periode_id)) {
            return $erreur;
        }

        Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->where('statut', 'soumis')
            ->update(['statut' => 'valide']);

        return response()->json(['message' => 'Notes validées']);
    }

    // Rejeter les notes (directeur/censeur)
    public function rejeter(Request $request)
    {
        $request->validate([
            'periode_id'   => 'required|integer',
            'matiere_id'   => 'required|integer',
            'classe_id'    => 'required|integer',
            'motif_rejet'  => 'required|string',
        ]);

        if ($erreur = $this->verifierPeriodeOuverte($request, $request->periode_id)) {
            return $erreur;
        }

        Note::where('periode_id', $request->periode_id)
            ->where('matiere_id', $request->matiere_id)
            ->where('statut', 'soumis')
            ->update([
                'statut'       => 'rejete',
                'motif_rejet'  => $request->motif_rejet,
            ]);

        return response()->json(['message' => 'Notes rejetées']);
    }

    // Vérifie que la période autorise la saisie/validation de notes selon
    // son statut :
    // - preparation   → bloqué pour tout le monde (pas encore ouverte)
    // - ouverte        → OK pour tout le monde
    // - en_veille      → OK pour tout le monde (rattrapage de saisie)
    // - en_validation  → bloqué sauf directeur/censeur/super_admin
    // - cloturee       → bloqué sauf directeur/censeur/super_admin
    // - archivee       → bloqué pour tout le monde
    private function verifierPeriodeOuverte(Request $request, $periodeId)
    {
        $periode = PeriodeAcademique::find($periodeId);

        if (!$periode) {
            return null;
        }

        $role = $request->user()->role;
        $estGestionnaire = in_array($role, ['directeur', 'censeur', 'super_admin']);

        $messages = [
            'preparation'   => "Cette période n'est pas encore ouverte.",
            'en_validation' => "Cette période est en validation. Vous pouvez consulter vos données mais pas les modifier.",
            'cloturee'      => "Cette période est clôturée. Vous pouvez consulter vos données mais pas les modifier.",
            'archivee'      => "Cette période est archivée et n'est plus modifiable.",
        ];

        if ($periode->statut === 'archivee') {
            return response()->json([
                'message'       => $messages['archivee'],
                'lecture_seule' => true,
            ], 403);
        }

        if (in_array($periode->statut, ['preparation']) || (in_array($periode->statut, ['en_validation', 'cloturee']) && !$estGestionnaire)) {
            return response()->json([
                'message'       => $messages[$periode->statut],
                'lecture_seule' => true,
            ], 403);
        }

        return null;
    }
}