import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class NotificationAttenteService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> lister({String type = 'tout'}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications-attente?type=$type'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement notifications');
  }

  static Future<void> marquerEnvoyee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications-attente/$id/envoyee'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur mise à jour notification');
    }
  }

  static Future<void> supprimer(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications-attente/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suppression notification');
    }
  }
}