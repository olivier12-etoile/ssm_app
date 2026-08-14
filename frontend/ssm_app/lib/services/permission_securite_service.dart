import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/permission_securite_model.dart';

// Service des sections Utilisateurs & Permissions, Sécurité, Système et
// Actions avancées. Même pattern que les autres services du projet
// (package:http + AuthService.getToken(), voir CLAUDE.md "Pattern headers
// Flutter") : ce projet n'utilise pas Dio.
class PermissionSecuriteService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Permissions ───────────────────────────────────────────

  // Renvoie {roles: [...], modules: {cle: libelle}, matrice: [PermissionRole]}.
  static Future<Map<String, dynamic>> getMatricePermissions() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/permissions'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'roles': (data['roles'] as List).map((e) => e as String).toList(),
        'modules': (data['modules'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
        'matrice': (data['matrice'] as List).map((e) => PermissionRole.fromJson(e as Map<String, dynamic>)).toList(),
      };
    }
    throw Exception('Erreur chargement de la matrice de permissions');
  }

  static Future<PermissionRole> updatePermission(PermissionRole permission) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/permissions'),
      headers: await _headers(),
      body: jsonEncode(permission.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return PermissionRole.fromJson(data['permission'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour de la permission');
  }

  static Future<void> reinitialiserPermissionsDefauts() async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/permissions/reinitialiser'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur réinitialisation des permissions');
    }
  }

  // ── Sécurité ──────────────────────────────────────────────

  static Future<void> changerMotDePasse({
    required String ancien,
    required String nouveau,
    required String confirmation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/changer-mot-de-passe'),
      headers: await _headers(),
      body: jsonEncode({
        'ancien_mot_de_passe': ancien,
        'nouveau_mot_de_passe': nouveau,
        'nouveau_mot_de_passe_confirmation': confirmation,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      // Erreurs de validation Laravel (mot de passe trop faible, etc.) :
      // {message: {champ: [messages]}} plutôt qu'un message simple.
      if (response.statusCode == 422 && data['errors'] != null) {
        final erreurs = (data['errors'] as Map<String, dynamic>).values.expand((v) => (v as List)).map((e) => e.toString());
        throw Exception(erreurs.join(' '));
      }
      throw Exception(data['message'] ?? 'Erreur changement de mot de passe');
    }
  }

  static Future<List<SessionActive>> getSessionsActives() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/sessions'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['sessions'] as List).map((e) => SessionActive.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Erreur chargement des sessions actives');
  }

  static Future<void> revoquerSession(int tokenId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/sessions/$tokenId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur révocation de la session');
    }
  }

  // Renvoie le délai en minutes, ou null si aucune déconnexion automatique n'est configurée.
  static Future<int?> getDeconnexionAutoConfig() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/deconnexion-auto'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['parametre'] as Map<String, dynamic>)['delai_inactivite_minutes'] as int?;
    }
    throw Exception('Erreur chargement du paramètre de déconnexion automatique');
  }

  static Future<void> updateDeconnexionAutoConfig(int? minutes) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/deconnexion-auto'),
      headers: await _headers(),
      body: jsonEncode({'delai_inactivite_minutes': minutes}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur mise à jour du délai de déconnexion automatique');
    }
  }

  // Renvoie {items: List<ConnexionHistorique>, pageActuelle, dernierePage, total}.
  static Future<Map<String, dynamic>> getHistoriqueConnexions({int? userId, int page = 1}) async {
    final query = <String, String>{'page': '$page', if (userId != null) 'user_id': '$userId'};
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/historique-connexions').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'items': (data['data'] as List).map((e) => ConnexionHistorique.fromJson(e as Map<String, dynamic>)).toList(),
        'pageActuelle': data['current_page'] as int? ?? 1,
        'dernierePage': data['last_page'] as int? ?? 1,
        'total': data['total'] as int? ?? 0,
      };
    }
    throw Exception('Erreur chargement de l\'historique des connexions');
  }

  // Renvoie {items: List<ActionJournal>, pageActuelle, dernierePage, total}.
  static Future<Map<String, dynamic>> getJournalActions({
    String? dateDebut,
    String? dateFin,
    int? userId,
    String? module,
    int page = 1,
  }) async {
    final query = <String, String>{
      'page': '$page',
      if (dateDebut != null) 'date_debut': dateDebut,
      if (dateFin != null) 'date_fin': dateFin,
      if (userId != null) 'user_id': '$userId',
      if (module != null) 'module': module,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/parametres/securite/journal-actions').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'items': (data['data'] as List).map((e) => ActionJournal.fromJson(e as Map<String, dynamic>)).toList(),
        'pageActuelle': data['current_page'] as int? ?? 1,
        'dernierePage': data['last_page'] as int? ?? 1,
        'total': data['total'] as int? ?? 0,
      };
    }
    final data = jsonDecode(response.body);
    throw Exception(data['message'] ?? 'Erreur chargement du journal des actions');
  }

  // ── Système ───────────────────────────────────────────────

  static Future<StatutSysteme> getStatutSysteme() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/systeme/statut'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return StatutSysteme.fromJson(jsonDecode(response.body));
    throw Exception('Erreur chargement du statut système');
  }

  static Future<SauvegardeInfo?> getSauvegardeInfo() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/systeme/sauvegarde'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final sauvegarde = data['sauvegarde'] as Map<String, dynamic>?;
      return sauvegarde != null ? SauvegardeInfo.fromJson(sauvegarde) : null;
    }
    throw Exception('Erreur chargement des informations de sauvegarde');
  }

  // ── Actions avancées ──────────────────────────────────────

  static Future<void> archiverAnnee({
    required int anneeScolaireId,
    required String motDePasseConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/actions-avancees/archiver-annee'),
      headers: await _headers(),
      body: jsonEncode({
        'annee_scolaire_id': anneeScolaireId,
        'mot_de_passe_confirmation': motDePasseConfirmation,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur archivage de l\'année scolaire');
    }
  }

  static Future<void> reinitialiserParametres(String motDePasseConfirmation) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/actions-avancees/reinitialiser-parametres'),
      headers: await _headers(),
      body: jsonEncode({'mot_de_passe_confirmation': motDePasseConfirmation}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur réinitialisation des paramètres');
    }
  }
}
