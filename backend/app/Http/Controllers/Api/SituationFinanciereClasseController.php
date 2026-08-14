<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Classe;
use App\Services\SituationFinanciereClasseService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class SituationFinanciereClasseController extends Controller
{
    public function __construct(private SituationFinanciereClasseService $situationClasse)
    {
    }

    // GET /paiements/situation-classe/{classeId}
    public function parClasse(Request $request, $classeId)
    {
        $classe = $this->classeEcole($request, $classeId);

        return response()->json($this->situationClasse->parClasse($classe->id, $classe->annee_academique_id));
    }

    // GET /paiements/situation-classe
    public function toutesLesClasses(Request $request)
    {
        $annee = $this->anneeCiblee($request);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active. Précisez annee_scolaire_id.'], 422);
        }

        return response()->json($this->situationClasse->toutesLesClasses($annee->id));
    }

    // GET /paiements/situation-classe/{classeId}/impayes
    public function impayes(Request $request, $classeId)
    {
        $classe = $this->classeEcole($request, $classeId);

        return response()->json($this->situationClasse->impayesParClasse($classe->id));
    }

    // GET /paiements/situation-classe/{classeId}/export-pdf
    public function exportClassePdf(Request $request, $classeId)
    {
        $classe = $this->classeEcole($request, $classeId);
        $situation = $this->situationClasse->parClasse($classe->id, $classe->annee_academique_id);

        $pdf = Pdf::loadView('pdf.situation_classe', [
            'ecole'     => $this->entierEcole($request->user()->ecole),
            'situation' => $situation,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('situation_' . str_replace(' ', '_', $classe->nom) . '.pdf');
    }

    // GET /paiements/situation-classe/{classeId}/export-excel
    public function exportClasseExcel(Request $request, $classeId)
    {
        $classe = $this->classeEcole($request, $classeId);
        $situation = $this->situationClasse->parClasse($classe->id, $classe->annee_academique_id);

        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Situation classe');
        $this->ecrireLigneSituation($feuille, $situation);

        return $this->telechargerSpreadsheet($spreadsheet, 'situation_' . str_replace(' ', '_', $classe->nom) . '.xlsx');
    }

    // GET /paiements/situation-classe/export-pdf
    public function exportToutesClassesPdf(Request $request)
    {
        $annee = $this->anneeCiblee($request);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active. Précisez annee_scolaire_id.'], 422);
        }

        $situations = $this->situationClasse->toutesLesClasses($annee->id);

        $pdf = Pdf::loadView('pdf.situation_toutes_classes', [
            'ecole'      => $this->entierEcole($request->user()->ecole),
            'annee'      => $annee->libelle,
            'situations' => $situations,
            'genere_le'  => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('situation_toutes_classes.pdf');
    }

    // GET /paiements/situation-classe/export-excel
    public function exportToutesClassesExcel(Request $request)
    {
        $annee = $this->anneeCiblee($request);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active. Précisez annee_scolaire_id.'], 422);
        }

        $situations = $this->situationClasse->toutesLesClasses($annee->id);

        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Situation toutes classes');
        $feuille->fromArray(['Classe', 'Effectif', 'En règle', 'Partiel', 'Non réglé', 'En retard', 'Attendu', 'Encaissé', 'Reste', 'Taux (%)'], null, 'A1');

        $ligne = 2;
        foreach ($situations as $s) {
            $feuille->fromArray([
                $s['classe_nom'], $s['nombre_eleves'], $s['nombre_en_regle'], $s['nombre_partiel'],
                $s['nombre_non_regle'], $s['nombre_en_retard'], $s['montant_attendu'],
                $s['montant_encaisse'], $s['reste_a_recouvrer'], $s['taux_recouvrement'],
            ], null, "A{$ligne}");
            $ligne++;
        }

        return $this->telechargerSpreadsheet($spreadsheet, 'situation_toutes_classes.xlsx');
    }

    // ── Aides internes ────────────────────────────────────────────

    private function classeEcole(Request $request, $classeId): Classe
    {
        return Classe::where('id', $classeId)->where('ecole_id', $request->user()->ecole_id)->firstOrFail();
    }

    private function anneeCiblee(Request $request): ?AnneeAcademique
    {
        $ecoleId = $request->user()->ecole_id;

        return $request->filled('annee_scolaire_id')
            ? AnneeAcademique::where('ecole_id', $ecoleId)->find((int) $request->annee_scolaire_id)
            : AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();
    }

    private function entierEcole($ecole): array
    {
        return [
            'nom'              => $ecole->nom,
            'code_ecole'       => $ecole->code_ecole,
            'couleur_primaire' => $ecole->couleur_primaire,
        ];
    }

    private function ecrireLigneSituation($feuille, array $s): void
    {
        $lignes = [
            ['Classe', $s['classe_nom']],
            ['Effectif', $s['nombre_eleves']],
            ['En règle', $s['nombre_en_regle']],
            ['Partiel', $s['nombre_partiel']],
            ['Non réglé', $s['nombre_non_regle']],
            ['En retard', $s['nombre_en_retard']],
            ['Montant attendu', $s['montant_attendu']],
            ['Montant encaissé', $s['montant_encaisse']],
            ['Reste à recouvrer', $s['reste_a_recouvrer']],
            ['Taux de recouvrement (%)', $s['taux_recouvrement']],
        ];

        foreach ($lignes as $index => $ligne) {
            $feuille->fromArray($ligne, null, 'A' . ($index + 1));
        }
    }

    private function telechargerSpreadsheet(Spreadsheet $spreadsheet, string $nomFichier)
    {
        $dossierTemp = storage_path('app/tmp');
        if (!is_dir($dossierTemp)) {
            mkdir($dossierTemp, 0755, true);
        }
        $cheminTemp = $dossierTemp . '/' . $nomFichier;

        (new Xlsx($spreadsheet))->save($cheminTemp);

        return response()->download($cheminTemp, $nomFichier)->deleteFileAfterSend(true);
    }
}
