import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class AnneeService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerAnnees() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement années');
  }

  static Future<void> creerAnnee({
    required String libelle,
    required String dateDebut,
    required String dateFin,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/annees'),
      headers: await _headers(),
      body: jsonEncode({
        'libelle':    libelle,
        'date_debut': dateDebut,
        'date_fin':   dateFin,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création année');
    }
  }

  static Future<List<dynamic>> listerPeriodes(int anneeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement périodes');
  }

  static Future<void> creerPeriode({
    required int anneeAcademiqueId,
    required String nom,
    required String dateDebut,
    required String dateFin,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes'),
      headers: await _headers(),
      body: jsonEncode({
        'annee_academique_id': anneeAcademiqueId,
        'nom':                 nom,
        'date_debut':          dateDebut,
        'date_fin':            dateFin,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création période');
    }
  }

  static Future<void> changerStatutPeriode(int id, String statut) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/statut'),
      headers: await _headers(),
      body: jsonEncode({'statut': statut}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur changement statut');
    }
  }
}