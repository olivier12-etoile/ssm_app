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

  // ── Années académiques ──────────────────────────────────

  static Future<List<dynamic>> listerAnnees() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement années');
  }

  // Renvoie {message, annee: null} avec un statut 404 si aucune année
  // n'est active — ce n'est pas une erreur, l'appelant doit vérifier
  // le contenu (`annee`) plutôt que catcher une exception.
  static Future<Map<String, dynamic>> anneeActive() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/active'),
      headers: await _headers(),
    );
    if (response.statusCode == 200 || response.statusCode == 404) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement année active');
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

  static Future<void> activerAnnee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/activer'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur activation année');
    }
  }

  static Future<void> cloturerAnnee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/cloturer'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur clôture année');
    }
  }

  static Future<void> archiverAnnee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/archiver'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur archivage année');
    }
  }

  static Future<Map<String, dynamic>> passerEleves(
    int anneeId, {
    required bool passerAutomatique,
    List<int> redoublants = const [],
    List<int> diplomes = const [],
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$anneeId/passer-eleves'),
      headers: await _headers(),
      body: jsonEncode({
        'passer_automatique': passerAutomatique,
        'redoublants':        redoublants,
        'diplomes':           diplomes,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur passage des élèves');
    }
    return data;
  }

  static Future<Map<String, dynamic>> statistiquesAnnee(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/statistiques'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement statistiques année');
  }

  static Future<List<dynamic>> historique() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/historique'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement historique');
  }

  // Aperçu en lecture seule du passage des élèves : moyenne et verdict
  // (admis/redoublant/sans_note) par élève, sans rien modifier en base.
  static Future<Map<String, dynamic>> apercuPassage(int anneeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$anneeId/passage-apercu'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de l\'aperçu de passage');
  }

  // ── Périodes académiques ────────────────────────────────

  static Future<List<dynamic>> listerPeriodes(int anneeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes?annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement périodes');
  }

  static Future<void> creerPeriode({
    required int anneeAcademiqueId,
    required String nom,
    String? code,
    required String dateDebut,
    required String dateFin,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes'),
      headers: await _headers(),
      body: jsonEncode({
        'annee_academique_id': anneeAcademiqueId,
        'nom':                 nom,
        'code':                code,
        'date_debut':          dateDebut,
        'date_fin':            dateFin,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création période');
    }
  }

  static Future<void> ouvrirPeriode(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/ouvrir'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur ouverture période');
    }
  }

  static Future<void> fermerPeriode(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/fermer'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur fermeture période');
    }
  }

  static Future<Map<String, dynamic>> alertesPeriodes() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/alertes'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement alertes périodes');
  }
}