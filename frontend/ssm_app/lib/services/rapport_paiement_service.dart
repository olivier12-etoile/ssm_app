import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/rapport_paiement_model.dart';

class RapportPaiementService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _headersFichier(String format) async {
    final token = await AuthService.getToken();
    return {
      'Accept': format == 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'application/pdf',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Situation financière par classe ─────────────────────

  static Future<SituationClasse> getSituationClasse(int classeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/situation-classe/$classeId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement de la situation de la classe');
    }
    return SituationClasse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<SituationClasse>> getToutesLesSituationsClasses({int? anneeScolaireId}) async {
    final query = <String, String>{};
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/paiements/situation-classe')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur chargement des situations par classe');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((c) => SituationClasse.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<List<ImpayeClasse>> getImpayesClasse(int classeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/situation-classe/$classeId/impayes'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement des impayés de la classe');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((e) => ImpayeClasse.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Uint8List> exportSituationClassePdf(int classeId) async {
    return _telecharger('/paiements/situation-classe/$classeId/export-pdf', 'pdf');
  }

  static Future<Uint8List> exportSituationClasseExcel(int classeId) async {
    return _telecharger('/paiements/situation-classe/$classeId/export-excel', 'excel');
  }

  static Future<Uint8List> exportToutesSituationsPdf() async {
    return _telecharger('/paiements/situation-classe/export-pdf', 'pdf');
  }

  static Future<Uint8List> exportToutesSituationsExcel() async {
    return _telecharger('/paiements/situation-classe/export-excel', 'excel');
  }

  // ── Rapports d'encaissement ──────────────────────────────

  static Future<RapportPaiement> getRapportJournalier(String date) async {
    final data = await _getJson('/paiements/rapports/journalier', {'date': date});
    return RapportPaiement.fromJson('journalier', data);
  }

  static Future<RapportPaiement> getRapportHebdomadaire(String dateDebut) async {
    final data = await _getJson('/paiements/rapports/hebdomadaire', {'date_debut': dateDebut});
    return RapportPaiement.fromJson('hebdomadaire', data);
  }

  static Future<RapportPaiement> getRapportMensuel(int mois, int annee) async {
    final data = await _getJson('/paiements/rapports/mensuel', {'mois': '$mois', 'annee': '$annee'});
    return RapportPaiement.fromJson('mensuel', data);
  }

  static Future<RapportPaiement> getRapportAnnuel(int anneeScolaireId) async {
    final data = await _getJson('/paiements/rapports/annuel', {'annee_scolaire_id': '$anneeScolaireId'});
    return RapportPaiement.fromJson('annuel', data);
  }

  static Future<RapportPaiement> getRapportPersonnalise(String dateDebut, String dateFin) async {
    final data = await _getJson('/paiements/rapports/personnalise', {
      'date_debut': dateDebut,
      'date_fin': dateFin,
    });
    return RapportPaiement.fromJson('personnalise', data);
  }

  static Future<Uint8List> exportRapport({
    required String type,
    required String format,
    Map<String, String> parametres = const {},
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{'type': type, 'format': format, ...parametres};

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/paiements/rapports/export')
        .replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {
        'Accept': format == 'excel'
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export du rapport de paiements');
    }
    return response.bodyBytes;
  }

  // ── Aides internes ───────────────────────────────────────

  static Future<Map<String, dynamic>> _getJson(String chemin, Map<String, String> query) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$chemin').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur chargement du rapport');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Uint8List> _telecharger(String chemin, String format) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$chemin'),
      headers: await _headersFichier(format),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du fichier');
    }
    return response.bodyBytes;
  }
}
