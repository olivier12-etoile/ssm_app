<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Classe;
use App\Models\Ecole;
use App\Models\EmploiDuTemps;
use App\Models\Matiere;
use App\Models\User;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;

class EmploiDuTempsController extends Controller
{
    private const JOURS = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi'];

    // Grille horaire fixe de l'établissement (utilisée à l'écran et dans le PDF)
    private const GRILLE_HORAIRE = [
        ['debut' => '07:00', 'fin' => '08:00', 'recreation' => false],
        ['debut' => '08:00', 'fin' => '09:00', 'recreation' => false],
        ['debut' => '09:00', 'fin' => '10:00', 'recreation' => false],
        ['debut' => '10:00', 'fin' => '10:15', 'recreation' => true],
        ['debut' => '10:00', 'fin' => '11:00', 'recreation' => false],
        ['debut' => '11:00', 'fin' => '12:00', 'recreation' => false],
    ];

    // Emploi du temps d'une classe, groupé par jour puis par heure
    public function parClasse(Request $request)
    {
        $request->validate([
            'classe_id' => 'required|integer',
            'annee_id'  => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $creneaux = EmploiDuTemps::where('classe_id', $request->classe_id)
            ->where('annee_academique_id', $request->annee_id)
            ->with(['matiere', 'enseignant'])
            ->orderBy('heure_debut')
            ->get();

        $groupes = collect(self::JOURS)->mapWithKeys(function ($jour) use ($creneaux) {
            $creneauxJour = $creneaux->where('jour', $jour)->values()->map(fn($c) => [
                'id'             => $c->id,
                'heure_debut'    => $c->heure_debut,
                'heure_fin'      => $c->heure_fin,
                'matiere_id'     => $c->matiere_id,
                'matiere_nom'    => $c->matiere->nom,
                'enseignant_id'  => $c->enseignant_id,
                'enseignant_nom' => $c->enseignant->name,
                'salle'          => $c->salle,
            ]);
            return [$jour => $creneauxJour];
        });

        return response()->json($groupes);
    }

    // Emploi du temps d'une classe au format PDF
    public function genererPdfClasse(Request $request)
    {
        $request->validate([
            'classe_id' => 'required|integer',
            'annee_id'  => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $ecole = Ecole::findOrFail($ecoleId);
        $annee = AnneeAcademique::findOrFail($request->annee_id);

        $creneaux = EmploiDuTemps::where('classe_id', $classe->id)
            ->where('annee_academique_id', $request->annee_id)
            ->with(['matiere', 'enseignant'])
            ->orderBy('heure_debut')
            ->get();

        $tableau = [];
        foreach (self::JOURS as $jour) {
            foreach ($creneaux->where('jour', $jour) as $c) {
                $tableau[$jour][substr($c->heure_debut, 0, 5)] = [
                    'matiere_nom'    => $c->matiere->nom,
                    'enseignant_nom' => $c->enseignant->name,
                    'salle'          => $c->salle,
                ];
            }
        }

        $data = [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'classe_nom'    => $classe->nom,
            'annee_libelle' => $annee->libelle,
            'jours'         => self::JOURS,
            'grille'        => self::GRILLE_HORAIRE,
            'tableau'       => $tableau,
            'genere_le'     => now()->format('d/m/Y à H:i'),
        ];

        $pdf = Pdf::loadView('pdf.emploi_du_temps_classe', $data);
        $nomFichier = 'emploi_du_temps_' . str_replace(' ', '_', $classe->nom) . '.pdf';

        return $pdf->download($nomFichier);
    }

    // Emploi du temps d'un enseignant, groupé par jour
    public function parEnseignant(Request $request)
    {
        $request->validate([
            'enseignant_id' => 'required|integer',
            'annee_id'      => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        User::where('id', $request->enseignant_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $creneaux = EmploiDuTemps::where('enseignant_id', $request->enseignant_id)
            ->where('annee_academique_id', $request->annee_id)
            ->with(['classe', 'matiere'])
            ->orderBy('heure_debut')
            ->get();

        $groupes = collect(self::JOURS)->mapWithKeys(function ($jour) use ($creneaux) {
            $creneauxJour = $creneaux->where('jour', $jour)->values()->map(fn($c) => [
                'id'          => $c->id,
                'heure_debut' => $c->heure_debut,
                'heure_fin'   => $c->heure_fin,
                'classe_id'   => $c->classe_id,
                'classe_nom'  => $c->classe->nom,
                'matiere_id'  => $c->matiere_id,
                'matiere_nom' => $c->matiere->nom,
                'salle'       => $c->salle,
            ]);
            return [$jour => $creneauxJour];
        });

        return response()->json($groupes);
    }

    // Emploi du temps d'un enseignant au format PDF (soi-même par défaut, ou un autre enseignant de l'école)
    public function genererPdfEnseignant(Request $request)
    {
        $request->validate([
            'enseignant_id' => 'nullable|integer',
            'annee_id'      => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $enseignant = $request->enseignant_id
            ? User::where('id', $request->enseignant_id)->where('ecole_id', $ecoleId)->firstOrFail()
            : $request->user();

        $ecole = Ecole::findOrFail($ecoleId);
        $annee = AnneeAcademique::findOrFail($request->annee_id);

        $creneaux = EmploiDuTemps::where('enseignant_id', $enseignant->id)
            ->where('annee_academique_id', $request->annee_id)
            ->with(['classe', 'matiere'])
            ->orderBy('heure_debut')
            ->get();

        $tableau = [];
        $minutesParClasse = [];
        foreach (self::JOURS as $jour) {
            foreach ($creneaux->where('jour', $jour) as $c) {
                $tableau[$jour][substr($c->heure_debut, 0, 5)] = [
                    'classe_nom'  => $c->classe->nom,
                    'matiere_nom' => $c->matiere->nom,
                    'salle'       => $c->salle,
                ];

                $duree = $this->dureeEnMinutes($c->heure_debut, $c->heure_fin);
                $minutesParClasse[$c->classe->nom] = ($minutesParClasse[$c->classe->nom] ?? 0) + $duree;
            }
        }

        $heuresParClasse = collect($minutesParClasse)
            ->map(fn($minutes) => round($minutes / 60, 1))
            ->all();

        $data = [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'enseignant_nom'    => $enseignant->name,
            'annee_libelle'     => $annee->libelle,
            'jours'             => self::JOURS,
            'grille'            => self::GRILLE_HORAIRE,
            'tableau'           => $tableau,
            'heures_par_classe' => $heuresParClasse,
            'total_heures'      => round(array_sum($minutesParClasse) / 60, 1),
            'genere_le'         => now()->format('d/m/Y à H:i'),
        ];

        $pdf = Pdf::loadView('pdf.emploi_du_temps_enseignant', $data);
        $nomFichier = 'emploi_du_temps_' . str_replace(' ', '_', $enseignant->name) . '.pdf';

        return $pdf->download($nomFichier);
    }

    private function dureeEnMinutes(string $heureDebut, string $heureFin): int
    {
        [$h1, $m1] = array_map('intval', explode(':', $heureDebut));
        [$h2, $m2] = array_map('intval', explode(':', $heureFin));
        return ($h2 * 60 + $m2) - ($h1 * 60 + $m1);
    }

    // Créer ou modifier un créneau (directeur et censeur uniquement)
    public function enregistrer(Request $request)
    {
        if (!in_array($request->user()->role, ['directeur', 'censeur'])) {
            return response()->json([
                'message' => 'Action réservée au directeur et au censeur',
            ], 403);
        }

        $request->validate([
            'classe_id'           => 'required|integer',
            'annee_academique_id' => 'required|integer',
            'jour'                => 'required|in:' . implode(',', self::JOURS),
            'heure_debut'         => 'required|date_format:H:i',
            'heure_fin'           => 'required|date_format:H:i|after:heure_debut',
            'matiere_id'          => 'required|integer',
            'enseignant_id'       => 'required|integer',
            'salle'               => 'nullable|string|max:191',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        Matiere::where('id', $request->matiere_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        User::where('id', $request->enseignant_id)
            ->where('ecole_id', $ecoleId)
            ->where('role', 'enseignant')
            ->firstOrFail();

        // Créneau existant pour ce triplet (classe, jour, heure_debut) — exclu des vérifications de conflit
        $existant = EmploiDuTemps::where('classe_id', $request->classe_id)
            ->where('annee_academique_id', $request->annee_academique_id)
            ->where('jour', $request->jour)
            ->where('heure_debut', $request->heure_debut)
            ->first();

        $conflitEnseignant = $this->conflitEnseignant(
            $request->enseignant_id,
            $request->annee_academique_id,
            $request->jour,
            $request->heure_debut,
            $request->heure_fin,
            $existant?->id
        );

        if ($conflitEnseignant) {
            return response()->json([
                'message' => "Conflit : l'enseignant est déjà occupé de {$conflitEnseignant->heure_debut} à "
                    . "{$conflitEnseignant->heure_fin} avec la classe {$conflitEnseignant->classe->nom} ce jour-là",
            ], 409);
        }

        $conflitClasse = $this->conflitClasse(
            $request->classe_id,
            $request->annee_academique_id,
            $request->jour,
            $request->heure_debut,
            $request->heure_fin,
            $existant?->id
        );

        if ($conflitClasse) {
            return response()->json([
                'message' => "Conflit : la classe a déjà un cours de {$conflitClasse->heure_debut} à "
                    . "{$conflitClasse->heure_fin} ({$conflitClasse->matiere->nom}) ce jour-là",
            ], 409);
        }

        $creneau = EmploiDuTemps::updateOrCreate(
            [
                'classe_id'           => $request->classe_id,
                'annee_academique_id' => $request->annee_academique_id,
                'jour'                => $request->jour,
                'heure_debut'         => $request->heure_debut,
            ],
            [
                'ecole_id'      => $ecoleId,
                'heure_fin'     => $request->heure_fin,
                'matiere_id'    => $request->matiere_id,
                'enseignant_id' => $request->enseignant_id,
                'salle'         => $request->salle,
            ]
        );

        return response()->json([
            'message' => 'Créneau enregistré avec succès',
            'creneau' => $creneau,
        ], 201);
    }

    // Supprimer un créneau (directeur et censeur uniquement)
    public function supprimer(Request $request, $id)
    {
        if (!in_array($request->user()->role, ['directeur', 'censeur'])) {
            return response()->json([
                'message' => 'Action réservée au directeur et au censeur',
            ], 403);
        }

        $creneau = EmploiDuTemps::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $creneau->delete();

        return response()->json(['message' => 'Créneau supprimé avec succès']);
    }

    // Vérifie si un enseignant est disponible sur un créneau donné
    public function verifierConflits(Request $request)
    {
        $request->validate([
            'enseignant_id'       => 'required|integer',
            'annee_academique_id' => 'required|integer',
            'jour'                => 'required|in:' . implode(',', self::JOURS),
            'heure_debut'         => 'required|date_format:H:i',
            'heure_fin'           => 'required|date_format:H:i|after:heure_debut',
            'exclude_id'          => 'nullable|integer',
        ]);

        $conflit = $this->conflitEnseignant(
            $request->enseignant_id,
            $request->annee_academique_id,
            $request->jour,
            $request->heure_debut,
            $request->heure_fin,
            $request->exclude_id
        );

        if ($conflit) {
            return response()->json([
                'disponible' => false,
                'message'    => "L'enseignant est déjà occupé de {$conflit->heure_debut} à "
                    . "{$conflit->heure_fin} avec la classe {$conflit->classe->nom} ({$conflit->matiere->nom}) ce jour-là",
            ]);
        }

        return response()->json([
            'disponible' => true,
            'message'    => 'Créneau disponible',
        ]);
    }

    // Un même enseignant ne peut pas avoir deux créneaux qui se chevauchent, même dans des classes différentes
    private function conflitEnseignant(
        int $enseignantId,
        int $anneeId,
        string $jour,
        string $heureDebut,
        string $heureFin,
        ?int $excludeId = null
    ) {
        return EmploiDuTemps::where('enseignant_id', $enseignantId)
            ->where('annee_academique_id', $anneeId)
            ->where('jour', $jour)
            ->where('heure_debut', '<', $heureFin)
            ->where('heure_fin', '>', $heureDebut)
            ->when($excludeId, fn($q) => $q->where('id', '!=', $excludeId))
            ->with(['classe', 'matiere'])
            ->first();
    }

    // Une même classe ne peut pas avoir deux cours qui se chevauchent
    private function conflitClasse(
        int $classeId,
        int $anneeId,
        string $jour,
        string $heureDebut,
        string $heureFin,
        ?int $excludeId = null
    ) {
        return EmploiDuTemps::where('classe_id', $classeId)
            ->where('annee_academique_id', $anneeId)
            ->where('jour', $jour)
            ->where('heure_debut', '<', $heureFin)
            ->where('heure_fin', '>', $heureDebut)
            ->when($excludeId, fn($q) => $q->where('id', '!=', $excludeId))
            ->with(['matiere', 'enseignant'])
            ->first();
    }
}
