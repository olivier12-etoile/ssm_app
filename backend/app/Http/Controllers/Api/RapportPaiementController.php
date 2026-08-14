<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Services\RapportPaiementService;
use Illuminate\Http\Request;

class RapportPaiementController extends Controller
{
    public function __construct(private RapportPaiementService $rapportPaiement)
    {
    }

    // GET /paiements/rapports/journalier
    public function journalier(Request $request)
    {
        $request->validate(['date' => 'nullable|date']);

        return response()->json(
            $this->rapportPaiement->rapportJournalier($request->input('date', now()->toDateString()))
        );
    }

    // GET /paiements/rapports/hebdomadaire
    public function hebdomadaire(Request $request)
    {
        $request->validate(['date_debut' => 'nullable|date']);

        $dateDebut = $request->input('date_debut', now()->startOfWeek()->toDateString());

        return response()->json($this->rapportPaiement->rapportHebdomadaire($dateDebut));
    }

    // GET /paiements/rapports/mensuel
    public function mensuel(Request $request)
    {
        $request->validate([
            'mois'  => 'nullable|integer|min:1|max:12',
            'annee' => 'nullable|integer|min:2000',
        ]);

        $mois = (int) $request->input('mois', now()->month);
        $annee = (int) $request->input('annee', now()->year);

        return response()->json($this->rapportPaiement->rapportMensuel($mois, $annee));
    }

    // GET /paiements/rapports/annuel
    public function annuel(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'nullable|integer']);

        $anneeScolaireId = $request->integer('annee_scolaire_id')
            ?: optional(AnneeAcademique::where('ecole_id', $request->user()->ecole_id)->where('statut', 'active')->first())->id;

        if (!$anneeScolaireId) {
            return response()->json(['message' => 'Aucune année scolaire active. Précisez annee_scolaire_id.'], 422);
        }

        return response()->json($this->rapportPaiement->rapportAnnuel($anneeScolaireId));
    }

    // GET /paiements/rapports/personnalise
    public function personnalise(Request $request)
    {
        $data = $request->validate([
            'date_debut' => 'required|date',
            'date_fin'   => 'required|date|after_or_equal:date_debut',
        ]);

        return response()->json($this->rapportPaiement->rapportPersonnalise($data['date_debut'], $data['date_fin']));
    }

    // GET /paiements/rapports/export
    public function export(Request $request)
    {
        $data = $request->validate([
            'type'   => 'required|in:journalier,hebdomadaire,mensuel,annuel,personnalise',
            'format' => 'required|in:pdf,excel',
        ]);

        $parametres = $request->except(['type', 'format']);

        try {
            return $data['format'] === 'excel'
                ? $this->rapportPaiement->exportExcel($data['type'], $parametres)
                : $this->rapportPaiement->exportPdf($data['type'], $parametres);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }
    }
}
