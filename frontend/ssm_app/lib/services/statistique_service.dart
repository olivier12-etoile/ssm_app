import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class StatistiqueService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> chargerStatistiques({
    int? anneeId,
    int? periodeId,
  }) async {
    final query = <String, String>{};
    if (anneeId != null) query['annee_id'] = '$anneeId';
    if (periodeId != null) query['periode_id'] = '$periodeId';

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/statistiques',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement statistiques');
  }
}
