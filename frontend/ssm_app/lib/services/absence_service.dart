import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class AbsenceService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Liste des absences d'une classe à une date
  static Future<List<dynamic>> listerAbsences({
    required int classeId,
    required String dateAbsence,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/absences?classe_id=$classeId&date_absence=$dateAbsence'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement absences');
  }

  // Enregistrer les absences d'une classe (par lot)
  static Future<List<dynamic>> enregistrerAbsences({
    required int classeId,
    required String dateAbsence,
    required List<Map<String, dynamic>> absences,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/absences'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':    classeId,
        'date_absence': dateAbsence,
        'absences':     absences,
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['absences'] as List;
    }
    throw Exception('Erreur enregistrement absences');
  }

  // Marquer comme notifié
  static Future<void> marquerNotifie(int absenceId) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/absences/$absenceId/notifie'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur mise à jour notification');
    }
  }

  // Justifier une absence
  static Future<void> justifier(int absenceId, String motif) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/absences/$absenceId/justifier'),
      headers: await _headers(),
      body: jsonEncode({'motif': motif}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur justification');
    }
  }

  // Historique d'un élève
  static Future<Map<String, dynamic>> historiqueEleve(int eleveId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/absences/eleve/$eleveId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur historique absences');
  }

  // Statistiques
  static Future<Map<String, dynamic>> statistiques() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/absences/statistiques'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur statistiques absences');
  }
}