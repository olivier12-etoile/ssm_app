import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/statistique_detail_model.dart';

// Le projet n'utilise pas Dio (voir pubspec.yaml : seul `http` est
// dépendance) — ce service suit donc le même pattern `http` + _headers()
// que tous les autres services (annee_service, statistique_generale_service...).
class StatistiqueDetailService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _get(String chemin, [Map<String, String>? query]) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$chemin').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data as Map<String, dynamic>;
    throw Exception(_messageErreur(data));
  }

  // ══════════════════════════════════════════════════════
  // INSCRIPTIONS
  // ══════════════════════════════════════════════════════

  static Future<List<EvolutionEffectif>> getInscriptionsParAnnee() async {
    final data = await _get('/statistiques/inscriptions/par-annee');
    return (data['annees'] as List).map((a) => EvolutionEffectif.fromJson(a as Map<String, dynamic>)).toList();
  }

  // Fusionne /inscriptions/par-niveau (total, nombre de classes) et
  // /inscriptions/par-sexe (garçons/filles par niveau) en une seule liste
  // RepartitionNiveau, pour le graphique en barres avec sous-répartition.
  static Future<List<RepartitionNiveau>> getInscriptionsParNiveau(int anneeScolaireId) async {
    final query = {'annee_scolaire_id': '$anneeScolaireId'};
    final resultats = await Future.wait([
      _get('/statistiques/inscriptions/par-niveau', query),
      _get('/statistiques/inscriptions/par-sexe', query),
    ]);

    final niveaux = resultats[0]['niveaux'] as List;
    final parNiveauSexe = {
      for (final n in (resultats[1]['par_niveau'] as List))
        (n as Map<String, dynamic>)['niveau'] as String: n,
    };

    return niveaux.map((n) {
      final niveau = n as Map<String, dynamic>;
      final sexe = parNiveauSexe[niveau['niveau']];
      return RepartitionNiveau.fromJson({
        'niveau': niveau['niveau'],
        'total': niveau['total_eleves'],
        'garcons': sexe?['garcons'] ?? 0,
        'filles': sexe?['filles'] ?? 0,
      });
    }).toList();
  }

  static Future<List<RepartitionClasse>> getInscriptionsParClasse(int anneeScolaireId) async {
    final data = await _get('/statistiques/inscriptions/par-classe', {'annee_scolaire_id': '$anneeScolaireId'});
    return (data['classes'] as List).map((c) => RepartitionClasse.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getInscriptionsParSexe(int anneeScolaireId) {
    return _get('/statistiques/inscriptions/par-sexe', {'annee_scolaire_id': '$anneeScolaireId'});
  }

  static Future<List<EvolutionEffectif>> getInscriptionsEvolution({int nombreAnnees = 5}) async {
    final data = await _get('/statistiques/inscriptions/evolution', {'nombre_annees': '$nombreAnnees'});
    return (data['detail'] as List).map((d) => EvolutionEffectif.fromJson(d as Map<String, dynamic>)).toList();
  }

  // ══════════════════════════════════════════════════════
  // PAIEMENTS
  // ══════════════════════════════════════════════════════

  static Future<List<PaiementClasse>> getPaiementsParClasse(int anneeScolaireId) async {
    final data = await _get('/statistiques/paiements/par-classe', {'annee_scolaire_id': '$anneeScolaireId'});
    return (data['classes'] as List).map((c) => PaiementClasse.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<List<PaiementClasse>> getPaiementsParNiveau(int anneeScolaireId) async {
    final data = await _get('/statistiques/paiements/par-niveau', {'annee_scolaire_id': '$anneeScolaireId'});
    return (data['niveaux'] as List).map((n) => PaiementClasse.fromJson(n as Map<String, dynamic>)).toList();
  }

  static Future<List<PaiementMensuel>> getPaiementsParMois(int anneeScolaireId) async {
    final data = await _get('/statistiques/paiements/par-mois', {'annee_scolaire_id': '$anneeScolaireId'});
    return (data['mois'] as List).map((m) => PaiementMensuel.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<List<EleveNonEnRegle>> getElevesNonEnRegle({
    int? anneeScolaireId,
    int? classeId,
    String? niveau,
    double? montantMin,
  }) async {
    final query = <String, String>{};
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';
    if (classeId != null) query['classe_id'] = '$classeId';
    if (niveau != null && niveau.isNotEmpty) query['niveau'] = niveau;
    if (montantMin != null) query['montant_min'] = '$montantMin';

    final data = await _get('/statistiques/paiements/eleves-non-en-regle', query);
    return (data['eleves'] as List).map((e) => EleveNonEnRegle.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ══════════════════════════════════════════════════════
  // PÉDAGOGIQUE
  // ══════════════════════════════════════════════════════

  static Future<List<StatMatiere>> getPedagogiqueParMatiere(int periodeId) async {
    final data = await _get('/statistiques/pedagogique/par-matiere', {'periode_id': '$periodeId'});
    return (data['matieres'] as List).map((m) => StatMatiere.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<List<StatEnseignant>> getPedagogiqueParEnseignant(int periodeId) async {
    final data = await _get('/statistiques/pedagogique/par-enseignant', {'periode_id': '$periodeId'});
    return (data['enseignants'] as List).map((e) => StatEnseignant.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<StatClasse>> getPedagogiqueParClasse(int periodeId) async {
    final data = await _get('/statistiques/pedagogique/par-classe', {'periode_id': '$periodeId'});
    return (data['classes'] as List).map((c) => StatClasse.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<List<StatClasse>> getMeilleuresClasses(int periodeId, {int limite = 10}) async {
    final data = await _get('/statistiques/pedagogique/meilleures-classes', {'periode_id': '$periodeId', 'limite': '$limite'});
    return (data['classement'] as List).map((c) => StatClasse.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<List<EleveClassement>> getMeilleursEleves(int periodeId, {int limite = 10, String? niveau}) async {
    final query = {'periode_id': '$periodeId', 'limite': '$limite'};
    if (niveau != null && niveau.isNotEmpty) query['niveau'] = niveau;
    final data = await _get('/statistiques/pedagogique/meilleurs-eleves', query);
    final eleves = data['eleves'] as List;
    return [for (var i = 0; i < eleves.length; i++) EleveClassement.fromJson(eleves[i] as Map<String, dynamic>, i + 1)];
  }

  static Future<List<EleveClassement>> getElevesEnDifficulte(int periodeId, {double seuil = 8}) async {
    final data = await _get('/statistiques/pedagogique/eleves-en-difficulte', {'periode_id': '$periodeId', 'seuil': '$seuil'});
    final eleves = data['eleves'] as List;
    return [for (var i = 0; i < eleves.length; i++) EleveClassement.fromJson(eleves[i] as Map<String, dynamic>, i + 1)];
  }

  // ══════════════════════════════════════════════════════
  // CENTRE DE DÉCISION
  // ══════════════════════════════════════════════════════

  static Future<List<Alerte>> getAlertes({
    required int anneeScolaireId,
    required int periodeId,
    int? seuilPaiementRetard,
  }) async {
    final query = {
      'annee_scolaire_id': '$anneeScolaireId',
      'periode_id': '$periodeId',
      if (seuilPaiementRetard != null) 'seuil_paiement_retard': '$seuilPaiementRetard',
    };
    final data = await _get('/statistiques/centre-decision/alertes', query);
    return (data['alertes'] as List).map((a) => Alerte.fromJson(a as Map<String, dynamic>)).toList();
  }

  // ══════════════════════════════════════════════════════
  // RAPPORTS (PDF / EXCEL)
  // ══════════════════════════════════════════════════════

  // type: inscriptions | financier | paiements | resultats | meilleurs-eleves | eleves-en-difficulte
  // format: pdf | excel
  static Future<Uint8List> getRapport(String type, String format, Map<String, String> filtres) async {
    final token = await AuthService.getToken();
    final query = {...filtres, 'format': format};

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/statistiques/rapports/$type').replace(queryParameters: query);

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
      throw Exception('Erreur lors de la génération du rapport.');
    }
    return response.bodyBytes;
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
