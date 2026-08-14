import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/parametre_ecole_model.dart';

// Service du module Paramètres de l'École (sections Établissement,
// Direction, Identité visuelle, Scolarité, Finance, Notifications).
// Même pattern que les autres services du projet (package:http +
// AuthService.getToken(), voir CLAUDE.md "Pattern headers Flutter") : ce
// projet n'utilise pas Dio.
class ParametreEcoleService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Établissement ────────────────────────────────────────

  static Future<InformationsEtablissement> getInformationsEtablissement() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/etablissement'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return InformationsEtablissement.fromJson(data['etablissement'] as Map<String, dynamic>);
    }
    throw Exception('Erreur chargement des informations de l\'établissement');
  }

  static Future<InformationsEtablissement> updateInformationsEtablissement(
    InformationsEtablissement infos,
  ) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/etablissement'),
      headers: await _headers(),
      body: jsonEncode(infos.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return InformationsEtablissement.fromJson(data['etablissement'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour de l\'établissement');
  }

  // ── Direction ─────────────────────────────────────────────

  static Future<InfosDirecteur> getDirection() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/direction'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return InfosDirecteur.fromJson(data['direction'] as Map<String, dynamic>);
    }
    throw Exception('Erreur chargement des informations de la direction');
  }

  static Future<InfosDirecteur> updateDirection(InfosDirecteur infos) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/direction'),
      headers: await _headers(),
      body: jsonEncode(infos.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return InfosDirecteur.fromJson(data['direction'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour de la direction');
  }

  // ── Identité visuelle ─────────────────────────────────────

  static Future<IdentiteVisuelle> getIdentiteVisuelle() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/identite-visuelle'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return IdentiteVisuelle.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur chargement de l\'identité visuelle');
  }

  // type = 'principal' | 'secondaire'
  static Future<String> uploadLogo(String type, File fichier) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/parametres/identite-visuelle/logo');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['type'] = type;
    request.files.add(await http.MultipartFile.fromPath('logo', fichier.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    if (response.statusCode == 200) return data['url'] as String;
    throw Exception(data['message'] ?? 'Erreur upload du logo');
  }

  static Future<String> uploadCachet(File fichier) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/parametres/identite-visuelle/cachet');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('cachet', fichier.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    if (response.statusCode == 200) return data['url'] as String;
    throw Exception(data['message'] ?? 'Erreur upload du cachet');
  }

  static Future<String> uploadSignature(File fichier) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/parametres/identite-visuelle/signature');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('signature', fichier.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    if (response.statusCode == 200) return data['url'] as String;
    throw Exception(data['message'] ?? 'Erreur upload de la signature');
  }

  static Future<void> updateCouleurs({
    String? couleurPrincipale,
    String? couleurSecondaire,
    String? couleurBoutons,
    String? couleurEntetes,
  }) async {
    final body = <String, dynamic>{};
    if (couleurPrincipale != null) body['couleur_principale'] = couleurPrincipale;
    if (couleurSecondaire != null) body['couleur_secondaire'] = couleurSecondaire;
    if (couleurBoutons != null) body['couleur_boutons'] = couleurBoutons;
    if (couleurEntetes != null) body['couleur_entetes'] = couleurEntetes;

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/identite-visuelle/couleurs'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur mise à jour des couleurs');
    }
  }

  // type = 'principal' | 'secondaire'
  static Future<void> supprimerLogo(String type) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/identite-visuelle/logo/$type'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur suppression du logo');
    }
  }

  // ── Organisation académique ──────────────────────────────

  static Future<ParametreAcademique> getParametreAcademique() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/academique'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return ParametreAcademique.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur chargement des paramètres académiques');
  }

  // Renvoie {parametre, avertissements} : avertissements est une liste de
  // messages informatifs (ex. "le barème ne s'applique qu'aux futures
  // saisies") à afficher après enregistrement, pas des erreurs.
  static Future<Map<String, dynamic>> updateParametreAcademique(
    ParametreAcademique parametre, {
    bool inclureTypeDecoupage = false,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/academique'),
      headers: await _headers(),
      body: jsonEncode(parametre.toJson(inclureTypeDecoupage: inclureTypeDecoupage)),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'parametre': ParametreAcademique.fromJson({'parametre': data['parametre']}),
        'avertissements': (data['avertissements'] as List?)?.map((e) => e.toString()).toList() ?? [],
      };
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour des paramètres académiques');
  }

  // ── Bulletins ─────────────────────────────────────────────

  static Future<ParametreBulletin> getParametreBulletin() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/bulletins'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return ParametreBulletin.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur chargement de la configuration des bulletins');
  }

  static Future<ParametreBulletin> updateParametreBulletin(ParametreBulletin parametre) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/bulletins'),
      headers: await _headers(),
      body: jsonEncode(parametre.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ParametreBulletin.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour de la configuration des bulletins');
  }

  // ── Validation des notes ─────────────────────────────────

  static Future<ParametreValidationNote> getParametreValidationNote() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/validation-notes'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return ParametreValidationNote.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur chargement de la configuration de validation des notes');
  }

  static Future<ParametreValidationNote> updateParametreValidationNote(
    ParametreValidationNote parametre,
  ) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/validation-notes'),
      headers: await _headers(),
      body: jsonEncode(parametre.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ParametreValidationNote.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour de la configuration de validation des notes');
  }

  // ── Classes (réglages par défaut) ────────────────────────

  static Future<Map<String, dynamic>> getParametreClasses() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/classes'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['parametre'] as Map<String, dynamic>;
    }
    throw Exception('Erreur chargement des paramètres des classes');
  }

  static Future<Map<String, dynamic>> updateParametreClasses({
    int? effectifMaxParClasse,
    String? formatCodeClasse,
  }) async {
    final body = <String, dynamic>{};
    if (effectifMaxParClasse != null) body['effectif_max_par_classe'] = effectifMaxParClasse;
    if (formatCodeClasse != null) body['format_code_classe'] = formatCodeClasse;

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/classes'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['parametre'] as Map<String, dynamic>;
    throw Exception(data['message'] ?? 'Erreur mise à jour des paramètres des classes');
  }

  // ── Matières (réglages par défaut) ───────────────────────

  static Future<Map<String, dynamic>> getParametreMatieres() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/matieres'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['parametre'] as Map<String, dynamic>;
    }
    throw Exception('Erreur chargement des paramètres des matières');
  }

  static Future<Map<String, dynamic>> updateParametreMatieres({
    String? systemeCoefficients,
    bool? matieresFacultativesAutorisees,
  }) async {
    final body = <String, dynamic>{};
    if (systemeCoefficients != null) body['systeme_coefficients'] = systemeCoefficients;
    if (matieresFacultativesAutorisees != null) {
      body['matieres_facultatives_autorisees'] = matieresFacultativesAutorisees;
    }

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/matieres'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['parametre'] as Map<String, dynamic>;
    throw Exception(data['message'] ?? 'Erreur mise à jour des paramètres des matières');
  }

  // ── Frais scolaires ───────────────────────────────────────

  static Future<ParametreFrais> getParametreFrais() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/frais'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return ParametreFrais.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur chargement des paramètres financiers');
  }

  static Future<ParametreFrais> updateParametreFrais(ParametreFrais parametre) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/frais'),
      headers: await _headers(),
      body: jsonEncode(parametre.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ParametreFrais.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erreur mise à jour des paramètres financiers');
  }

  // ── Notifications de l'école ─────────────────────────────

  // cible = null (les deux), 'parents' ou 'enseignants'.
  static Future<Map<String, List<TypeNotificationEcole>>> getNotificationsEcole({String? cible}) async {
    final query = cible != null ? '?cible=$cible' : '';
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/notifications-ecole$query'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final types = data['types_notifications'] as Map<String, dynamic>;
      return types.map((cle, valeur) => MapEntry(
            cle,
            (valeur as List)
                .map((e) => TypeNotificationEcole.fromJson(e as Map<String, dynamic>, cible: cle))
                .toList(),
          ));
    }
    throw Exception('Erreur chargement des types de notifications');
  }

  static Future<void> updateNotificationEcole({
    required String cible,
    required String typeEvenement,
    required bool actif,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/parametres/notifications-ecole'),
      headers: await _headers(),
      body: jsonEncode({
        'cible': cible,
        'type_evenement': typeEvenement,
        'actif': actif,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur mise à jour du type de notification');
    }
  }
}
