import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/bulletin_model.dart';

// Service du module Bulletins (génération, validation, corrections, PDF).
// Même pattern que les autres services du projet (package:http +
// AuthService.getToken(), voir CLAUDE.md "Pattern headers Flutter") : ce
// projet n'utilise pas Dio.
class BulletinService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Génération ────────────────────────────────────────────

  static Future<Bulletin> genererIndividuel({
    required int eleveId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/generation/individuel'),
      headers: await _headers(),
      body: jsonEncode({'eleve_id': eleveId, 'periode_id': periodeId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return Bulletin.fromJson(data['bulletin'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur génération du bulletin');
  }

  static Future<ResumeGenerationClasse> genererClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/generation/classe'),
      headers: await _headers(),
      body: jsonEncode({'classe_id': classeId, 'periode_id': periodeId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ResumeGenerationClasse.fromJson(data['resume'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur génération des bulletins de la classe');
  }

  static Future<Bulletin> regenererIndividuel({
    required int eleveId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/generation/regenerer'),
      headers: await _headers(),
      body: jsonEncode({'eleve_id': eleveId, 'periode_id': periodeId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Bulletin.fromJson(data['bulletin'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur régénération du bulletin');
  }

  static Future<List<StatutGenerationEleve>> getStatutGeneration({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/generation/statut/$classeId/$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['eleves'] as List)
          .map((e) => StatutGenerationEleve.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(data['message'] ?? 'Erreur vérification du statut de génération');
  }

  // ── Dashboard ─────────────────────────────────────────────

  static Future<ResumeDashboardBulletin> getResumeDashboard({
    required int anneeScolaireId,
    required int periodeId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/bulletins/dashboard/resume').replace(
      queryParameters: {
        'annee_scolaire_id': '$anneeScolaireId',
        'periode_id': '$periodeId',
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ResumeDashboardBulletin.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erreur chargement du résumé des bulletins');
  }

  // ── Historique d'un élève ─────────────────────────────────
  // GET /bulletins/historique/eleve/{eleveId} renvoie les bulletins
  // groupés par année scolaire puis par période (structure imbriquée,
  // utile pour un écran d'historique dédié). Ici on aplatit en
  // Map<periode_id, résumé> pour les écrans qui affichent le bulletin
  // d'un élève période par période (ex: fiche élève).
  static Future<Map<int, Map<String, dynamic>>> getHistoriqueEleve(int eleveId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/historique/eleve/$eleveId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Erreur chargement de l'historique des bulletins");
    }

    final parPeriode = <int, Map<String, dynamic>>{};
    final historique = data['historique'] as Map<String, dynamic>? ?? {};
    for (final groupeAnnee in historique.values) {
      final periodes = (groupeAnnee as Map<String, dynamic>)['periodes'] as Map<String, dynamic>? ?? {};
      for (final resume in periodes.values) {
        final r = resume as Map<String, dynamic>;
        final periodeId = r['periode_id'] as int?;
        if (periodeId != null) parPeriode[periodeId] = r;
      }
    }
    return parPeriode;
  }

  // ── Liste des bulletins d'une classe/période ────────────────
  // Réutilise GET /bulletins/historique/rechercher (module Historique &
  // Recherche, Phase 6) plutôt qu'une route dédiée qui n'existe pas côté
  // API : ce endpoint accepte déjà classe_id + periode_id et renvoie les
  // bulletins avec élève/classe/période chargés. Il est paginé (30/page),
  // donc on parcourt toutes les pages pour reconstituer la classe entière,
  // puis on trie par rang côté client.
  static Future<List<Bulletin>> listerBulletinsClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final tous = <Bulletin>[];
    var page = 1;
    while (true) {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/bulletins/historique/rechercher').replace(
        queryParameters: {
          'classe_id': '$classeId',
          'periode_id': '$periodeId',
          'page': '$page',
        },
      );
      final response = await http.get(uri, headers: await _headers());
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Erreur chargement des bulletins de la classe');
      }
      tous.addAll((data['data'] as List).map((b) => Bulletin.fromJson(b as Map<String, dynamic>)));

      final pageCourante = data['current_page'] as int? ?? page;
      final derniere = data['last_page'] as int? ?? pageCourante;
      if (pageCourante >= derniere) break;
      page++;
    }

    tous.sort((a, b) => (a.rang ?? 1 << 30).compareTo(b.rang ?? 1 << 30));
    return tous;
  }

  // ── Validation ────────────────────────────────────────────
  // Pas listées nommément dans le brief de bulletin_service.dart, mais
  // requises par apercu_bulletin_screen.dart ("Valider ce bulletin") et
  // liste_bulletins_classe_screen.dart ("Valider tous les bulletins").

  static Future<Bulletin> validerBulletin(int bulletinId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/validation/valider'),
      headers: await _headers(),
      body: jsonEncode({'bulletin_id': bulletinId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Bulletin.fromJson(data['bulletin'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur validation du bulletin');
  }

  static Future<int> validerClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/validation/valider-masse'),
      headers: await _headers(),
      body: jsonEncode({'classe_id': classeId, 'periode_id': periodeId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return _versEntierService(data['nombre_valides']);
    }
    throw Exception(data['message'] ?? 'Erreur validation des bulletins de la classe');
  }

  // ── Corrections ───────────────────────────────────────────
  // Requise par apercu_bulletin_screen.dart ("Modifier" — décision du
  // conseil / appréciation générale, uniquement sur un bulletin déjà
  // validé, voir CorrectionBulletinController côté backend).
  static Future<Bulletin> corrigerBulletin({
    required int bulletinId,
    int? bulletinDetailId,
    required String champModifie,
    required dynamic nouvelleValeur,
    required String motif,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/corrections'),
      headers: await _headers(),
      body: jsonEncode({
        'bulletin_id': bulletinId,
        'bulletin_detail_id': bulletinDetailId,
        'champ_modifie': champModifie,
        'nouvelle_valeur': nouvelleValeur,
        'motif': motif,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Bulletin.fromJson(data['bulletin'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Erreur correction du bulletin');
  }

  // ── PDF / exports (octets bruts — l'appelant décide de les
  // sauvegarder puis de les ouvrir, voir recu_pdf_viewer.dart) ──────

  static Future<Uint8List> telechargerPdf(int bulletinId) {
    return _telechargerBytes('/bulletins/pdf/$bulletinId', 'application/pdf', 'Erreur téléchargement du bulletin');
  }

  static Future<Uint8List> telechargerApercu(int bulletinId) {
    return _telechargerBytes(
      '/bulletins/pdf/$bulletinId/apercu',
      'application/pdf',
      "Erreur génération de l'aperçu du bulletin",
    );
  }

  static Future<Uint8List> telechargerClasseZip({
    required int classeId,
    required int periodeId,
  }) {
    return _telechargerBytes(
      '/bulletins/pdf/classe/$classeId/$periodeId/zip',
      'application/zip',
      'Erreur téléchargement du ZIP des bulletins',
    );
  }

  static Future<Uint8List> telechargerGlobalClasse({
    required int classeId,
    required int periodeId,
  }) {
    return _telechargerBytes(
      '/bulletins/pdf/classe/$classeId/$periodeId/global',
      'application/pdf',
      'Erreur téléchargement du récapitulatif de classe',
    );
  }

  static Future<Uint8List> _telechargerBytes(String chemin, String accept, String messageErreur) async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$chemin'),
      headers: {
        'Accept': accept,
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(messageErreur);
    }
    return response.bodyBytes;
  }
}

int _versEntierService(dynamic valeur) => (valeur as num?)?.toInt() ?? 0;
