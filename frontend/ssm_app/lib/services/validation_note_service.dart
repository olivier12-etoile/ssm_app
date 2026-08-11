import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/analyse_performance_model.dart';

class ValidationNoteService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Saisies en attente de validation ───────────────────
  static Future<List<SaisieEnAttenteValidation>> getEnAttente() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/validation/en-attente'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (data['saisies'] as List)
        .map((s) => SaisieEnAttenteValidation.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  // ── Détail complet d'une saisie ────────────────────────
  static Future<DetailSaisieValidation> getDetailSaisie(int saisieId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/validation/$saisieId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return DetailSaisieValidation.fromJson(data);
  }

  // ── Valider une saisie ──────────────────────────────────
  static Future<void> valider(int saisieId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/validation/$saisieId/valider'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(jsonDecode(response.body)));
    }
  }

  // ── Rejeter une saisie (motif obligatoire) ─────────────
  static Future<void> rejeter(int saisieId, String motif) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/validation/$saisieId/rejeter'),
      headers: await _headers(),
      body: jsonEncode({'motif': motif}),
    );
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(jsonDecode(response.body)));
    }
  }

  // ── Historique des actions de validation ───────────────
  static Future<Map<String, dynamic>> getHistorique({
    int? classeId,
    int? matiereId,
    int? periodeId,
    String? action,
    String? dateDebut,
    String? dateFin,
    int page = 1,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (classeId != null) query['classe_id'] = '$classeId';
    if (matiereId != null) query['matiere_id'] = '$matiereId';
    if (periodeId != null) query['periode_id'] = '$periodeId';
    if (action != null) query['action'] = action;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/validation/historique').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return data as Map<String, dynamic>;
  }

  // ── Déverrouiller une saisie déjà validée ──────────────
  static Future<void> deverrouiller({
    required int matiereId,
    required int classeId,
    required int periodeId,
    required String motif,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/deverrouillage'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id': classeId,
        'matiere_id': matiereId,
        'periode_id': periodeId,
        'motif': motif,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(jsonDecode(response.body)));
    }
  }

  // ── Résumé d'analyse (vue d'ensemble) ──────────────────
  static Future<ResumeAnalyse> getResumeAnalyse(int periodeId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/resume')
        .replace(queryParameters: {'periode_id': '$periodeId'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return ResumeAnalyse.fromJson(data);
  }

  static Future<List<ClasseIncomplete>> getClassesIncompletes(int periodeId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/classes-incompletes')
        .replace(queryParameters: {'periode_id': '$periodeId'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (data['classes'] as List).map((c) => ClasseIncomplete.fromJson(c as Map<String, dynamic>)).toList();
  }

  // Non listé dans le brief mais nécessaire à la section "Matières non
  // validées" de analyse_performance_screen.dart et au dashboard.
  static Future<List<ClasseMatieresNonValidees>> getMatieresNonValidees(int periodeId, {int? classeId}) async {
    final query = {'periode_id': '$periodeId'};
    if (classeId != null) query['classe_id'] = '$classeId';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/matieres-non-validees').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (data['classes'] as List)
        .map((c) => ClasseMatieresNonValidees.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  static Future<List<EnseignantRetard>> getEnseignantsEnRetard(int periodeId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/enseignants-en-retard')
        .replace(queryParameters: {'periode_id': '$periodeId'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (data['enseignants'] as List).map((e) => EnseignantRetard.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<EleveNiveau>> getElevesFaibles(int periodeId, {double seuil = 8}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/eleves-faibles')
        .replace(queryParameters: {'periode_id': '$periodeId', 'seuil': '$seuil'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return elevesNiveauAvecRang(data['eleves'] as List? ?? []);
  }

  static Future<List<EleveNiveau>> getElevesExcellents(int periodeId, {double seuil = 16}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/eleves-excellents')
        .replace(queryParameters: {'periode_id': '$periodeId', 'seuil': '$seuil'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return elevesNiveauAvecRang(data['eleves'] as List? ?? []);
  }

  static Future<List<ClassementClasse>> getClassementClasses(int periodeId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/analyse/classement-classes')
        .replace(queryParameters: {'periode_id': '$periodeId'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (data['classement'] as List).map((c) => ClassementClasse.fromJson(c as Map<String, dynamic>)).toList();
  }

  // ── Export de l'analyse de performance (PDF/Excel) ──────
  // Non listé dans le brief du service, mais nécessaire aux boutons
  // "PDF/Excel" demandés sur analyse_performance_screen.dart.
  static Future<Uint8List> exporterAnalysePerformance({
    required int periodeId,
    String format = 'pdf',
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/export/analyse-performance')
        .replace(queryParameters: {'periode_id': '$periodeId', 'format': format});

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
      throw Exception("Erreur lors de l'export de l'analyse de performance");
    }
    return response.bodyBytes;
  }

  static String _messageErreur(dynamic data) {
    if (data is Map && data['errors'] is Map) {
      final erreurs = (data['errors'] as Map).values.first;
      if (erreurs is List && erreurs.isNotEmpty) {
        return erreurs.first.toString();
      }
    }
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Une erreur est survenue';
  }
}
