import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class UtilisateurService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Fiche d'un utilisateur ─────────────────────────────
  static Future<Map<String, dynamic>> obtenir(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/$id'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement utilisateur');
  }

  // ── Tableau de bord des utilisateurs ──────────────────
  static Future<Map<String, dynamic>> tableauDeBord() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/tableau-de-bord'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement tableau de bord');
  }

  // ── Liste paginée des utilisateurs ────────────────────
  static Future<Map<String, dynamic>> lister({
    String? role,
    bool? actif,
    String? recherche,
    String tri = 'created_at',
    int page = 1,
  }) async {
    final query = <String, String>{
      'tri':  tri,
      'page': '$page',
    };
    if (role != null)      query['role']   = role;
    if (actif != null)     query['actif']  = actif.toString();
    if (recherche != null && recherche.isNotEmpty) query['search'] = recherche;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement utilisateurs');
  }

  // ── Créer un utilisateur ──────────────────────────────
  static Future<Map<String, dynamic>> creer({
    required String nom,
    required String prenom,
    required String email,
    required String role,
    String? sexe,
    String? telephone,
    String? adresse,
    String? fonction,
    File? photo,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs');

    if (photo != null) {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept']        = 'application/json';

      request.fields['name']  = nom;
      request.fields['prenom'] = prenom;
      request.fields['email'] = email;
      request.fields['role']  = role;
      if (sexe != null)      request.fields['sexe']      = sexe;
      if (telephone != null) request.fields['telephone'] = telephone;
      if (adresse != null)   request.fields['adresse']   = adresse;
      if (fonction != null)  request.fields['fonction']  = fonction;
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

      final reponse    = await request.send();
      final corpsBrut  = await reponse.stream.bytesToString();
      final data       = jsonDecode(corpsBrut);
      if (reponse.statusCode == 201) return data;
      throw Exception(data['message'] ?? 'Erreur création utilisateur');
    }

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'name':      nom,
        'prenom':    prenom,
        'email':     email,
        'role':      role,
        'sexe':      sexe,
        'telephone': telephone,
        'adresse':   adresse,
        'fonction':  fonction,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Erreur création utilisateur');
  }

  // ── Modifier un utilisateur ───────────────────────────
  static Future<void> modifier(
    int id, {
    String? nom,
    String? prenom,
    String? telephone,
    String? email,
    String? role,
    String? adresse,
    String? fonction,
    File? photo,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/$id');

    if (photo != null) {
      final token = await AuthService.getToken();
      // PHP ne peuple pas $_FILES pour une requête PATCH multipart :
      // on envoie donc en POST avec le champ _method (spoofing Laravel).
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept']        = 'application/json';

      request.fields['_method'] = 'PATCH';
      if (nom != null)       request.fields['name']      = nom;
      if (prenom != null)    request.fields['prenom']    = prenom;
      if (telephone != null) request.fields['telephone'] = telephone;
      if (email != null)     request.fields['email']     = email;
      if (role != null)      request.fields['role']      = role;
      if (adresse != null)   request.fields['adresse']   = adresse;
      if (fonction != null)  request.fields['fonction']  = fonction;
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

      final reponse = await request.send();
      if (reponse.statusCode != 200) {
        final corpsBrut = await reponse.stream.bytesToString();
        final data = jsonDecode(corpsBrut);
        throw Exception(data['message'] ?? 'Erreur modification utilisateur');
      }
      return;
    }

    final donnees = <String, dynamic>{};
    if (nom != null)       donnees['name']      = nom;
    if (prenom != null)    donnees['prenom']    = prenom;
    if (telephone != null) donnees['telephone'] = telephone;
    if (email != null)     donnees['email']     = email;
    if (role != null)      donnees['role']      = role;
    if (adresse != null)   donnees['adresse']   = adresse;
    if (fonction != null)  donnees['fonction']  = fonction;

    final response = await http.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(donnees),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur modification utilisateur');
    }
  }

  // ── Désactiver un utilisateur ──────────────────────────
  static Future<void> desactiver(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/$id/desactiver'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur désactivation utilisateur');
    }
  }

  // ── Réactiver un utilisateur ───────────────────────────
  static Future<void> reactiver(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/$id/reactiver'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur réactivation utilisateur');
    }
  }

  // ── Réinitialiser le mot de passe ──────────────────────
  static Future<Map<String, dynamic>> reinitialiserMotDePasse(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/$id/reinitialiser-mdp'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur réinitialisation mot de passe');
  }

  // ── Importer des utilisateurs depuis un fichier Excel ──
  static Future<Map<String, dynamic>> importerExcel(File fichier) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/importer');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept']        = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('fichier', fichier.path));

    final reponse   = await request.send();
    final corpsBrut = await reponse.stream.bytesToString();
    final data      = jsonDecode(corpsBrut);
    if (reponse.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Erreur import Excel');
  }

  // ── Exporter la liste des utilisateurs en PDF ──────────
  static Future<String> exporterPdf({String? role, bool? actif}) async {
    final token = await AuthService.getToken();

    final query = <String, String>{};
    if (role != null)  query['role']  = role;
    if (actif != null) query['actif'] = actif.toString();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/exporter-pdf')
        .replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {
        'Accept':        'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier = '${dossier.path}/utilisateurs.pdf';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }

  // ── Exporter la liste des utilisateurs en Excel (CSV) ──
  static Future<String> exporterExcel({String? role}) async {
    final token = await AuthService.getToken();

    final query = <String, String>{};
    if (role != null) query['role'] = role;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/exporter-excel')
        .replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {
        'Accept':        'text/csv',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export Excel');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier = '${dossier.path}/utilisateurs.csv';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }

  // ── Changer mot de passe (utilisé par changement_mdp_screen.dart) ─
  static Future<void> changerMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/changer-mot-de-passe'),
      headers: await _headers(),
      body: jsonEncode({
        'ancien_mot_de_passe':             ancienMotDePasse,
        'nouveau_mot_de_passe':            nouveauMotDePasse,
        'nouveau_mot_de_passe_confirmation': nouveauMotDePasse,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur changement mot de passe');
    }
  }
}
