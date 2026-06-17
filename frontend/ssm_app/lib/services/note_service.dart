import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class NoteService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerNotes({
    required int classeId,
    required int periodeId,
    required int matiereId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/notes?classe_id=$classeId&periode_id=$periodeId&matiere_id=$matiereId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement notes');
  }

  static Future<void> sauvegarderNote({
    required int eleveId,
    required int matiereId,
    required int periodeId,
    required double valeur,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id':   eleveId,
        'matiere_id': matiereId,
        'periode_id': periodeId,
        'valeur':     valeur,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur sauvegarde note');
    }
  }

  static Future<void> soumettreNotes({
    required int classeId,
    required int periodeId,
    required int matiereId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/soumettre'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':  classeId,
        'periode_id': periodeId,
        'matiere_id': matiereId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur soumission notes');
    }
  }

  static Future<void> validerNotes({
    required int classeId,
    required int periodeId,
    required int matiereId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/valider'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':  classeId,
        'periode_id': periodeId,
        'matiere_id': matiereId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur validation notes');
    }
  }

  static Future<void> rejeterNotes({
    required int classeId,
    required int periodeId,
    required int matiereId,
    required String motifRejet,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/rejeter'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':   classeId,
        'periode_id':  periodeId,
        'matiere_id':  matiereId,
        'motif_rejet': motifRejet,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur rejet notes');
    }
  }
}