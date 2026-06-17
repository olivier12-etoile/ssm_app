import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class EleveService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerEleves() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement élèves');
  }

  static Future<List<dynamic>> elevesParClasse(
      int classeId, int anneeId) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/eleves/classe/$classeId?annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement élèves');
  }

  static Future<void> creerEleve({
    required String nom,
    required String prenom,
    required String sexe,
    required int classeId,
    required int anneeAcademiqueId,
    String? dateNaissance,
    String? telephoneParent,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves'),
      headers: await _headers(),
      body: jsonEncode({
        'nom':                  nom,
        'prenom':               prenom,
        'sexe':                 sexe,
        'classe_id':            classeId,
        'annee_academique_id':  anneeAcademiqueId,
        'date_naissance':       dateNaissance,
        'telephone_parent':     telephoneParent,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création élève');
    }
  }
}