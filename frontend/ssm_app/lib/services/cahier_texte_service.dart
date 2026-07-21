import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class CahierTexteService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste filtrée ───────────────────────────────────────
  static Future<List<dynamic>> lister({
    required int classeId,
    int? matiereId,
    String? date,
  }) async {
    final query = <String, String>{'classe_id': '$classeId'};
    if (matiereId != null) query['matiere_id'] = '$matiereId';
    if (date != null)      query['date']       = date;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/cahier-texte')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement du cahier de texte');
  }

  // ── Créer une entrée ────────────────────────────────────
  static Future<Map<String, dynamic>> creer({
    required int classeId,
    required int matiereId,
    required String dateCours,
    required String coursDuJour,
    String? exercices,
    String? devoir,
    String? dateRemiseDevoir,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/cahier-texte'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':          classeId,
        'matiere_id':         matiereId,
        'date_cours':         dateCours,
        'cours_du_jour':      coursDuJour,
        'exercices':          exercices,
        'devoir':             devoir,
        'date_remise_devoir': dateRemiseDevoir,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Erreur création entrée cahier de texte');
  }

  // ── Modifier une entrée ─────────────────────────────────
  static Future<void> modifier(
    int id, {
    int? matiereId,
    String? dateCours,
    String? coursDuJour,
    String? exercices,
    String? devoir,
    String? dateRemiseDevoir,
  }) async {
    final donnees = <String, dynamic>{};
    if (matiereId != null)         donnees['matiere_id']          = matiereId;
    if (dateCours != null)         donnees['date_cours']          = dateCours;
    if (coursDuJour != null)       donnees['cours_du_jour']       = coursDuJour;
    if (exercices != null)         donnees['exercices']           = exercices;
    if (devoir != null)            donnees['devoir']              = devoir;
    if (dateRemiseDevoir != null)  donnees['date_remise_devoir']  = dateRemiseDevoir;

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/cahier-texte/$id'),
      headers: await _headers(),
      body: jsonEncode(donnees),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur modification entrée cahier de texte');
    }
  }

  // ── Historique complet d'une classe ─────────────────────
  static Future<List<dynamic>> historiqueClasse(int classeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/cahier-texte/classe/$classeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement historique du cahier de texte');
  }
}
