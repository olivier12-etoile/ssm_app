import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/bulletin_service.dart';
import '../models/bulletin_model.dart';
import '../models/historique_statistique_bulletin_model.dart';

// Service Historique/Recherche/Statistiques/Validation-en-masse/Corrections
// du module Bulletins. Même pattern que les autres services du projet
// (package:http + AuthService.getToken() — ce projet n'utilise pas Dio,
// voir bulletin_service.dart pour la même remarque).
//
// La validation individuelle/en masse et les corrections sont déjà
// implémentées dans BulletinService (Phase 5, requises par
// apercu_bulletin_screen.dart et liste_bulletins_classe_screen.dart) : les
// méthodes ci-dessous délèguent à cette implémentation existante plutôt que
// de dupliquer la logique HTTP, tout en exposant les noms attendus par ce
// service dédié.
class HistoriqueStatistiqueBulletinService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Historique d'un élève (structure arborescente année → périodes) ──
  // GET /bulletins/historique/eleve/{eleveId} renvoie une structure
  // imbriquée ; elle est aplatie ici en liste plate (chaque élément porte
  // déjà son nomAnnee/nomPeriode), le regroupement pour l'affichage en
  // arborescence se faisant côté écran.
  static Future<List<BulletinHistorique>> getHistoriqueEleve(int eleveId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/historique/eleve/$eleveId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Erreur chargement de l'historique des bulletins");
    }

    final eleve = data['eleve'] as Map<String, dynamic>?;
    final nomEleve = eleve != null ? '${eleve['nom'] ?? ''} ${eleve['prenom'] ?? ''}'.trim() : null;
    final historique = data['historique'] as Map<String, dynamic>? ?? {};

    final resultats = <BulletinHistorique>[];
    historique.forEach((nomAnnee, groupe) {
      final groupeMap = groupe as Map<String, dynamic>;
      final anneeScolaireId = groupeMap['annee_scolaire_id'] as int?;
      final periodes = groupeMap['periodes'] as Map<String, dynamic>? ?? {};

      periodes.forEach((nomPeriode, resume) {
        final r = resume as Map<String, dynamic>;
        resultats.add(BulletinHistorique(
          id: r['bulletin_id'] as int,
          eleveId: eleveId,
          nomEleve: nomEleve,
          nomClasse: r['classe_nom'] as String?,
          periodeId: r['periode_id'] as int,
          nomPeriode: nomPeriode,
          anneeScolaireId: anneeScolaireId,
          nomAnnee: nomAnnee,
          moyenneGenerale: double.parse((r['moyenne_generale'] ?? 0).toString()),
          rang: r['rang'] as int?,
          statut: StatutBulletin.depuisApi(r['statut'] as String? ?? 'genere'),
        ));
      });
    });

    return resultats;
  }

  // ── Recherche ─────────────────────────────────────────────
  static Future<ResultatRechercheBulletins> rechercherBulletins({
    String? query,
    int? classeId,
    int? anneeScolaireId,
    int? periodeId,
    int page = 1,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (classeId != null) params['classe_id'] = '$classeId';
    if (anneeScolaireId != null) params['annee_scolaire_id'] = '$anneeScolaireId';
    if (periodeId != null) params['periode_id'] = '$periodeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/bulletins/historique/rechercher').replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur recherche des bulletins');
    }
    return ResultatRechercheBulletins.fromJson(data);
  }

  // ── Statistiques ──────────────────────────────────────────

  static Future<StatistiqueClasseBulletin> getStatistiqueClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/statistiques/classe/$classeId/$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return StatistiqueClasseBulletin.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erreur chargement des statistiques de la classe');
  }

  static Future<List<DistributionMoyenne>> getDistributionMoyennes({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/statistiques/distribution/$classeId/$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['distribution'] as List)
          .map((d) => DistributionMoyenne.fromJson(d as Map<String, dynamic>))
          .toList();
    }
    throw Exception(data['message'] ?? 'Erreur chargement de la distribution des moyennes');
  }

  static Future<ComparaisonPeriodesBulletin> getComparaisonPeriodes({
    required int classeId,
    required int periodeId1,
    required int periodeId2,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/bulletins/statistiques/comparaison').replace(
      queryParameters: {
        'classe_id': '$classeId',
        'periode_id_1': '$periodeId1',
        'periode_id_2': '$periodeId2',
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ComparaisonPeriodesBulletin.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erreur chargement de la comparaison entre périodes');
  }

  // ── Validation (délègue à BulletinService, voir commentaire de classe) ──

  static Future<Bulletin> validerBulletin(int bulletinId) => BulletinService.validerBulletin(bulletinId);

  static Future<int> validerEnMasse({required int classeId, required int periodeId}) =>
      BulletinService.validerClasse(classeId: classeId, periodeId: periodeId);

  // ── Corrections (délègue à BulletinService pour l'écriture) ──────

  static Future<Bulletin> demanderCorrection({
    required int bulletinId,
    int? bulletinDetailId,
    required String champModifie,
    required dynamic nouvelleValeur,
    required String motif,
  }) {
    return BulletinService.corrigerBulletin(
      bulletinId: bulletinId,
      bulletinDetailId: bulletinDetailId,
      champModifie: champModifie,
      nouvelleValeur: nouvelleValeur,
      motif: motif,
    );
  }

  static Future<List<CorrectionBulletin>> getHistoriqueCorrections(int bulletinId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/corrections/$bulletinId/historique'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['corrections'] as List)
          .map((c) => CorrectionBulletin.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    throw Exception(data['message'] ?? "Erreur chargement de l'historique des corrections");
  }
}
