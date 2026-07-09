import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class FraisScolaireService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerFrais({
    required int classeId,
    required int anneeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/frais-scolaires?classe_id=$classeId&annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement frais scolaires');
  }

  static Future<void> enregistrerFrais({
    required int classeId,
    required int anneeAcademiqueId,
    required String type,
    required double montantTotal,
    double? montantTranche1,
    double? montantTranche2,
    double? montantTranche3,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':           classeId,
        'annee_academique_id': anneeAcademiqueId,
        'type':                type,
        'montant_total':       montantTotal,
        'montant_tranche_1':   montantTranche1,
        'montant_tranche_2':   montantTranche2,
        'montant_tranche_3':   montantTranche3,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur enregistrement des frais scolaires');
    }
  }

  static Future<Map<String, dynamic>> situationEleve({
    required int eleveId,
    required int anneeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/frais-scolaires/situation/$eleveId?annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de la situation de l\'élève');
  }

  static Future<Map<String, dynamic>> situationClasse({
    required int classeId,
    required int anneeId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/frais-scolaires/situation-classe?classe_id=$classeId&annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de la situation de la classe');
  }

  static Future<Map<String, dynamic>> rapportFinancier({
    required int anneeId,
    int? mois,
  }) async {
    final uri = mois != null
        ? '${AppConfig.apiBaseUrl}/frais-scolaires/rapport?annee_id=$anneeId&mois=$mois'
        : '${AppConfig.apiBaseUrl}/frais-scolaires/rapport?annee_id=$anneeId';

    final response = await http.get(
      Uri.parse(uri),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement du rapport financier');
  }

  // Télécharger le rapport financier en PDF
  static Future<String> telechargerRapportPdf({
    required int anneeId,
    int? mois,
  }) async {
    final token = await AuthService.getToken();

    final uri = mois != null
        ? '${AppConfig.apiBaseUrl}/frais-scolaires/rapport-pdf?annee_id=$anneeId&mois=$mois'
        : '${AppConfig.apiBaseUrl}/frais-scolaires/rapport-pdf?annee_id=$anneeId';

    final response = await http.get(
      Uri.parse(uri),
      headers: {
        'Accept':        'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur génération du rapport PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier =
        '${dossier.path}/rapport_financier_$anneeId${mois != null ? '_$mois' : ''}.pdf';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }
}
