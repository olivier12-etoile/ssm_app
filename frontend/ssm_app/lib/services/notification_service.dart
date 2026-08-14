import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/notification_model.dart';

class NotificationService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Modèles de messages ──────────────────────────────────
  static Future<List<ModeleMessage>> getModeles({CategorieNotification? categorie}) async {
    final query = <String, String>{};
    if (categorie != null) query['categorie'] = categorie.valeurApi;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/modeles')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement des modèles');
    }
    return (data['modeles'] as List)
        .map((m) => ModeleMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  static Future<ModeleMessage> creerModele(ModeleMessage modele) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/modeles'),
      headers: await _headers(),
      body: jsonEncode(modele.toJsonCreation()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur création du modèle');
    }
    return ModeleMessage.fromJson(data['modele'] as Map<String, dynamic>);
  }

  static Future<ModeleMessage> modifierModele(int id, ModeleMessage modele) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/modeles/$id'),
      headers: await _headers(),
      body: jsonEncode(modele.toJsonCreation()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur modification du modèle');
    }
    return ModeleMessage.fromJson(data['modele'] as Map<String, dynamic>);
  }

  static Future<void> supprimerModele(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/modeles/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur suppression du modèle');
    }
  }

  // ── Aperçus (avant confirmation d'envoi) ─────────────────
  static Future<int> apercuDestinataires({
    required TypeCible typeCible,
    Map<String, dynamic>? cibles,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/apercu-destinataires'),
      headers: await _headers(),
      body: jsonEncode({
        'type_cible': typeCible.valeurApi,
        'cibles': cibles,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur calcul des destinataires');
    }
    return data['nombre_destinataires'] as int;
  }

  // Retourne {eleve, variables_utilisees, variables_resolues, apercu}
  // (voir NotificationController::apercuMessage côté API).
  static Future<Map<String, dynamic>> apercuMessage({
    required String contenu,
    required int eleveIdExemple,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/apercu-message'),
      headers: await _headers(),
      body: jsonEncode({
        'contenu': contenu,
        'eleve_id_exemple': eleveIdExemple,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Erreur génération de l'aperçu");
    }
    return data as Map<String, dynamic>;
  }

  // ── Notifications ─────────────────────────────────────────
  static Future<NotificationSSM> creerNotification(NotificationSSM notification) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications'),
      headers: await _headers(),
      body: jsonEncode(notification.toJsonCreation()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur création de la notification');
    }
    return NotificationSSM.fromJson(data['notification'] as Map<String, dynamic>);
  }

  // Liste des notifications récentes (première page, 20 résultats côté API).
  static Future<List<NotificationSSM>> getNotifications({
    String? statut,
    String? canal,
    String? categorie,
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{};
    if (statut != null) query['statut'] = statut;
    if (canal != null) query['canal'] = canal;
    if (categorie != null) query['categorie'] = categorie;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement des notifications');
    }

    final page = data['notifications'] as Map<String, dynamic>;
    return (page['data'] as List)
        .map((n) => NotificationSSM.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  // Historique paginé (écran historique_notifications_screen.dart) — contrairement
  // à getNotifications() qui ne renvoie que la première page, celle-ci expose
  // la pagination complète pour le scroll infini, plus le tri et la recherche
  // par titre.
  static Future<Map<String, dynamic>> getHistorique({
    String? statut,
    String? canal,
    String? categorie,
    String? recherche,
    String? dateDebut,
    String? dateFin,
    String tri = 'recent', // 'recent' | 'destinataires'
    int page = 1,
  }) async {
    final query = <String, String>{'tri': tri, 'page': '$page'};
    if (statut != null) query['statut'] = statut;
    if (canal != null) query['canal'] = canal;
    if (categorie != null) query['categorie'] = categorie;
    if (recherche != null && recherche.isNotEmpty) query['recherche'] = recherche;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications').replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Erreur chargement de l'historique");
    }

    final page_ = data['notifications'] as Map<String, dynamic>;
    return {
      'items': (page_['data'] as List)
          .map((n) => NotificationSSM.fromJson(n as Map<String, dynamic>))
          .toList(),
      'page_actuelle': page_['current_page'] as int,
      'derniere_page': page_['last_page'] as int,
    };
  }

  // Télécharge l'export CSV (compatible Excel) de l'historique filtré et
  // retourne le chemin local du fichier.
  static Future<String> telechargerExportExcel({
    String? statut,
    String? canal,
    String? categorie,
    String? recherche,
    String? dateDebut,
    String? dateFin,
    String tri = 'recent',
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{'tri': tri};
    if (statut != null) query['statut'] = statut;
    if (canal != null) query['canal'] = canal;
    if (categorie != null) query['categorie'] = categorie;
    if (recherche != null && recherche.isNotEmpty) query['recherche'] = recherche;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/export-excel')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(
      uri,
      headers: {'Accept': 'text/csv', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception("Erreur génération de l'export");
    }

    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/notifications.csv';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  static Future<NotificationSSM> getDetailNotification(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/$id'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement de la notification');
    }
    return NotificationSSM.fromJson(data['notification'] as Map<String, dynamic>);
  }

  static Future<void> annulerProgrammee(int id) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/$id/annuler'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur annulation de la notification');
    }
  }

  // ── Paramètres des déclencheurs automatiques ─────────────
  static Future<List<ParametreDeclencheur>> getParametresDeclencheurs() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/parametres-declencheurs'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement des paramètres');
    }
    return (data['declencheurs'] as List)
        .map((d) => ParametreDeclencheur.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateParametreDeclencheur(String cle, bool valeur) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/notifications/parametres-declencheurs'),
      headers: await _headers(),
      body: jsonEncode({'cle': cle, 'valeur': valeur}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur mise à jour du paramètre');
    }
  }
}
