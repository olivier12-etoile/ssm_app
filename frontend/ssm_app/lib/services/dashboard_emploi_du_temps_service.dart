import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/emploi_du_temps_service.dart';
import '../models/emploi_du_temps_model.dart';
import '../models/dashboard_emploi_du_temps_model.dart';

class DashboardEmploiDuTempsService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Dashboard ─────────────────────────────────────────────

  static Future<ResumeEmploiDuTemps> getResume(int periodeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/dashboard/resume?periode_id=$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return ResumeEmploiDuTemps.fromJson(data as Map<String, dynamic>);
    throw Exception(_messageErreur(data));
  }

  // ── Consultation ──────────────────────────────────────────

  // Planning personnel de l'enseignant connecté. La ligne "enseignant" de
  // chaque carte de séance (normalement redondante — c'est toujours
  // l'utilisateur connecté) est réutilisée pour afficher la classe
  // concernée, seule info qu'il manque à GrilleEmploiDuTempsWidget pour
  // ce cas d'usage précis.
  static Future<EmploiDuTemps> getMonEmploiDuTemps(int periodeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/consultation/mon-emploi-du-temps?periode_id=$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(_messageErreur(data));

    final seances = (data['seances'] as List? ?? []).map((s) {
      final json = Map<String, dynamic>.from(s as Map<String, dynamic>);
      final classeNom = (json['emploi_du_temps'] as Map<String, dynamic>?)?['classe']?['nom'] as String?;
      if (classeNom != null) json['enseignant_nom'] = classeNom;
      return json;
    }).toList();

    return EmploiDuTemps.fromApiResponse({...data, 'seances': seances});
  }

  // Emploi du temps d'une classe pour une période, ou null si aucun n'a
  // encore été créé — délègue à EmploiDuTempsService (module création)
  // pour ne pas dupliquer la logique de parsing de la grille.
  static Future<EmploiDuTemps?> getEmploiDuTempsClasse(int classeId, int periodeId) {
    return EmploiDuTempsService.consulterParClasse(classeId: classeId, periodeId: periodeId);
  }

  // Liste de toutes les classes avec statut et % de complétion de leur
  // emploi du temps — pas de modèle dédié demandé, forme brute réutilisée
  // telle quelle par l'écran (classe_id, classe_nom, statut, ...).
  static Future<List<Map<String, dynamic>>> getToutesLesClasses(int periodeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/consultation/toutes-classes?periode_id=$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['classes'] as List).map((c) => c as Map<String, dynamic>).toList();
    }
    throw Exception(_messageErreur(data));
  }

  // ── Statistiques ──────────────────────────────────────────

  static Future<List<HeuresParEntite>> getHeuresParEnseignant(int periodeId) async {
    final data = await _getJson('/statistiques/heures-enseignant?periode_id=$periodeId');
    return (data['heures_par_enseignant'] as List).map((h) => HeuresParEntite.fromJson(h as Map<String, dynamic>)).toList();
  }

  static Future<List<HeuresParEntite>> getHeuresParMatiere(int periodeId) async {
    final data = await _getJson('/statistiques/heures-matiere?periode_id=$periodeId');
    return (data['heures_par_matiere'] as List).map((h) => HeuresParEntite.fromJson(h as Map<String, dynamic>)).toList();
  }

  static Future<List<HeuresParEntite>> getHeuresParClasse(int periodeId) async {
    final data = await _getJson('/statistiques/heures-classe?periode_id=$periodeId');
    return (data['heures_par_classe'] as List).map((h) => HeuresParEntite.fromJson(h as Map<String, dynamic>)).toList();
  }

  // {taux_completion_moyen: int, details_par_classe: [{classe_id, classe_nom, pourcentage}]}
  static Future<Map<String, dynamic>> getTauxCompletion(int periodeId) async {
    return _getJson('/statistiques/taux-completion?periode_id=$periodeId');
  }

  // ── Disponibilité ─────────────────────────────────────────

  static Future<List<DisponibiliteEnseignant>> getDisponibiliteEnseignant(int enseignantId, int periodeId) async {
    final data = await _getJson('/disponibilite/$enseignantId?periode_id=$periodeId');
    final disponibilite = data['disponibilite'] as Map<String, dynamic>? ?? {};

    final resultat = <DisponibiliteEnseignant>[];
    disponibilite.forEach((jour, creneaux) {
      for (final c in (creneaux as List)) {
        resultat.add(DisponibiliteEnseignant.fromJson(jour, c as Map<String, dynamic>));
      }
    });
    return resultat;
  }

  // Enseignants disponibles/occupés sur un jour + créneau donné — utile
  // pour trouver rapidement un remplaçant.
  static Future<List<DisponibiliteEnseignant>> getDisponibiliteCreneau({
    required String jour,
    required int creneauId,
    required int periodeId,
  }) async {
    final data = await _getJson(
      '/disponibilite/creneau?periode_id=$periodeId&jour=$jour&creneau_horaire_id=$creneauId',
    );
    return (data['enseignants'] as List)
        .map((e) => DisponibiliteEnseignant.pourEnseignant(jour: jour, creneauId: creneauId, json: e as Map<String, dynamic>))
        .toList();
  }

  // ── Remplacements ─────────────────────────────────────────

  static Future<Map<String, dynamic>> creerRemplacement({
    required int seanceId,
    required DateTime dateRemplacement,
    required int enseignantRemplacantId,
    String? motif,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/remplacements'),
      headers: await _headers(),
      body: jsonEncode({
        'seance_id': seanceId,
        'date_remplacement': EvenementCalendrier.formatDate(dateRemplacement),
        'enseignant_remplacant_id': enseignantRemplacantId,
        'motif': motif,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) throw Exception(_messageErreur(data));
    return data['remplacement'] as Map<String, dynamic>;
  }

  // Pas de modèle "Remplacement" dédié demandé — l'écran consomme
  // directement les champs bruts (seance, enseignant_remplacant, ...).
  static Future<List<Map<String, dynamic>>> getRemplacements({String? date, int? enseignantId, int? classeId}) async {
    final query = <String, String>{};
    if (date != null) query['date'] = date;
    if (enseignantId != null) query['enseignant_id'] = '$enseignantId';
    if (classeId != null) query['classe_id'] = '$classeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/remplacements')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['remplacements'] as List).map((r) => r as Map<String, dynamic>).toList();
    }
    throw Exception(_messageErreur(data));
  }

  static Future<void> annulerRemplacement(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/remplacements/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(_messageErreur(data));
    }
  }

  // ── Calendrier scolaire ──────────────────────────────────

  static Future<List<EvenementCalendrier>> getCalendrier(int anneeScolaireId) async {
    final data = await _getJson('/calendrier?annee_scolaire_id=$anneeScolaireId');
    return (data['evenements'] as List).map((e) => EvenementCalendrier.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<EvenementCalendrier> creerEvenementCalendrier(
    EvenementCalendrier evenement, {
    required int anneeScolaireId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/calendrier'),
      headers: await _headers(),
      body: jsonEncode({...evenement.toJson(), 'annee_scolaire_id': anneeScolaireId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) throw Exception(_messageErreur(data));
    return EvenementCalendrier.fromJson(data['evenement'] as Map<String, dynamic>);
  }

  static Future<void> supprimerEvenementCalendrier(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/calendrier/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(_messageErreur(data));
    }
  }

  // ── Exports ───────────────────────────────────────────────
  // Télécharge le fichier et renvoie son chemin local (même convention que
  // les autres exports de l'application — voir AnneeService.telecharger*),
  // prêt à être ouvert avec OpenFile.open.

  static Future<String> exportClassePdf(int classeId, int periodeId) {
    return _telechargerFichier(
      '/export/classe/$classeId/pdf?periode_id=$periodeId',
      'emploi_du_temps_classe_$classeId.pdf',
    );
  }

  static Future<String> exportClasseExcel(int classeId, int periodeId) {
    return _telechargerFichier(
      '/export/classe/$classeId/excel?periode_id=$periodeId',
      'emploi_du_temps_classe_$classeId.xlsx',
    );
  }

  static Future<String> exportEnseignantPdf(int enseignantId, int periodeId) {
    return _telechargerFichier(
      '/export/enseignant/$enseignantId/pdf?periode_id=$periodeId',
      'emploi_du_temps_enseignant_$enseignantId.pdf',
    );
  }

  static Future<String> _telechargerFichier(String chemin, String nomFichier) async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps$chemin'),
      headers: {'Accept': '*/*', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      var message = 'Erreur lors de la génération du fichier';
      try {
        message = (jsonDecode(response.body) as Map)['message'] as String? ?? message;
      } catch (_) {
        // Réponse non-JSON (rare) : on garde le message générique.
      }
      throw Exception(message);
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminLocal = '${dossier.path}/$nomFichier';
    await File(cheminLocal).writeAsBytes(response.bodyBytes);
    return cheminLocal;
  }

  // ── Aide interne ──────────────────────────────────────────

  static Future<Map<String, dynamic>> _getJson(String chemin) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps$chemin'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data as Map<String, dynamic>;
    throw Exception(_messageErreur(data));
  }

  static String _messageErreur(dynamic data) {
    if (data is Map && data['errors'] is Map) {
      final erreurs = (data['errors'] as Map).values.first;
      if (erreurs is List && erreurs.isNotEmpty) return erreurs.first.toString();
    }
    if (data is Map && data['message'] != null) return data['message'].toString();
    return 'Une erreur est survenue';
  }
}
