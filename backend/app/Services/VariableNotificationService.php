<?php

namespace App\Services;

use App\Models\Eleve;
use App\Models\Inscription;
use App\Models\Note;
use App\Models\Paiement;
use App\Models\ParentEleve;
use App\Models\PeriodeAcademique;

/**
 * Extrait et remplace les variables {xxx} d'un modèle/message avec les
 * vraies données d'un élève (classe, parent, moyenne de la période active,
 * dernier paiement, situation financière...).
 */
class VariableNotificationService
{
    public function __construct(private FraisCalculService $fraisCalculService)
    {
    }

    public function extraireVariables(string $contenu): array
    {
        preg_match_all('/\{([a-zA-Z0-9_]+)\}/', $contenu, $matches);

        return array_values(array_unique($matches[1]));
    }

    // $periodeId permet de forcer la période utilisée pour {periode}/{moyenne}
    // (ex: notification de résultats déclenchée pour une période qui n'est
    // plus la période active de l'école). Sans précision, on retombe sur la
    // période active courante.
    public function remplacerVariables(string $contenu, int $eleveId, ?int $periodeId = null): string
    {
        $eleve = Eleve::with('ecole')->findOrFail($eleveId);

        return $this->injecter($contenu, $this->valeursPourEleve($eleve, $periodeId));
    }

    public function genererApercu(string $contenu, int $eleveIdExemple, ?int $periodeId = null): array
    {
        $eleve   = Eleve::with('ecole')->findOrFail($eleveIdExemple);
        $valeurs = $this->valeursPourEleve($eleve, $periodeId);

        return [
            'eleve'               => trim($eleve->prenom . ' ' . $eleve->nom),
            'variables_utilisees' => $this->extraireVariables($contenu),
            'variables_resolues'  => $valeurs,
            'apercu'              => $this->injecter($contenu, $valeurs),
        ];
    }

    private function injecter(string $contenu, array $valeurs): string
    {
        $recherche = array_map(fn($cle) => '{' . $cle . '}', array_keys($valeurs));

        return str_replace($recherche, array_values($valeurs), $contenu);
    }

    // Une variable indisponible pour cet élève retombe sur '—' plutôt que de
    // laisser {variable} brut dans un message envoyé à un parent.
    private function valeursPourEleve(Eleve $eleve, ?int $periodeId = null): array
    {
        $inscription = Inscription::where('eleve_id', $eleve->id)
            ->whereHas('classe')
            ->with('classe.annee')
            ->latest('id')
            ->first();

        $classe = $inscription?->classe;
        $annee  = $classe?->annee;
        $periode = $periodeId ? PeriodeAcademique::find($periodeId) : $annee?->periodeActive();

        $parent = ParentEleve::where('eleve_id', $eleve->id)->first();

        $dernierPaiement = Paiement::where('eleve_id', $eleve->id)
            ->where('statut', 'valide')
            ->latest('date_paiement')
            ->first();

        $moyenne = $periode ? $this->moyenneEleve($eleve->id, $periode->id) : null;

        $situationFinanciere = $annee
            ? $this->fraisCalculService->situationEleve($eleve, $annee->id)
            : null;

        $premierFraisImpaye = $situationFinanciere
            ? collect($situationFinanciere['frais'])->firstWhere('statut', '!=', 'paye')
            : null;

        return [
            'parent'          => $parent
                ? trim($parent->prenom . ' ' . $parent->nom)
                : 'Parent de ' . trim($eleve->prenom . ' ' . $eleve->nom),
            'eleve'           => trim($eleve->prenom . ' ' . $eleve->nom),
            'classe'          => $classe->nom ?? '—',
            'periode'         => $periode->nom ?? '—',
            'moyenne'         => $moyenne !== null ? number_format($moyenne, 2) : '—',
            'mention'         => $moyenne !== null ? $this->mention($moyenne) : '—',
            'montant'         => $dernierPaiement ? number_format((float) $dernierPaiement->montant, 0, ',', ' ') : '—',
            'tranche'         => $dernierPaiement?->echeance?->libelle ?? '—',
            'montant_restant' => $situationFinanciere ? number_format($situationFinanciere['reste_a_payer'], 0, ',', ' ') : '—',
            'date_echeance'   => $premierFraisImpaye?->date_limite?->format('d/m/Y') ?? '—',
            'date'            => now()->format('d/m/Y'),
            'heure'           => now()->format('H:i'),
            'ecole'           => $eleve->ecole->nom ?? '—',
        ];
    }

    // Moyenne pondérée (par coefficient) des notes validées de l'élève pour
    // une période : même règle devoirs/composition que MoyenneCalculService,
    // en s'appuyant directement sur le modèle Note (statut='valide').
    private function moyenneEleve(int $eleveId, int $periodeId): ?float
    {
        $notesParMatiere = Note::where('eleve_id', $eleveId)
            ->where('periode_id', $periodeId)
            ->where('statut', 'valide')
            ->get()
            ->groupBy('matiere_id');

        $totalPoints       = 0.0;
        $totalCoefficients = 0.0;

        foreach ($notesParMatiere as $notesMatiere) {
            $notesDevoirs = $notesMatiere->where('type_evaluation', 'devoir')
                ->pluck('valeur')
                ->map(fn($v) => (float) $v)
                ->all();

            $composition     = $notesMatiere->firstWhere('type_evaluation', 'composition');
            $noteComposition = $composition ? (float) $composition->valeur : null;

            $moyenneFinale = MoyenneCalculService::moyenneFinale($notesDevoirs, $noteComposition);
            $coefficient   = (float) $notesMatiere->first()->coefficient;

            if ($moyenneFinale !== null) {
                $totalPoints       += $moyenneFinale * $coefficient;
                $totalCoefficients += $coefficient;
            }
        }

        return $totalCoefficients > 0 ? round($totalPoints / $totalCoefficients, 2) : null;
    }

    private function mention(float $moyenne): string
    {
        return match (true) {
            $moyenne >= 18 => 'Excellent',
            $moyenne >= 16 => 'Très Bien',
            $moyenne >= 14 => 'Bien',
            $moyenne >= 12 => 'Assez Bien',
            $moyenne >= 10 => 'Passable',
            default        => 'Insuffisant',
        };
    }
}
