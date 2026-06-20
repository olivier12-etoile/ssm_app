import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class AppreciationService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> recuperer({
    required int eleveId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/appreciations?eleve_id=$eleveId&periode_id=$periodeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement appréciation');
  }

  static Future<void> enregistrer({
    required int eleveId,
    required int periodeId,
    String? appreciationEnseignant,
    String? appreciationDirecteur,
    String? observation,
  }) async {
    final corps = <String, dynamic>{
      'eleve_id':   eleveId,
      'periode_id': periodeId,
    };
    if (appreciationEnseignant != null) {
      corps['appreciation_enseignant'] = appreciationEnseignant;
    }
    if (appreciationDirecteur != null) {
      corps['appreciation_directeur'] = appreciationDirecteur;
    }
    if (observation != null) {
      corps['observation'] = observation;
    }

    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/appreciations'),
      headers: await _headers(),
      body: jsonEncode(corps),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur enregistrement appréciation');
    }
  }

  static Future<String> suggererObservation(double moyenne) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/appreciations/suggerer?moyenne=$moyenne'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['observation_suggeree'] as String;
    }
    throw Exception('Erreur suggestion observation');
  }
}