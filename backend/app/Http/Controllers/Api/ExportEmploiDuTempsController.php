<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\CreneauHoraire;
use App\Models\EmploiDuTemps;
use App\Models\JourTravaille;
use App\Models\PeriodeAcademique;
use App\Models\Seance;
use App\Models\User;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ExportEmploiDuTempsController extends Controller
{
    private const JOURS_SEMAINE = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];

    // GET /emploi-du-temps/export/classe/{classeId}/pdf?periode_id=
    public function exportClassePdf(Request $request, $classeId)
    {
        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $classeId)->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = $this->periodeEcole($request, $ecoleId);

        $emploiDuTemps = EmploiDuTemps::where('classe_id', $classe->id)
            ->where('periode_id', $periode->id)
            ->first();

        if (!$emploiDuTemps) {
            return response()->json([
                'message' => "Aucun emploi du temps n'a encore été créé pour cette classe sur cette période.",
            ], 404);
        }

        $seances = $emploiDuTemps->seances()
            ->with(['creneauHoraire', 'matiere:id,nom,couleur', 'enseignant:id,name'])
            ->get();

        [$jours, $grille] = $this->grilleReference($periode->annee_academique_id);

        $tableau = [];
        foreach ($seances as $seance) {
            $tableau[$seance->jour][$seance->creneauHoraire->heure_debut->format('H:i')] = [
                'matiere_nom' => $seance->matiere->nom,
                'enseignant_nom' => $seance->enseignant->name,
                'salle' => $seance->salle,
                'couleur' => $seance->couleur ?? $seance->matiere->couleur,
            ];
        }

        $pdf = Pdf::loadView('pdf.emploi_du_temps_classe', [
            'ecole' => $this->ecoleInfos($request),
            'classe_nom' => $classe->nom,
            'annee_libelle' => $periode->annee->libelle,
            'jours' => $jours,
            'grille' => $grille,
            'tableau' => $tableau,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ])->setPaper('a4', 'landscape');

        return $pdf->download("emploi_du_temps_{$classe->nom}.pdf");
    }

    // GET /emploi-du-temps/export/classe/{classeId}/excel?periode_id=
    public function exportClasseExcel(Request $request, $classeId)
    {
        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $classeId)->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = $this->periodeEcole($request, $ecoleId);

        $emploiDuTemps = EmploiDuTemps::where('classe_id', $classe->id)
            ->where('periode_id', $periode->id)
            ->first();

        if (!$emploiDuTemps) {
            return response()->json([
                'message' => "Aucun emploi du temps n'a encore été créé pour cette classe sur cette période.",
            ], 404);
        }

        $seances = $emploiDuTemps->seances()
            ->with(['creneauHoraire', 'matiere:id,nom', 'enseignant:id,name'])
            ->get();

        [$jours, $grille] = $this->grilleReference($periode->annee_academique_id);

        $tableau = [];
        foreach ($seances as $seance) {
            $tableau[$seance->jour][$seance->creneauHoraire->heure_debut->format('H:i')] =
                "{$seance->matiere->nom} — {$seance->enseignant->name}" . ($seance->salle ? " ({$seance->salle})" : '');
        }

        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Emploi du temps');

        $feuille->fromArray(["Emploi du temps — {$classe->nom} — {$periode->annee->libelle}"], null, 'A1');
        $feuille->fromArray(array_merge(['Horaire'], array_map('ucfirst', $jours)), null, 'A3');

        $ligneIndex = 4;
        foreach ($grille as $row) {
            if ($row['recreation']) {
                $feuille->fromArray(["Récréation {$row['debut']} - {$row['fin']}"], null, "A{$ligneIndex}");
                $ligneIndex++;
                continue;
            }

            $ligne = ["{$row['debut']} - {$row['fin']}"];
            foreach ($jours as $jour) {
                $ligne[] = $tableau[$jour][$row['debut']] ?? '';
            }
            $feuille->fromArray($ligne, null, "A{$ligneIndex}");
            $ligneIndex++;
        }

        return $this->telechargerSpreadsheet($spreadsheet, "emploi_du_temps_{$classe->nom}.xlsx");
    }

    // GET /emploi-du-temps/export/enseignant/{enseignantId}/pdf?periode_id=
    public function exportEnseignantPdf(Request $request, $enseignantId)
    {
        $ecoleId = $request->user()->ecole_id;

        $enseignant = User::where('id', $enseignantId)
            ->where('ecole_id', $ecoleId)
            ->where('role', 'enseignant')
            ->firstOrFail();

        $periode = $this->periodeEcole($request, $ecoleId);

        $seances = Seance::where('enseignant_id', $enseignant->id)
            ->whereHas('emploiDuTemps', fn ($q) => $q->where('periode_id', $periode->id))
            ->with(['creneauHoraire', 'matiere:id,nom,couleur', 'emploiDuTemps.classe:id,nom'])
            ->get();

        [$jours, $grille] = $this->grilleReference($periode->annee_academique_id);

        $tableau = [];
        foreach ($seances as $seance) {
            $tableau[$seance->jour][$seance->creneauHoraire->heure_debut->format('H:i')] = [
                'matiere_nom' => $seance->matiere->nom,
                'classe_nom' => $seance->emploiDuTemps->classe->nom,
                'salle' => $seance->salle,
                'couleur' => $seance->couleur ?? $seance->matiere->couleur,
            ];
        }

        $seancesDeCours = $seances->filter(fn (Seance $s) => $s->creneauHoraire?->type === 'cours');

        $totalHeures = round($seancesDeCours->sum(function (Seance $s) {
            return $s->creneauHoraire->heure_fin->diffInMinutes($s->creneauHoraire->heure_debut, true);
        }) / 60, 2);

        $heuresParClasse = $seancesDeCours
            ->groupBy(fn (Seance $s) => $s->emploiDuTemps->classe->nom)
            ->map(function ($seancesClasse) {
                return round($seancesClasse->sum(function (Seance $s) {
                    return $s->creneauHoraire->heure_fin->diffInMinutes($s->creneauHoraire->heure_debut, true);
                }) / 60, 2);
            });

        $pdf = Pdf::loadView('pdf.emploi_du_temps_enseignant', [
            'ecole' => $this->ecoleInfos($request),
            'enseignant_nom' => $enseignant->name,
            'annee_libelle' => $periode->annee->libelle,
            'jours' => $jours,
            'grille' => $grille,
            'tableau' => $tableau,
            'total_heures' => $totalHeures,
            'heures_par_classe' => $heuresParClasse,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ])->setPaper('a4', 'landscape');

        return $pdf->download("emploi_du_temps_{$enseignant->name}.pdf");
    }

    // ── Aides internes ────────────────────────────────────────────

    private function periodeEcole(Request $request, int $ecoleId): PeriodeAcademique
    {
        return PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->with('annee:id,libelle')
            ->findOrFail($request->integer('periode_id'));
    }

    private function ecoleInfos(Request $request): array
    {
        $ecole = $request->user()->ecole;

        return [
            'nom' => $ecole->nom,
            'code_ecole' => $ecole->code_ecole,
            'couleur_primaire' => $ecole->couleur_primaire,
        ];
    }

    // Jours travaillés actifs (ordonnés) et grille horaire (créneaux de cours
    // + récréations/pauses) de référence pour l'année scolaire, communes aux
    // exports classe et enseignant.
    private function grilleReference(int $anneeScolaireId): array
    {
        $joursActifs = JourTravaille::where('annee_scolaire_id', $anneeScolaireId)
            ->where('actif', true)
            ->pluck('jour');

        $jours = collect(self::JOURS_SEMAINE)->filter(fn ($j) => $joursActifs->contains($j))->values()->all();

        $grille = CreneauHoraire::where('annee_scolaire_id', $anneeScolaireId)
            ->orderBy('ordre')
            ->get()
            ->map(fn (CreneauHoraire $c) => [
                'debut' => $c->heure_debut->format('H:i'),
                'fin' => $c->heure_fin->format('H:i'),
                'recreation' => $c->type === 'recreation',
            ])
            ->all();

        return [$jours, $grille];
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
