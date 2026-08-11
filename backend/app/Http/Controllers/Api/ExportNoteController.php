<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\Eleve;
use App\Models\Matiere;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use App\Services\MoyenneCalculService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ExportNoteController extends Controller
{
    public function __construct(private AnalysePerformanceController $analysePerformance)
    {
    }

    // GET /notes/export/releve/{classeId}/{matiereId}/{periodeId}?format=pdf|excel
    public function releveClasse(Request $request, $classeId, $matiereId, $periodeId)
    {
        $ecoleId = $request->user()->ecole_id;
        $format = $request->input('format', 'pdf');

        $classe = Classe::where('id', $classeId)->where('ecole_id', $ecoleId)->firstOrFail();
        $matiere = Matiere::where('id', $matiereId)->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($periodeId);

        $lignes = $this->lignesReleve($ecoleId, $classe, $matiere, $periode);

        if ($format === 'excel') {
            return $this->releveExcel($classe, $matiere, $periode, $lignes);
        }

        $ecole = $request->user()->ecole;

        $pdf = Pdf::loadView('pdf.releve_notes', [
            'ecole' => [
                'nom' => $ecole->nom,
                'code_ecole' => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'classe' => $classe,
            'matiere' => $matiere,
            'periode' => $periode,
            'lignes' => $lignes,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download("releve_{$classe->nom}_{$matiere->nom}.pdf");
    }

    // GET /notes/export/analyse-performance?periode_id=&format=pdf|excel
    public function analysePerformance(Request $request)
    {
        $data = $request->validate([
            'periode_id' => 'required|integer',
            'format' => 'nullable|in:pdf,excel',
        ]);

        abort_unless(in_array($request->user()->role, ['directeur', 'censeur']), 403,
            'Seuls le directeur ou le censeur peuvent exporter cette analyse.');

        $periode = $this->analysePerformance->periodeEcole($request, $data['periode_id']);
        $format = $data['format'] ?? 'pdf';

        $elevesFaibles = $this->analysePerformance->calculerElevesParSeuil($request, $periode, (float) $request->input('seuil_faible', 8), 'faible');
        $elevesExcellents = $this->analysePerformance->calculerElevesParSeuil($request, $periode, (float) $request->input('seuil_excellent', 16), 'excellent');
        $classementClasses = $this->analysePerformance->calculerClassementClasses($request, $periode);

        if ($format === 'excel') {
            return $this->analysePerformanceExcel($periode, $elevesFaibles, $elevesExcellents, $classementClasses);
        }

        $ecole = $request->user()->ecole;

        $pdf = Pdf::loadView('pdf.analyse_performance', [
            'ecole' => [
                'nom' => $ecole->nom,
                'code_ecole' => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'periode' => $periode,
            'eleves_faibles' => $elevesFaibles,
            'eleves_excellents' => $elevesExcellents,
            'classement_classes' => $classementClasses,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download("analyse_performance_{$periode->nom}.pdf");
    }

    // ── Aides internes ────────────────────────────────────────────

    private function lignesReleve($ecoleId, Classe $classe, Matiere $matiere, PeriodeAcademique $periode)
    {
        $notes = Note::where('classe_id', $classe->id)
            ->where('matiere_id', $matiere->id)
            ->where('periode_id', $periode->id)
            ->get()
            ->groupBy('eleve_id');

        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', fn ($q) => $q
                ->where('classe_id', $classe->id)
                ->where('annee_academique_id', $periode->annee_academique_id))
            ->orderBy('nom')
            ->get();

        return $eleves->map(function (Eleve $eleve) use ($notes) {
            $notesEleve = $notes->get($eleve->id, collect());
            $devoir = $notesEleve->firstWhere('type_evaluation', 'devoir');
            $composition = $notesEleve->firstWhere('type_evaluation', 'composition');

            $moyenne = MoyenneCalculService::moyenneFinale(
                $devoir ? [(float) $devoir->valeur] : [],
                $composition?->valeur
            );

            return [
                'nom' => $eleve->nom,
                'prenom' => $eleve->prenom,
                'matricule' => $eleve->matricule,
                'note_devoir' => $devoir?->valeur !== null ? (float) $devoir->valeur : null,
                'note_composition' => $composition?->valeur !== null ? (float) $composition->valeur : null,
                'moyenne' => $moyenne,
            ];
        });
    }

    private function releveExcel(Classe $classe, Matiere $matiere, PeriodeAcademique $periode, $lignes)
    {
        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Relevé de notes');

        $feuille->fromArray(["Relevé de notes — {$classe->nom} — {$matiere->nom}", $periode->nom], null, 'A1');
        $feuille->fromArray(['Nom', 'Prénom', 'Matricule', 'Devoir', 'Composition', 'Moyenne'], null, 'A3');

        $ligneIndex = 4;
        foreach ($lignes as $ligne) {
            $feuille->fromArray([
                $ligne['nom'],
                $ligne['prenom'],
                $ligne['matricule'],
                $ligne['note_devoir'],
                $ligne['note_composition'],
                $ligne['moyenne'],
            ], null, "A{$ligneIndex}");
            $ligneIndex++;
        }

        return $this->telechargerSpreadsheet($spreadsheet, "releve_{$classe->nom}_{$matiere->nom}.xlsx");
    }

    private function analysePerformanceExcel(PeriodeAcademique $periode, $elevesFaibles, $elevesExcellents, $classementClasses)
    {
        $spreadsheet = new Spreadsheet();

        $feuilleFaibles = $spreadsheet->getActiveSheet();
        $feuilleFaibles->setTitle('Élèves faibles');
        $feuilleFaibles->fromArray(['Nom', 'Prénom', 'Matricule', 'Classe', 'Moyenne générale'], null, 'A1');
        $ligne = 2;
        foreach ($elevesFaibles as $e) {
            $feuilleFaibles->fromArray([$e['nom'], $e['prenom'], $e['matricule'], $e['classe_nom'], $e['moyenne_generale']], null, "A{$ligne}");
            $ligne++;
        }

        $feuilleExcellents = $spreadsheet->createSheet();
        $feuilleExcellents->setTitle('Élèves excellents');
        $feuilleExcellents->fromArray(['Nom', 'Prénom', 'Matricule', 'Classe', 'Moyenne générale'], null, 'A1');
        $ligne = 2;
        foreach ($elevesExcellents as $e) {
            $feuilleExcellents->fromArray([$e['nom'], $e['prenom'], $e['matricule'], $e['classe_nom'], $e['moyenne_generale']], null, "A{$ligne}");
            $ligne++;
        }

        $feuilleClassement = $spreadsheet->createSheet();
        $feuilleClassement->setTitle('Classement classes');
        $feuilleClassement->fromArray(['Classe', "Nombre d'élèves", 'Moyenne classe', 'Taux de réussite (%)'], null, 'A1');
        $ligne = 2;
        foreach ($classementClasses as $c) {
            $feuilleClassement->fromArray([$c['classe_nom'], $c['nombre_eleves'], $c['moyenne_classe'], $c['taux_reussite']], null, "A{$ligne}");
            $ligne++;
        }

        return $this->telechargerSpreadsheet($spreadsheet, "analyse_performance_{$periode->nom}.xlsx");
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
