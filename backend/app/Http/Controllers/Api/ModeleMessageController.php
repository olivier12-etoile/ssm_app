<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ModeleMessage;
use Illuminate\Http\Request;

class ModeleMessageController extends Controller
{
    private const CATEGORIES = ['scolarite', 'finances', 'presence', 'administration', 'discipline', 'vie_scolaire'];

    // Liste des modèles de messages (filtrable par catégorie)
    public function index(Request $request)
    {
        $query = ModeleMessage::where('ecole_id', $request->user()->ecole_id)->orderBy('nom');

        if ($request->filled('categorie')) {
            $query->where('categorie', $request->categorie);
        }

        return response()->json(['modeles' => $query->get()]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'nom'                   => 'required|string|max:255',
            'categorie'             => 'required|in:' . implode(',', self::CATEGORIES),
            'contenu'               => 'required|string',
            'variables_disponibles' => 'nullable|array',
            'actif'                 => 'boolean',
        ]);

        $data['ecole_id']   = $request->user()->ecole_id;
        $data['modifiable'] = true;

        $modele = ModeleMessage::create($data);

        return response()->json(['modele' => $modele], 201);
    }

    public function update(Request $request, $id)
    {
        $modele = ModeleMessage::where('ecole_id', $request->user()->ecole_id)->findOrFail($id);

        if (!$modele->modifiable) {
            return response()->json(['message' => "Ce modèle système n'est pas modifiable."], 422);
        }

        $data = $request->validate([
            'nom'                   => 'sometimes|required|string|max:255',
            'categorie'             => 'sometimes|required|in:' . implode(',', self::CATEGORIES),
            'contenu'               => 'sometimes|required|string',
            'variables_disponibles' => 'nullable|array',
            'actif'                 => 'boolean',
        ]);

        $modele->update($data);

        return response()->json(['modele' => $modele]);
    }

    public function destroy(Request $request, $id)
    {
        $modele = ModeleMessage::where('ecole_id', $request->user()->ecole_id)->findOrFail($id);

        if (!$modele->modifiable) {
            return response()->json(['message' => "Ce modèle système ne peut pas être supprimé."], 422);
        }

        $modele->delete();

        return response()->json(['message' => 'Modèle supprimé.']);
    }
}
