import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/dashboard_frais_model.dart';

class DashboardFraisService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> resume() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/resume'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement du résumé financier');
  }

  static Future<Map<String, dynamic>> debiteurs({
    int? classeId,
    int? joursRetardMin,
    double? pourcentageImpayeMin,
    bool? aucunPaiement,
    String? tri,
  }) async {
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';
    if (joursRetardMin != null) query['jours_retard_min'] = '$joursRetardMin';
    if (pourcentageImpayeMin != null) query['pourcentage_impaye_min'] = '$pourcentageImpayeMin';
    if (aucunPaiement != null) query['aucun_paiement'] = aucunPaiement ? '1' : '0';
    if (tri != null) query['tri'] = tri;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/debiteurs')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des débiteurs');
  }

  static Future<Map<String, dynamic>> elevesAJour({int? classeId}) async {
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/a-jour')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des élèves à jour');
  }

  static Future<Map<String, dynamic>> statistiques() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/statistiques'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des statistiques financières');
  }

  static Future<Map<String, dynamic>> journal({
    int? userId,
    String? action,
    String? dateDebut,
    String? dateFin,
    int page = 1,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (userId != null) query['user_id'] = '$userId';
    if (action != null) query['action'] = action;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/journal')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement du journal des opérations');
  }

  // Télécharge le rapport financier (PDF ou Excel) et retourne le chemin local.
  // Si [periode] et [dateDebut] sont tous deux omis alors que
  // [anneeScolaireId] est fourni, le backend couvre toute la durée de cette
  // année scolaire (utile pour exporter le rapport d'une année passée).
  static Future<String> telechargerRapport({
    String? periode,
    String? dateDebut,
    String? dateFin,
    String format = 'pdf',
    int? anneeScolaireId,
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{'format': format};
    if (periode != null) query['periode'] = periode;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/rapport')
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
      throw Exception('Erreur génération du rapport financier');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final extension = format == 'excel' ? 'xlsx' : 'pdf';
    final chemin = '${dossier.path}/rapport_financier_$periode.$extension';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  static Future<String> telechargerDebiteursExcel({int? classeId}) async {
    return _telechargerExportDebiteurs('export-excel', classeId, 'xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  static Future<String> telechargerDebiteursPdf({int? classeId}) async {
    return _telechargerExportDebiteurs('export-pdf', classeId, 'pdf', 'application/pdf');
  }

  static Future<String> _telechargerExportDebiteurs(
    String endpoint,
    int? classeId,
    String extension,
    String accept,
  ) async {
    final token = await AuthService.getToken();
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/debiteurs/$endpoint')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(
      uri,
      headers: {'Accept': accept, 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export des débiteurs');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/debiteurs.$extension';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  // ════════════════════════════════════════════════════════
  // API typée (ResumeFinancier / EleveDebiteur / StatistiquesFrais) —
  // utilisée par dashboard_frais_screen.dart, debiteurs_screen.dart et
  // statistiques_frais_screen.dart. Coexiste avec les méthodes ci-dessus
  // (resume/debiteurs/statistiques/telecharger...), déjà utilisées par
  // gestion_paiements_screen.dart et statistiques_screen.dart.
  // ════════════════════════════════════════════════════════

  static Future<ResumeFinancier> getResume() async {
    final data = await resume();
    return ResumeFinancier.fromJson(data);
  }

  static Future<List<EleveDebiteur>> getDebiteurs({
    int? classeId,
    int? joursRetardMin,
    double? pourcentageImpayeMin,
    bool? aucunPaiement,
    String? tri,
  }) async {
    final data = await debiteurs(
      classeId: classeId,
      joursRetardMin: joursRetardMin,
      pourcentageImpayeMin: pourcentageImpayeMin,
      aucunPaiement: aucunPaiement,
      tri: tri,
    );
    return (data['debiteurs'] as List)
        .map((e) => EleveDebiteur.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> getElevesAJour({int? classeId}) {
    return elevesAJour(classeId: classeId);
  }

  static Future<StatistiquesFrais> getStatistiques() async {
    final data = await statistiques();
    return StatistiquesFrais.fromJson(data);
  }

  // ── Rapport financier téléchargeable (retourne les octets bruts) ──
  static Future<Uint8List> getRapport({
    String? periode,
    String? dateDebut,
    String? dateFin,
    String format = 'pdf',
    int? anneeScolaireId,
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{'format': format};
    if (periode != null) query['periode'] = periode;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/rapport')
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
      throw Exception('Erreur génération du rapport financier');
    }
    return response.bodyBytes;
  }

  static Future<Uint8List> exportDebiteursExcel({int? classeId}) {
    return _exportDebiteursOctets(
      'export-excel',
      classeId,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<Uint8List> exportDebiteursPdf({int? classeId}) {
    return _exportDebiteursOctets('export-pdf', classeId, 'application/pdf');
  }

  static Future<Uint8List> _exportDebiteursOctets(
    String endpoint,
    int? classeId,
    String accept,
  ) async {
    final token = await AuthService.getToken();
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/dashboard/debiteurs/$endpoint')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(
      uri,
      headers: {'Accept': accept, 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export des débiteurs');
    }
    return response.bodyBytes;
  }
}
