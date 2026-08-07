import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class SituationFinanciereService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Situation financière complète d'un élève : frais applicables, montant
  // attendu/payé/restant, statut par frais, historique des paiements.
  static Future<Map<String, dynamic>> getSituation(
    int eleveId, {
    int? anneeScolaireId,
  }) async {
    final query = <String, String>{};
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/eleves/$eleveId/situation-financiere')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    final data = jsonDecode(response.body);
    throw Exception(data['message'] ?? 'Erreur chargement de la situation financière');
  }
}
