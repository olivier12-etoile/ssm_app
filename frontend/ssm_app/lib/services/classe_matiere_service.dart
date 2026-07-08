import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class ClasseMatiereService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
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

  static Future<void> ajouter(
    int classeId,
    int matiereId,
    double coefficient,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/classe-matieres'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':   classeId,
        'matiere_id':  matiereId,
        'coefficient': coefficient,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur ajout matière à la classe');
    }
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
