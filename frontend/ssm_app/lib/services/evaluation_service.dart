import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class EvaluationService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerEvaluations({
    required int classeId,
    required int matiereId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/evaluations?classe_id=$classeId&matiere_id=$matiereId&periode_id=$periodeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement évaluations');
  }

  static Future<Map<String, dynamic>> creerEvaluation({
    required int classeId,
    required int matiereId,
    required int periodeId,
    required String type,
    required int numero,
    required String libelle,
    required String dateEvaluation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/evaluations'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':       classeId,
        'matiere_id':      matiereId,
        'periode_id':      periodeId,
        'type':            type,
        'numero':          numero,
        'libelle':         libelle,
        'date_evaluation': dateEvaluation,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur création évaluation');
    }
    return data;
  }

  static Future<void> saisirNotes({
    required int evaluationId,
    required List<Map<String, dynamic>> notes,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/evaluations/$evaluationId/notes'),
      headers: await _headers(),
      body: jsonEncode({'notes': notes}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur enregistrement des notes');
    }
  }

  static Future<Map<String, dynamic>> calculerMoyenne({
    required int classeId,
    required int matiereId,
    required int periodeId,
    required int eleveId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/evaluations/moyenne?classe_id=$classeId&matiere_id=$matiereId&periode_id=$periodeId&eleve_id=$eleveId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur calcul de la moyenne');
  }

  static Future<List<dynamic>> moyennesClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/evaluations/moyennes-classe?classe_id=$classeId&periode_id=$periodeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['eleves'] as List<dynamic>;
    }
    throw Exception('Erreur chargement des moyennes de la classe');
  }
}
