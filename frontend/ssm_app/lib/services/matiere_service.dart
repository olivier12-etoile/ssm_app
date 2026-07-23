import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class MatiereService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste des matières de l'école ──────────────────────
  // Renvoie la liste enrichie (nombre_classes, enseignants, moyenne_generale).
  static Future<List<dynamic>> listerMatieres({
    String? recherche,
  }) async {
    final query = <String, String>{};
    if (recherche != null && recherche.isNotEmpty) query['search'] = recherche;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/matieres')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement matières');
  }

  // ── Créer une matière ───────────────────────────────────
  static Future<void> creerMatiere({
    required String nom,
    String? code,
    String? couleur,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/matieres'),
      headers: await _headers(),
      body: jsonEncode({
        'nom':     nom,
        'code':    code,
        'couleur': couleur,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création matière');
    }
  }

  // ── Modifier une matière ────────────────────────────────
  static Future<void> modifierMatiere(
    int id, {
    String? nom,
    String? code,
    String? couleur,
  }) async {
    final donnees = <String, dynamic>{};
    if (nom != null)     donnees['nom']     = nom;
    if (code != null)    donnees['code']    = code;
    if (couleur != null) donnees['couleur'] = couleur;

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/matieres/$id'),
      headers: await _headers(),
      body: jsonEncode(donnees),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur modification matière');
    }
  }

  // ── Supprimer une matière ───────────────────────────────
  static Future<void> supprimerMatiere(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/matieres/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur suppression matière');
    }
  }

  // ── Statistiques par matière ────────────────────────────
  static Future<Map<String, dynamic>> statistiques() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/matieres/statistiques'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement statistiques matières');
  }
}