import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class DisciplineService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste filtrée des sanctions ─────────────────────────
  static Future<List<dynamic>> lister({
    int? classeId,
    int? eleveId,
  }) async {
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';
    if (eleveId != null)  query['eleve_id']  = '$eleveId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/sanctions')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des sanctions');
  }

  // ── Créer une sanction ──────────────────────────────────
  // type : retard | avertissement | exclusion | observation | conseil_discipline
  static Future<Map<String, dynamic>> creer({
    required int eleveId,
    required int classeId,
    required String type,
    required String description,
    required String dateSanction,
    bool notifieParent = false,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/sanctions'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id':       eleveId,
        'classe_id':      classeId,
        'type':           type,
        'description':    description,
        'date_sanction':  dateSanction,
        'notifie_parent': notifieParent,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Erreur création sanction');
  }

  // ── Historique d'un élève ───────────────────────────────
  static Future<List<dynamic>> historiqueEleve(int eleveId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sanctions/eleve/$eleveId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement historique disciplinaire');
  }

  // ── Statistiques (globales ou par classe) ───────────────
  static Future<Map<String, dynamic>> statistiques({int? classeId}) async {
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/sanctions/statistiques')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement statistiques disciplinaires');
  }

  // ── Marquer le parent comme notifié ─────────────────────
  static Future<void> notifier(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/sanctions/$id/notifier'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur mise à jour notification');
    }
  }
}
