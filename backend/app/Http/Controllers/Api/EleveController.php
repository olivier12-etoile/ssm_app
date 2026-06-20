<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Eleve;
use App\Models\Inscription;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class EleveController extends Controller
{
    // Liste des élèves de l'école
    public function index(Request $request)
    {
        $eleves = Eleve::where('ecole_id', $request->user()->ecole_id)
            ->orderBy('nom')
            ->get();

        return response()->json($eleves);
    }

    // Élèves d'une classe
    public function parClasse(Request $request, $classeId)
    {
        $anneeId = $request->query('annee_id');

        $eleves = Eleve::where('ecole_id', $request->user()->ecole_id)
            ->whereHas('inscriptions', function ($q) use ($classeId, $anneeId) {
                $q->where('classe_id', $classeId);
                if ($anneeId) {
                    $q->where('annee_academique_id', $anneeId);
                }
            })
            ->orderBy('nom')
            ->get();

        return response()->json($eleves);
    }

    // Créer un élève
    public function creer(Request $request)
    {
        $request->validate([
            'nom'               => 'required|string|max:100',
            'prenom'            => 'required|string|max:100',
            'sexe'              => 'required|in:M,F',
            'date_naissance'    => 'nullable|date',
            'telephone_parent'  => 'nullable|string|max:20',
            'classe_id'         => 'required|integer',
            'annee_academique_id' => 'required|integer',
        ]);

        // Générer matricule unique
        do {
            $matricule = strtoupper(Str::random(8));
        } while (Eleve::where('matricule', $matricule)->exists());

        $eleve = Eleve::create([
            'ecole_id'         => $request->user()->ecole_id,
            'nom'              => $request->nom,
            'prenom'           => $request->prenom,
            'sexe'             => $request->sexe,
            'date_naissance'   => $request->date_naissance,
            'telephone_parent' => $request->telephone_parent,
            'matricule'        => $matricule,
        ]);

        // Inscrire dans la classe
        Inscription::create([
            'eleve_id'            => $eleve->id,
            'classe_id'           => $request->classe_id,
            'annee_academique_id' => $request->annee_academique_id,
            'statut'              => 'inscrit',
        ]);

        return response()->json([
            'message' => 'Élève créé et inscrit avec succès',
            'eleve'   => $eleve,
        ], 201);
    }

    public function uploaderPhoto(Request $request, $id)
{
    $request->validate([
        'photo' => 'required|image|mimes:jpg,jpeg,png|max:5120', // 5 Mo max
    ]);

    $eleve = Eleve::where('id', $id)
        ->where('ecole_id', $request->user()->ecole_id)
        ->firstOrFail();

    // Supprimer l'ancienne photo si elle existe
    if ($eleve->photo_path) {
        \Storage::disk('public')->delete($eleve->photo_path);
    }

    // Stocker la nouvelle photo
    $chemin = $request->file('photo')->store('eleves/photos', 'public');

    $eleve->update(['photo_path' => $chemin]);

    return response()->json([
        'message'    => 'Photo mise à jour avec succès',
        'photo_url'  => asset('storage/' . $chemin),
    ]);
}
}