<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Eleve;
use Illuminate\Http\Request;

class AbsenceController extends Controller
{
    // Liste des absences d'une classe à une date donnée
    public function index(Request $request)
    {
        $request->validate([
            'classe_id'     => 'required|integer',
            'date_absence'  => 'required|date',
        ]);

        $absences = Absence::where('classe_id', $request->classe_id)
            ->where('date_absence', $request->date_absence)
            ->get();

        return response()->json($absences);
    }

    // Enregistrer les absences d'une classe pour une date (par lot)
    public function enregistrer(Request $request)
    {
        $request->validate([
            'classe_id'             => 'required|integer',
            'date_absence'          => 'required|date',
            'absences'              => 'required|array',
            'absences.*.eleve_id'   => 'required|integer',
            'absences.*.motif'      => 'nullable|string',
        ]);

        $marquePar = $request->user()->id;

        // Supprimer les anciennes absences de cette classe/date pour repartir propre
        Absence::where('classe_id', $request->classe_id)
            ->where('date_absence', $request->date_absence)
            ->delete();

        $cree = [];
        foreach ($request->absences as $a) {
            $cree[] = Absence::create([
                'eleve_id'     => $a['eleve_id'],
                'classe_id'    => $request->classe_id,
                'date_absence' => $request->date_absence,
                'motif'        => $a['motif'] ?? null,
                'justifiee'    => false,
                'marque_par'   => $marquePar,
                'notifie'      => false,
            ]);
        }

        return response()->json([
            'message'  => count($cree) . ' absence(s) enregistrée(s)',
            'absences' => $cree,
        ], 201);
    }

    // Marquer une absence comme notifiée (après envoi WhatsApp)
    public function marquerNotifie(Request $request, $id)
    {
        $absence = Absence::findOrFail($id);
        $absence->update(['notifie' => true]);

        return response()->json(['message' => 'Absence marquée comme notifiée']);
    }

    // Marquer une absence comme justifiée
    public function justifier(Request $request, $id)
    {
        $request->validate([
            'motif' => 'required|string',
        ]);

        $absence = Absence::findOrFail($id);
        $absence->update([
            'justifiee' => true,
            'motif'     => $request->motif,
        ]);

        return response()->json(['message' => 'Absence justifiée']);
    }

    // Historique des absences d'un élève
    public function parEleve(Request $request, $eleveId)
    {
        $absences = Absence::where('eleve_id', $eleveId)
            ->orderBy('date_absence', 'desc')
            ->get();

        return response()->json([
            'absences'      => $absences,
            'total'         => $absences->count(),
            'non_justifiees' => $absences->where('justifiee', false)->count(),
        ]);
    }

    // Statistiques absences pour le tableau de bord
    public function statistiques(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $aujourdhui = Absence::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->where('date_absence', now()->format('Y-m-d'))
            ->count();

        $cetteSemaine = Absence::whereHas('eleve', function ($q) use ($ecoleId) {
                $q->where('ecole_id', $ecoleId);
            })
            ->whereBetween('date_absence', [
                now()->startOfWeek()->format('Y-m-d'),
                now()->endOfWeek()->format('Y-m-d'),
            ])
            ->count();

        return response()->json([
            'absents_aujourdhui' => $aujourdhui,
            'absents_semaine'    => $cetteSemaine,
        ]);
    }
}