import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/presence_model.dart';
import 'auth_service.dart';

class PresenceService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<AppelPresence> creerAppel({
    required int classeId,
    int? matiereId,
    required int periodeId,
    required String dateAppel,
    int? creneauHoraireId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/appels'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id': classeId,
        'matiere_id': matiereId,
        'periode_id': periodeId,
        'date_appel': dateAppel,
        'creneau_horaire_id': creneauHoraireId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? "Erreur création de l'appel");
    }
    return AppelPresence.fromJson(data['appel'] as Map<String, dynamic>);
  }

  static Future<AppelPresence> getAppel(int appelId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/appels/$appelId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Erreur chargement de l'appel");
    }
    return AppelPresence.fromJson(data as Map<String, dynamic>);
  }

  static Future<Presence> marquerPresence({
    required int appelId,
    required int eleveId,
    required StatutPresence statut,
    bool justifie = false,
    String? motif,
    int? minutesRetard,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/appels/$appelId/marquer'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id': eleveId,
        'statut': statut.valeurApi,
        'justifie': justifie,
        'motif': motif,
        'minutes_retard': minutesRetard,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur mise à jour de la présence');
    }
    return Presence.fromJson(data['presence'] as Map<String, dynamic>);
  }

  static Future<AppelPresence> marquerPresenceBulk(int appelId, List<Presence> statuts) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/appels/$appelId/marquer-bulk'),
      headers: await _headers(),
      body: jsonEncode({'statuts': statuts.map((p) => p.toJson()).toList()}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur mise à jour des présences');
    }
    return AppelPresence.fromJson(data['appel'] as Map<String, dynamic>);
  }

  static Future<AppelPresence> terminerAppel(int appelId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/appels/$appelId/terminer'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Erreur clôture de l'appel");
    }
    return AppelPresence.fromJson(data['appel'] as Map<String, dynamic>);
  }

  static Future<HistoriquePresenceEleve> getHistoriqueEleve(int eleveId, int periodeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/historique/eleve/$eleveId/$periodeId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement historique de présence');
    }
    return HistoriquePresenceEleve.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<StatistiquePresenceClasse> getStatistiquesClasse(int classeId, int periodeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/statistiques/classe/$classeId/$periodeId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement statistiques de présence');
    }
    return StatistiquePresenceClasse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<AppelPresence>> getAppelsRecents(int classeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/presences/appels-recents/$classeId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement des appels récents');
    }
    final liste = jsonDecode(response.body) as List<dynamic>;
    return liste.map((a) => AppelPresence.fromJson(a as Map<String, dynamic>)).toList();
  }
}
