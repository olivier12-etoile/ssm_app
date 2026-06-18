import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class PaiementService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Liste tous les paiements
  static Future<List<dynamic>> listerPaiements() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement paiements');
  }

  // Paiements d'un élève
  static Future<Map<String, dynamic>> paiementsEleve(int eleveId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/eleve/$eleveId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement paiements élève');
  }

  // Enregistrer un paiement
  static Future<void> enregistrer({
    required int eleveId,
    required int anneeAcademiqueId,
    required double montant,
    required String tranche,
    required String datePaiement,
    String? reference,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id':            eleveId,
        'annee_academique_id': anneeAcademiqueId,
        'montant':             montant,
        'tranche':             tranche,
        'date_paiement':       datePaiement,
        'reference':           reference,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur enregistrement paiement');
    }
  }

  // Liste de renvoi
  static Future<Map<String, dynamic>> listeRenvoi({
    required int classeId,
    required int anneeAcademiqueId,
    required double montantExige,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/liste-renvoi'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':           classeId,
        'annee_academique_id': anneeAcademiqueId,
        'montant_exige':       montantExige,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur liste renvoi');
  }

  // Statistiques
  static Future<Map<String, dynamic>> statistiques(int? anneeId) async {
    final url = anneeId != null
        ? '${AppConfig.apiBaseUrl}/paiements/statistiques?annee_id=$anneeId'
        : '${AppConfig.apiBaseUrl}/paiements/statistiques';
    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur statistiques');
  }
}