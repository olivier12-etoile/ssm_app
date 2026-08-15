<?php

namespace App\Services;

use App\Helpers\IdentiteEcoleHelper;
use App\Models\Bulletin;
use App\Models\ParametreBulletin;
use Barryvdh\DomPDF\Facade\Pdf;
use RuntimeException;
use ZipArchive;

class PdfBulletinService
{
    public function genererPdf(int $bulletinId)
    {
        $bulletin = $this->chargerBulletin($bulletinId);

        return Pdf::loadView('pdf.bulletin', $this->donneesBulletin($bulletin));
    }

    // Génère un ZIP (via ZipArchive natif) contenant le PDF de chaque
    // bulletin déjà généré pour la classe/période, et retourne le chemin
    // du fichier temporaire créé (storage/app/tmp, comme les autres exports
    // ZIP/Excel de l'application -- voir ExportNoteController par exemple).
    public function genererPdfClasse(int $classeId, int $periodeId): string
    {
        $bulletins = Bulletin::where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->with('eleve')
            ->orderBy('rang')
            ->get();

        if ($bulletins->isEmpty()) {
            throw new RuntimeException('Aucun bulletin généré pour cette classe et cette période.');
        }

        $dossierTemp = storage_path('app/tmp');
        if (!is_dir($dossierTemp)) {
            mkdir($dossierTemp, 0755, true);
        }

        $cheminZip = $dossierTemp . '/bulletins_classe_' . $classeId . '_' . $periodeId . '_' . uniqid() . '.zip';

        $zip = new ZipArchive();
        $zip->open($cheminZip, ZipArchive::CREATE | ZipArchive::OVERWRITE);

        foreach ($bulletins as $bulletin) {
            $bulletinComplet = $this->chargerBulletin($bulletin->id);
            $pdf = Pdf::loadView('pdf.bulletin', $this->donneesBulletin($bulletinComplet));

            $zip->addFromString($this->nomFichierBulletin($bulletinComplet), $pdf->output());
        }

        $zip->close();

        return $cheminZip;
    }

    // Document récapitulatif de classe : liste des élèves triée par rang,
    // avec leur moyenne générale (format "1. KODJO Jean 16,25 / ...").
    public function genererBulletinGlobalClasse(int $classeId, int $periodeId)
    {
        $bulletins = Bulletin::where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->with('eleve')
            ->orderBy('rang')
            ->get();

        if ($bulletins->isEmpty()) {
            throw new RuntimeException('Aucun bulletin généré pour cette classe et cette période.');
        }

        $premierBulletin = $bulletins->first()->load(['classe', 'periode', 'anneeScolaire']);

        $eleves = $bulletins->map(fn (Bulletin $b) => [
            'rang' => $b->rang,
            'rang_ex_aequo' => $b->rang_ex_aequo,
            'nom' => $b->eleve->nom,
            'prenom' => $b->eleve->prenom,
            'moyenne_generale' => (float) $b->moyenne_generale,
            'decision_conseil' => $b->decision_conseil,
        ])->values();

        return Pdf::loadView('pdf.bulletin_classe_recap', [
            'ecole' => IdentiteEcoleHelper::getIdentiteEcole($premierBulletin->ecole_id),
            'classe' => $premierBulletin->classe,
            'periode' => $premierBulletin->periode,
            'annee' => $premierBulletin->anneeScolaire,
            'effectif' => $premierBulletin->effectif_classe,
            'moyenne_classe' => round((float) $bulletins->avg('moyenne_generale'), 2),
            'eleves' => $eleves,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);
    }

    private function chargerBulletin(int $bulletinId): Bulletin
    {
        return Bulletin::with([
            'eleve',
            'classe',
            'periode',
            'anneeScolaire',
            'details' => fn ($q) => $q->orderBy('id'),
            'professeurPrincipal',
        ])->findOrFail($bulletinId);
    }

    private function donneesBulletin(Bulletin $bulletin): array
    {
        return [
            'ecole' => IdentiteEcoleHelper::getIdentiteEcole($bulletin->ecole_id),
            'parametre' => ParametreBulletin::firstOrCreate(['ecole_id' => $bulletin->ecole_id]),
            'bulletin' => $bulletin,
            'eleve' => $bulletin->eleve,
            'classe' => $bulletin->classe,
            'periode' => $bulletin->periode,
            'annee' => $bulletin->anneeScolaire,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ];
    }

    private function nomFichierBulletin(Bulletin $bulletin): string
    {
        return 'bulletin_' . str_replace(' ', '_', $bulletin->eleve->nom . '_' . $bulletin->eleve->prenom) . '.pdf';
    }
}
