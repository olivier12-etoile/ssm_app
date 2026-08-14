<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\Eleve;
use App\Models\PeriodeAcademique;
use App\Models\SaisieNote;
use App\Services\NoteCalculService;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

class AnalysePerformanceController extends Controller
{
    public function __construct(private NoteCalculService $noteCalcul)
    {
    }

    // GET /notes/analyse/resume?periode_id=
    public function resume(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);

        $classesIncompletes = $this->calculerClassesIncompletes($request, $periode);
        $enseignantsEnRetard = $this->calculerEnseignantsEnRetard($request, $periode);
        $elevesFaibles = $this->calculerElevesParSeuil($request, $periode, 8.0, 'faible');
        $elevesExcellents = $this->calculerElevesParSeuil($request, $periode, 16.0, 'excellent');

        return response()->json([
            'periode_id' => $periode->id,
            'periode_nom' => $periode->nom,
            'classes_incompletes' => $classesIncompletes->take(5)->values(),
            'nombre_classes_incompletes' => $classesIncompletes->count(),
            'enseignants_en_retard' => $enseignantsEnRetard->take(5)->values(),
            'nombre_enseignants_en_retard' => $enseignantsEnRetard->count(),
            'eleves_faibles' => $elevesFaibles->take(5)->values(),
            'nombre_eleves_faibles' => $elevesFaibles->count(),
            'eleves_excellents' => $elevesExcellents->take(5)->values(),
            'nombre_eleves_excellents' => $elevesExcellents->count(),
            'classement_classes' => $this->calculerClassementClasses($request, $periode)->values(),
        ]);
    }

    // GET /notes/analyse/classes-incompletes?periode_id=
    public function classesIncompletes(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);

        return response()->json(['classes' => $this->calculerClassesIncompletes($request, $periode)->values()]);
    }

    // GET /notes/analyse/matieres-non-validees?periode_id=
    public function matieresNonValidees(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);
        $ecoleId = $request->user()->ecole_id;

        $saisies = SaisieNote::where('ecole_id', $ecoleId)
            ->where('periode_id', $periode->id)
            ->whereIn('statut', ['en_cours', 'en_attente_validation', 'rejetee'])
            ->when($request->filled('classe_id'), fn ($q) => $q->where('classe_id', $request->classe_id))
            ->when($request->filled('niveau'), fn ($q) => $q->whereHas('classe', fn ($q2) => $q2->where('niveau', $request->niveau)))
            ->with(['classe:id,nom', 'matiere:id,nom', 'enseignant:id,name'])
            ->get()
            ->groupBy('classe_id')
            ->map(function (Collection $groupe) {
                $premiere = $groupe->first();

                return [
                    'classe_id' => $premiere->classe_id,
                    'classe_nom' => $premiere->classe->nom,
                    'matieres' => $groupe->map(fn (SaisieNote $s) => [
                        'matiere_id' => $s->matiere_id,
                        'matiere_nom' => $s->matiere->nom,
                        'enseignant_nom' => $s->enseignant->name,
                        'statut' => $s->statut,
                    ])->values(),
                ];
            })
            ->values();

        return response()->json(['classes' => $saisies]);
    }

    // GET /notes/analyse/enseignants-en-retard?periode_id=
    public function enseignantsEnRetard(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);

        return response()->json(['enseignants' => $this->calculerEnseignantsEnRetard($request, $periode)->values()]);
    }

    // GET /notes/analyse/eleves-faibles?periode_id=&seuil=
    public function elevesFaibles(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);
        $seuil = (float) $request->input('seuil', 8);

        return response()->json([
            'seuil' => $seuil,
            'eleves' => $this->calculerElevesParSeuil($request, $periode, $seuil, 'faible')->values(),
        ]);
    }

    // GET /notes/analyse/eleves-excellents?periode_id=&seuil=
    public function elevesExcellents(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);
        $seuil = (float) $request->input('seuil', 16);

        return response()->json([
            'seuil' => $seuil,
            'eleves' => $this->calculerElevesParSeuil($request, $periode, $seuil, 'excellent')->values(),
        ]);
    }

    // GET /notes/analyse/classement-classes?periode_id=
    public function classementClasses(Request $request)
    {
        $this->autoriserGestionnaire($request);
        $periode = $this->periodeDepuisRequest($request);

        return response()->json(['classement' => $this->calculerClassementClasses($request, $periode)->values()]);
    }

    // ── Calculs internes (partagés entre les endpoints et resume()) ────

    private function classesFiltrees(Request $request, PeriodeAcademique $periode): Collection
    {
        return Classe::where('ecole_id', $periode->annee->ecole_id)
            ->when($request->filled('classe_id'), fn ($q) => $q->where('id', $request->classe_id))
            ->when($request->filled('niveau'), fn ($q) => $q->where('niveau', $request->niveau))
            ->get();
    }

    private function elevesClasse(Classe $classe, PeriodeAcademique $periode): Collection
    {
        return Eleve::where('ecole_id', $classe->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q
                ->where('classe_id', $classe->id)
                ->where('annee_academique_id', $periode->annee_academique_id))
            ->get();
    }

    private function calculerClassesIncompletes(Request $request, PeriodeAcademique $periode): Collection
    {
        return $this->classesFiltrees($request, $periode)
            ->map(function (Classe $classe) use ($periode) {
                $matieres = ClasseMatiere::where('classe_id', $classe->id)->with('matiere:id,nom')->get();

                $matieresIncompletes = $matieres
                    ->filter(function (ClasseMatiere $cm) use ($classe, $periode) {
                        $saisie = SaisieNote::where('classe_id', $classe->id)
                            ->where('matiere_id', $cm->matiere_id)
                            ->where('periode_id', $periode->id)
                            ->first();

                        return !$saisie || $saisie->statut !== 'validee';
                    })
                    ->map(fn (ClasseMatiere $cm) => [
                        'matiere_id' => $cm->matiere_id,
                        'matiere_nom' => $cm->matiere->nom,
                    ])
                    ->values();

                if ($matieresIncompletes->isEmpty()) {
                    return null;
                }

                return [
                    'classe_id' => $classe->id,
                    'classe_nom' => $classe->nom,
                    'nombre_matieres_incompletes' => $matieresIncompletes->count(),
                    'matieres_incompletes' => $matieresIncompletes,
                ];
            })
            ->filter()
            ->values();
    }

    // Rendue publique (comme calculerElevesParSeuil/calculerClassementClasses
    // ci-dessous) pour être réutilisée par CentreDecisionService.
    public function calculerEnseignantsEnRetard(Request $request, PeriodeAcademique $periode): Collection
    {
        if (!$periode->date_fin || now()->lessThanOrEqualTo($periode->date_fin)) {
            return collect();
        }

        $ecoleId = $request->user()->ecole_id;

        return SaisieNote::where('ecole_id', $ecoleId)
            ->where('periode_id', $periode->id)
            ->whereIn('statut', ['en_cours', 'rejetee'])
            ->when($request->filled('classe_id'), fn ($q) => $q->where('classe_id', $request->classe_id))
            ->when($request->filled('niveau'), fn ($q) => $q->whereHas('classe', fn ($q2) => $q2->where('niveau', $request->niveau)))
            ->with(['enseignant:id,name', 'classe:id,nom', 'matiere:id,nom'])
            ->get()
            ->map(function (SaisieNote $saisie) use ($periode) {
                $nbEleves = $this->elevesClasse($saisie->classe, $periode)->count();
                $nbNotes = $saisie->notes()->count();
                $attendu = $nbEleves * 2;
                $pourcentage = $attendu > 0 ? round(min($nbNotes, $attendu) / $attendu * 100, 1) : 0;

                return [
                    'enseignant_id' => $saisie->enseignant_id,
                    'enseignant_nom' => $saisie->enseignant->name,
                    'classe_id' => $saisie->classe_id,
                    'classe_nom' => $saisie->classe->nom,
                    'matiere_id' => $saisie->matiere_id,
                    'matiere_nom' => $saisie->matiere->nom,
                    'pourcentage_completion' => $pourcentage,
                    'jours_de_retard' => now()->diffInDays($periode->date_fin),
                ];
            })
            ->filter(fn ($e) => $e['pourcentage_completion'] < 100)
            ->values();
    }

    // $sens = 'faible' (moyenne < seuil) ou 'excellent' (moyenne >= seuil)
    public function calculerElevesParSeuil(Request $request, PeriodeAcademique $periode, float $seuil, string $sens): Collection
    {
        $resultat = collect();

        foreach ($this->classesFiltrees($request, $periode) as $classe) {
            foreach ($this->elevesClasse($classe, $periode) as $eleve) {
                $moyenne = $this->noteCalcul->moyenneEleve($eleve->id, $periode->id);
                if ($moyenne === null) {
                    continue;
                }

                $correspond = $sens === 'faible' ? $moyenne < $seuil : $moyenne >= $seuil;
                if (!$correspond) {
                    continue;
                }

                $resultat->push([
                    'eleve_id' => $eleve->id,
                    'nom' => $eleve->nom,
                    'prenom' => $eleve->prenom,
                    'matricule' => $eleve->matricule,
                    'classe_id' => $classe->id,
                    'classe_nom' => $classe->nom,
                    'moyenne_generale' => $moyenne,
                ]);
            }
        }

        return $sens === 'faible'
            ? $resultat->sortBy('moyenne_generale')->values()
            : $resultat->sortByDesc('moyenne_generale')->values();
    }

    public function calculerClassementClasses(Request $request, PeriodeAcademique $periode): Collection
    {
        return $this->classesFiltrees($request, $periode)
            ->map(function (Classe $classe) use ($periode) {
                $moyennes = $this->elevesClasse($classe, $periode)
                    ->map(fn (Eleve $e) => $this->noteCalcul->moyenneEleve($e->id, $periode->id))
                    ->filter(fn ($m) => $m !== null);

                $tauxReussite = $moyennes->isNotEmpty()
                    ? round($moyennes->filter(fn ($m) => $m >= 10)->count() / $moyennes->count() * 100, 1)
                    : null;

                return [
                    'classe_id' => $classe->id,
                    'classe_nom' => $classe->nom,
                    'nombre_eleves' => $moyennes->count(),
                    'moyenne_classe' => $moyennes->isNotEmpty() ? round($moyennes->avg(), 2) : null,
                    'taux_reussite' => $tauxReussite,
                ];
            })
            ->filter(fn ($c) => $c['taux_reussite'] !== null)
            ->sortByDesc('taux_reussite')
            ->values();
    }

    public function periodeEcole(Request $request, $periodeId): PeriodeAcademique
    {
        return PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $request->user()->ecole_id))
            ->with('annee')
            ->findOrFail($periodeId);
    }

    // Les routes /notes/analyse/* passent periode_id en paramètre de requête
    // (pas de segment {periodeId} dans l'URL).
    private function periodeDepuisRequest(Request $request): PeriodeAcademique
    {
        $request->validate(['periode_id' => 'required|integer']);

        return $this->periodeEcole($request, $request->input('periode_id'));
    }

    private function autoriserGestionnaire(Request $request): void
    {
        abort_unless(in_array($request->user()->role, ['directeur', 'censeur']), 403,
            'Seuls le directeur ou le censeur peuvent consulter ces analyses.');
    }
}
