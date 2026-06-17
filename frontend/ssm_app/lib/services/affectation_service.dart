import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class AffectationService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Liste des affectations d'un enseignant
  static Future<Map<String, dynamic>> listerAffectations(int enseignantId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/affectations/$enseignantId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement affectations');
  }

  // Ajouter une affectation
  static Future<void> ajouterAffectation({
    required int enseignantId,
    required int classeId,
    required int matiereId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/affectations'),
      headers: await _headers(),
      body: jsonEncode({
        'enseignant_id': enseignantId,
        'classe_id':     classeId,
        'matiere_id':    matiereId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur ajout affectation');
    }
  }

  // Supprimer une affectation
  static Future<void> supprimerAffectation(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/affectations/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suppression affectation');
    }
  }
}