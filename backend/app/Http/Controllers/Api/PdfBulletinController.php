<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Bulletin;
use App\Models\Classe;
use App\Services\PdfBulletinService;
use Illuminate\Http\Request;
use RuntimeException;

class PdfBulletinController extends Controller
{
    public function __construct(private PdfBulletinService $service)
    {
    }

    // GET /bulletins/pdf/{bulletinId}
    public function telechargerIndividuel(Request $request, int $bulletinId)
    {
        $bulletin = $this->bulletinDeLecole($request, $bulletinId);

        $pdf = $this->service->genererPdf($bulletin->id);

        return $pdf->download($this->nomFichier($bulletin));
    }

    // GET /bulletins/pdf/{bulletinId}/apercu
    // Même génération que telechargerIndividuel() : le statut du bulletin
    // (genere = brouillon, valide/verrouille = officiel) suffit à distinguer
    // un aperçu d'un bulletin définitif, pas besoin d'un rendu différent.
    public function previsualiser(Request $request, int $bulletinId)
    {
        $bulletin = $this->bulletinDeLecole($request, $bulletinId);

        $pdf = $this->service->genererPdf($bulletin->id);

        return $pdf->stream($this->nomFichier($bulletin));
    }

    // GET /bulletins/pdf/classe/{classeId}/{periodeId}/zip
    public function telechargerClasseZip(Request $request, int $classeId, int $periodeId)
    {
        $classe = $this->classeDeLecole($request, $classeId);

        try {
            $cheminZip = $this->service->genererPdfClasse($classe->id, $periodeId);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $nomZip = 'bulletins_' . str_replace(' ', '_', $classe->nom) . '.zip';

        return response()->download($cheminZip, $nomZip)->deleteFileAfterSend(true);
    }

    // GET /bulletins/pdf/classe/{classeId}/{periodeId}/global
    public function telechargerGlobalClasse(Request $request, int $classeId, int $periodeId)
    {
        $classe = $this->classeDeLecole($request, $classeId);

        try {
            $pdf = $this->service->genererBulletinGlobalClasse($classe->id, $periodeId);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return $pdf->download('recapitulatif_' . str_replace(' ', '_', $classe->nom) . '.pdf');
    }

    private function bulletinDeLecole(Request $request, int $bulletinId): Bulletin
    {
        return Bulletin::where('id', $bulletinId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->with('eleve')
            ->firstOrFail();
    }

    private function classeDeLecole(Request $request, int $classeId): Classe
    {
        return Classe::where('id', $classeId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();
    }

    private function nomFichier(Bulletin $bulletin): string
    {
        return 'bulletin_' . str_replace(' ', '_', $bulletin->eleve->nom . '_' . $bulletin->eleve->prenom) . '.pdf';
    }
}
