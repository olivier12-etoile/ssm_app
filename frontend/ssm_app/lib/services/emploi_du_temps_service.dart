import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class EmploiDuTempsService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> parClasse({
    required int classeId,
    required int anneeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/emploi-du-temps/classe?classe_id=$classeId&annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement emploi du temps');
  }

  static Future<Map<String, dynamic>> parEnseignant({
    required int enseignantId,
    required int anneeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/emploi-du-temps/enseignant?enseignant_id=$enseignantId&annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement emploi du temps');
  }

  static Future<void> enregistrer({
    required int classeId,
    required int anneeAcademiqueId,
    required String jour,
    required String heureDebut,
    required String heureFin,
    required int matiereId,
    required int enseignantId,
    String? salle,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':           classeId,
        'annee_academique_id': anneeAcademiqueId,
        'jour':                jour,
        'heure_debut':         heureDebut,
        'heure_fin':           heureFin,
        'matiere_id':          matiereId,
        'enseignant_id':       enseignantId,
        'salle':               salle,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur enregistrement du créneau');
    }
  }

  static Future<void> supprimer(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur suppression du créneau');
    }
  }

  static Future<Map<String, dynamic>> verifierConflits({
    required int enseignantId,
    required int anneeAcademiqueId,
    required String jour,
    required String heureDebut,
    required String heureFin,
    int? excludeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/verifier-conflits'),
      headers: await _headers(),
      body: jsonEncode({
        'enseignant_id':       enseignantId,
        'annee_academique_id': anneeAcademiqueId,
        'jour':                jour,
        'heure_debut':         heureDebut,
        'heure_fin':           heureFin,
        'exclude_id':          excludeId,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur vérification des conflits');
  }

  // Télécharger l'emploi du temps en PDF
  static Future<String> telechargerPdf({
    required int classeId,
    required int anneeId,
  }) async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/emploi-du-temps/pdf-classe?classe_id=$classeId&annee_id=$anneeId'),
      headers: {
        'Accept':        'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur génération du PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier =
        '${dossier.path}/emploi_du_temps_${classeId}_$anneeId.pdf';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }

  // Télécharger l'emploi du temps d'un enseignant en PDF
  // (l'enseignant connecté par défaut si enseignantId est omis)
  static Future<String> telechargerPdfEnseignant({
    required int anneeId,
    int? enseignantId,
  }) async {
    final token = await AuthService.getToken();

    final uri = enseignantId != null
        ? '${AppConfig.apiBaseUrl}/emploi-du-temps/pdf-enseignant?enseignant_id=$enseignantId&annee_id=$anneeId'
        : '${AppConfig.apiBaseUrl}/emploi-du-temps/pdf-enseignant?annee_id=$anneeId';

    final response = await http.get(
      Uri.parse(uri),
      headers: {
        'Accept':        'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur génération du PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier = '${dossier.path}/emploi_du_temps_${enseignantId ?? 'moi'}_$anneeId.pdf';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }
}
