import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/affectation_service.dart';

class ClasseMatiereService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerParClasse(int classeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/classe-matieres?classe_id=$classeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement matières de la classe');
  }

  // Ajoute (ou met à jour le coefficient d')une matière dans une classe.
  // matiereId → réutilise une matière existante du catalogue de l'école.
  // Sinon matiereNom (+ code/couleur en option) → le backend réutilise la
  // matière si une du même nom existe déjà dans l'école, sinon la crée.
  // Si enseignantId est fourni, l'affecte à cette matière pour cette classe.
  // Retourne la matière (résolue ou créée) renvoyée par le backend.
  static Future<Map<String, dynamic>> ajouter({
    required int classeId,
    int? matiereId,
    String? matiereNom,
    String? matiereCode,
    String? matiereCouleur,
    required double coefficient,
    int? enseignantId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/classe-matieres'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id': classeId,
        'matiere_id': matiereId,
        'matiere_nom': matiereNom,
        'matiere_code': matiereCode,
        'matiere_couleur': matiereCouleur,
        'coefficient': coefficient,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur ajout matière à la classe');
    }

    final matiere = data['matiere'] as Map<String, dynamic>;

    if (enseignantId != null) {
      await AffectationService.ajouterAffectation(
        enseignantId: enseignantId,
        classeId: classeId,
        matiereId: matiere['id'] as int,
      );
    }

    return matiere;
  }

  static Future<void> supprimer(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/classe-matieres/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suppression matière de la classe');
    }
  }
}
