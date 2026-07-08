<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Eleve;
use App\Models\Note;
use App\Models\Inscription;
use App\Models\PeriodeAcademique;
use App\Models\ClasseMatiere;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Barryvdh\DomPDF\Facade\Pdf;
use App\Models\NotificationAttente;
use App\Services\MessageTemplateService;
use App\Models\AppreciationBulletin;

class BulletinController extends Controller
{
    public function generer(Request $request)
    {
        $request->validate([
            'eleve_id'   => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId  = $request->user()->ecole_id;
        $eleveId  = $request->eleve_id;
        $periodeId = $request->periode_id;

        // Récupérer l'élève
        $eleve = Eleve::where('id', $eleveId)
            ->where('ecole_id', $ecoleId)
            ->with('ecole')
            ->firstOrFail();

        // Récupérer la période
        $periode = PeriodeAcademique::with('annee')
            ->findOrFail($periodeId);

        // Récupérer l'inscription
        $inscription = Inscription::where('eleve_id', $eleveId)
            ->where('annee_academique_id', $periode->annee->id)
            ->with('classe')
            ->first();

        // Récupérer les notes validées
        $notes = Note::where('eleve_id', $eleveId)
            ->where('periode_id', $periodeId)
            ->where('statut', 'valide')
            ->with('matiere')
            ->get();

        // Calculer les moyennes
        $classeId         = $inscription?->classe?->id;
        $totalPoints      = 0;
        $totalCoefficients = 0;
        $lignesNotes      = [];

        foreach ($notes as $note) {
            $coef = $this->coefficientPourClasse($classeId, $note->matiere_id, $note->matiere->coefficient);
            $totalPoints    += $note->valeur * $coef;
            $totalCoefficients += $coef;

            $lignesNotes[] = [
                'matiere'      => $note->matiere->nom,
                'coefficient'  => $coef,
                'note'         => $note->valeur,
                'points'       => round($note->valeur * $coef, 2),
                'mention'      => $this->mention($note->valeur),
            ];
        }

        $moyenneGenerale = $totalCoefficients > 0
            ? round($totalPoints / $totalCoefficients, 2)
            : 0;

        // Récupérer l'appréciation existante
        $appreciation = AppreciationBulletin::where('eleve_id', $eleveId)
            ->where('periode_id', $periodeId)
            ->first();

        return response()->json([
            'eleve' => [
                'id'       => $eleve->id,
                'nom'      => $eleve->nom,
                'prenom'   => $eleve->prenom,
                'matricule' => $eleve->matricule,
                'sexe'     => $eleve->sexe,
            ],
            'classe'  => $inscription?->classe?->nom ?? 'Non définie',
            'periode' => [
                'nom'        => $periode->nom,
                'date_debut' => $periode->date_debut,
                'date_fin'   => $periode->date_fin,
            ],
            'annee'           => $periode->annee->libelle,
            'ecole'           => [
                'nom'              => $eleve->ecole->nom,
                'code_ecole'       => $eleve->ecole->code_ecole,
                'couleur_primaire' => $eleve->ecole->couleur_primaire,
                'telephone'        => $eleve->ecole->telephone,
                'adresse'          => $eleve->ecole->adresse,
            ],
            'notes'                   => $lignesNotes,
            'moyenne_generale'        => $moyenneGenerale,
            'mention_generale'        => $this->mention($moyenneGenerale),
            'total_matieres'          => count($lignesNotes),
            'appreciation_enseignant' => $appreciation?->appreciation_enseignant,
            'appreciation_directeur'  => $appreciation?->appreciation_directeur,
            'observation'             => $appreciation?->observation,
        ]);
    }

    // Bulletins d'une classe entière
    public function parClasse(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId   = $request->user()->ecole_id;
        $classeId  = $request->classe_id;
        $periodeId = $request->periode_id;

        $periode = PeriodeAcademique::with('annee')->findOrFail($periodeId);

        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', function ($q) use ($classeId, $periode) {
                $q->where('classe_id', $classeId)
                  ->where('annee_academique_id', $periode->annee->id);
            })
            ->orderBy('nom')
            ->get();

        $bulletins = [];

        foreach ($eleves as $eleve) {
            $notes = Note::where('eleve_id', $eleve->id)
                ->where('periode_id', $periodeId)
                ->where('statut', 'valide')
                ->with('matiere')
                ->get();

            $totalPoints       = 0;
            $totalCoefficients = 0;

            foreach ($notes as $note) {
                $coef               = $note->matiere->coefficient;
                $totalPoints        += $note->valeur * $coef;
                $totalCoefficients  += $coef;
            }

            $moyenne = $totalCoefficients > 0
                ? round($totalPoints / $totalCoefficients, 2)
                : 0;

            $bulletins[] = [
                'eleve_id'  => $eleve->id,
                'nom'       => $eleve->nom,
                'prenom'    => $eleve->prenom,
                'matricule' => $eleve->matricule,
                'moyenne'   => $moyenne,
                'mention'   => $this->mention($moyenne),
            ];
        }

        // Trier par moyenne décroissante et ajouter le rang
        usort($bulletins, fn($a, $b) => $b['moyenne'] <=> $a['moyenne']);
        foreach ($bulletins as $i => &$b) {
            $b['rang'] = $i + 1;
        }

        return response()->json([
            'classe_id'  => $classeId,
            'periode'    => $periode->nom,
            'bulletins'  => $bulletins,
        ]);
    }

