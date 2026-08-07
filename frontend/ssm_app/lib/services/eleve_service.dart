import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class EleveService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> tableauDeBord() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/tableau-de-bord'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement tableau de bord');
  }

  static Future<Map<String, dynamic>> listeIntelligente(String type) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/liste-intelligente?type=$type'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de la liste intelligente');
  }

  // Télécharge le PDF d'une liste intelligente et retourne le chemin local.
  static Future<String> telechargerListeIntelligentePdf(String type) async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/liste-intelligente/pdf?type=$type'),
      headers: {'Accept': 'application/pdf', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du PDF');
    }
    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/liste_$type.pdf';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  // Télécharge le CSV (compatible Excel) d'une liste intelligente.
  static Future<String> telechargerListeIntelligenteExcel(String type) async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/liste-intelligente/excel?type=$type'),
      headers: {'Accept': 'text/csv', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du fichier Excel');
    }
    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/liste_$type.csv';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  static Future<Map<String, dynamic>> lister({
    int? classeId,
    String? sexe,
    int? anneeId,
    String? statut,
    bool? enRegle,
    String? recherche,
    int page = 1,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (classeId != null) params['classe_id'] = '$classeId';
    if (sexe != null) params['sexe'] = sexe;
    if (anneeId != null) params['annee_id'] = '$anneeId';
    if (statut != null) params['statut'] = statut;
    if (enRegle != null) params['en_regle'] = enRegle ? '1' : '0';
    if (recherche != null && recherche.isNotEmpty) params['search'] = recherche;

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/eleves',
    ).replace(queryParameters: params);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des élèves');
  }

  static Future<Map<String, dynamic>> details(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de l\'élève');
  }

  static Future<Map<String, dynamic>> creer({
    required String nom,
    required String prenom,
    required String sexe,
    required String dateNaissance,
    String? lieuNaissance,
    String? nationalite,
    required int classeId,
    required int anneeAcademiqueId,
    int? numeroAppel,
    String? dateInscription,
    File? photo,
  }) async {
    final champs = {
      'nom': nom,
      'prenom': prenom,
      'sexe': sexe,
      'date_naissance': dateNaissance,
      'lieu_naissance': ?lieuNaissance,
      'nationalite': ?nationalite,
      'classe_id': '$classeId',
      'annee_academique_id': '$anneeAcademiqueId',
      'numero_appel': ?numeroAppel?.toString(),
      'date_inscription': ?dateInscription,
    };

    if (photo == null) {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/eleves'),
        headers: await _headers(),
        body: jsonEncode(champs),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(data['message'] ?? 'Erreur création élève');
      }
      return data;
    }

    final token = await AuthService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/eleves'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(champs);
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur création élève');
    }
    return data;
  }

  static Future<void> modifier(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final erreur = jsonDecode(response.body);
      throw Exception(erreur['message'] ?? 'Erreur modification élève');
    }
  }

  static Future<void> changerStatut(
    int id,
    String statut, {
    String? motif,
  }) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id/statut'),
      headers: await _headers(),
      body: jsonEncode({'statut': statut, 'motif': motif}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur changement de statut');
    }
  }

  static Future<String> uploaderPhoto(int id, File photo) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id/photo');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return data['photo_url'] as String;
    }
    throw Exception('Erreur upload photo');
  }

  static Future<void> gererParents(
    int id,
    List<Map<String, dynamic>> parents,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id/parents'),
      headers: await _headers(),
      body: jsonEncode(parents),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur mise à jour des parents');
    }
  }

  static Future<void> uploaderDocument(
    int id, {
    required String nom,
    required String type,
    required File fichier,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id/documents');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['nom'] = nom;
    request.fields['type'] = type;
    request.files.add(
      await http.MultipartFile.fromPath('fichier', fichier.path),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      final data = jsonDecode(body);
      throw Exception(data['message'] ?? 'Erreur upload document');
    }
  }

  static Future<void> supprimerDocument(int eleveId, int docId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/$eleveId/documents/$docId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur suppression document');
    }
  }

  static Future<List<dynamic>> chronologie(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/$id/chronologie'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de la chronologie');
  }

  // Télécharge le PDF de la liste des élèves et retourne le chemin local.
  static Future<String> exporterPdf({int? classeId, String? statut}) async {
    final token = await AuthService.getToken();
    final params = <String, String>{};
    if (classeId != null) params['classe_id'] = '$classeId';
    if (statut != null) params['statut'] = statut;

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/eleves/exporter-pdf',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/liste_eleves.pdf';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  // Télécharge le CSV (compatible Excel) de la liste des élèves.
  static Future<String> exporterExcel({int? classeId}) async {
    final token = await AuthService.getToken();
    final params = <String, String>{};
    if (classeId != null) params['classe_id'] = '$classeId';

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/eleves/exporter-excel',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(
      uri,
      headers: {'Accept': 'text/csv', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du fichier Excel');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/eleves.csv';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  static Future<List<dynamic>> elevesParClasse(int classeId, int? anneeId) async {
    final query = anneeId != null ? '?annee_id=$anneeId' : '';
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/eleves/classe/$classeId$query'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement élèves');
  }
}