    // Coefficient spécifique à la classe, avec repli sur le coefficient général de la matière
    private function coefficientPourClasse(?int $classeId, int $matiereId, float $coefficientDefaut): float
    {
        if (!$classeId) {
            return $coefficientDefaut;
        }

        $classeMatiere = ClasseMatiere::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->first();

        return $classeMatiere?->coefficient ?? $coefficientDefaut;
    }

    private function mention(float $note): string
    {
        if ($note >= 18) return 'Excellent';
        if ($note >= 16) return 'Très Bien';
        if ($note >= 14) return 'Bien';
        if ($note >= 12) return 'Assez Bien';
        if ($note >= 10) return 'Passable';
        return 'Insuffisant';
    }

    public function genererPdf(Request $request)
    {
        $request->validate([
            'eleve_id'   => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        // Réutilise la logique de generer() pour calculer les données
        $ecoleId   = $request->user()->ecole_id;
        $eleveId   = $request->eleve_id;
        $periodeId = $request->periode_id;

        $eleve = Eleve::where('id', $eleveId)
            ->where('ecole_id', $ecoleId)
            ->with('ecole')
            ->firstOrFail();

        $periode = PeriodeAcademique::with('annee')->findOrFail($periodeId);

        $inscription = Inscription::where('eleve_id', $eleveId)
            ->where('annee_academique_id', $periode->annee->id)
            ->with('classe')
            ->first();

        $notes = Note::where('eleve_id', $eleveId)
            ->where('periode_id', $periodeId)
            ->where('statut', 'valide')
            ->with('matiere')
            ->get();

        $classeId          = $inscription?->classe?->id;
        $totalPoints       = 0;
        $totalCoefficients = 0;
        $lignesNotes       = [];

        foreach ($notes as $note) {
            $coef = $this->coefficientPourClasse($classeId, $note->matiere_id, $note->matiere->coefficient);
            $totalPoints        += $note->valeur * $coef;
            $totalCoefficients  += $coef;

            $lignesNotes[] = [
                'matiere'     => $note->matiere->nom,
                'coefficient' => $coef,
                'note'        => $note->valeur,
                'points'      => round($note->valeur * $coef, 2),
                'mention'     => $this->mention($note->valeur),
            ];
        }

        $moyenneGenerale = $totalCoefficients > 0
            ? round($totalPoints / $totalCoefficients, 2)
            : 0;

        // Récupérer l'appréciation existante
        $appreciation = AppreciationBulletin::where('eleve_id', $eleveId)
            ->where('periode_id', $periodeId)
            ->first();

        $data = [
            'eleve'  => [
                'id'        => $eleve->id,
                'nom'       => $eleve->nom,
                'prenom'    => $eleve->prenom,
                'matricule' => $eleve->matricule,
                'sexe'      => $eleve->sexe,
            ],
            'classe'           => $inscription?->classe?->nom ?? 'Non définie',
            'periode'          => ['nom' => $periode->nom],
            'annee'            => $periode->annee->libelle,
            'ecole'            => [
                'nom'              => $eleve->ecole->nom,
                'code_ecole'       => $eleve->ecole->code_ecole,
                'couleur_primaire' => $eleve->ecole->couleur_primaire,
                'telephone'        => $eleve->ecole->telephone,
                'adresse'          => $eleve->ecole->adresse,
            ],
            'notes'                    => $lignesNotes,
            'moyenne_generale'         => $moyenneGenerale,
            'mention_generale'         => $this->mention($moyenneGenerale),
            'total_matieres'           => count($lignesNotes),
            'appreciation_enseignant'  => $appreciation?->appreciation_enseignant,
            'appreciation_directeur'   => $appreciation?->appreciation_directeur,
            'observation'              => $appreciation?->observation,
            'genere_le'                => now()->format('d/m/Y à H:i'),
        ];

        $pdf = Pdf::loadView('pdf.bulletin', $data);
        $nomFichier = 'bulletin_' . str_replace(' ', '_', $eleve->nom . '_' . $eleve->prenom) . '.pdf';

        return $pdf->download($nomFichier);
    }

    // Créer une notification en attente pour un bulletin (appelé manuellement depuis Flutter)
    public function notifierBulletin(Request $request)
    {
        $request->validate([
            'eleve_id'   => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $eleve = Eleve::with('ecole')
            ->where('id', $request->eleve_id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $periode = PeriodeAcademique::findOrFail($request->periode_id);

        $notes = Note::where('eleve_id', $eleve->id)
            ->where('periode_id', $periode->id)
            ->where('statut', 'valide')
            ->with('matiere')
            ->get();

        $totalPoints       = 0;
        $totalCoefficients = 0;
        foreach ($notes as $note) {
            $coef = $note->matiere->coefficient;
            $totalPoints       += $note->valeur * $coef;
            $totalCoefficients += $coef;
        }
        $moyenne = $totalCoefficients > 0 ? round($totalPoints / $totalCoefficients, 2) : 0;
        $mention = $this->mention($moyenne);

        if (!$eleve->telephone_parent) {
            return response()->json(['message' => 'Aucun numéro de téléphone parent enregistré'], 422);
        }

        $message = MessageTemplateService::bulletin(
            $eleve->nom . ' ' . $eleve->prenom,
            $periode->nom,
            $moyenne,
            $mention,
            $eleve->ecole->nom ?? ''
        );

        NotificationAttente::create([
            'ecole_id'         => $request->user()->ecole_id,
            'eleve_id'         => $eleve->id,
            'type'             => 'bulletin',
            'telephone_parent' => $eleve->telephone_parent,
            'message'          => $message,
            'statut'           => 'en_attente',
        ]);

        return response()->json(['message' => 'Notification ajoutée à la file d\'attente']);
    }
}