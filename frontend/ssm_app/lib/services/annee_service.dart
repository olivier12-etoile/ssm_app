import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class AnneeService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Années académiques ──────────────────────────────────

  static Future<Map<String, dynamic>> tableauDeBord() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/tableau-de-bord'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement tableau de bord');
  }

  static Future<List<dynamic>> listerAnnees() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement années');
  }

  // Renvoie {message, annee: null} avec un statut 404 si aucune année
  // n'est active — ce n'est pas une erreur, l'appelant doit vérifier
  // le contenu (`annee`) plutôt que catcher une exception.
  static Future<Map<String, dynamic>> anneeActive() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/active'),
      headers: await _headers(),
    );
    if (response.statusCode == 200 || response.statusCode == 404) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement année active');
  }

  static Future<void> creerAnnee({
    required String libelle,
    required String dateDebut,
    required String dateFin,
    String typePeriodes = 'auto',
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/annees'),
      headers: await _headers(),
      body: jsonEncode({
        'libelle': libelle,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        'type_periodes': typePeriodes,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création année');
    }
  }

  // Détails complets d'une année : stats, périodes, classes, élèves
  // (avec statut final), enseignants et données financières.
  static Future<Map<String, dynamic>> detailsAnnee(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/details'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des détails de l\'année');
  }

  static Future<void> activerAnnee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/activer'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur activation année');
    }
  }

  static Future<void> cloturerAnnee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/cloturer'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur clôture année');
    }
  }

  static Future<void> archiverAnnee(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/archiver'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur archivage année');
    }
  }

  static Future<Map<String, dynamic>> passerEleves(
    int anneeId, {
    required bool passerAutomatique,
    List<int> redoublants = const [],
    List<int> diplomes = const [],
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$anneeId/passer-eleves'),
      headers: await _headers(),
      body: jsonEncode({
        'passer_automatique': passerAutomatique,
        'redoublants': redoublants,
        'diplomes': diplomes,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur passage des élèves');
    }
    return data;
  }

  static Future<Map<String, dynamic>> statistiquesAnnee(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$id/statistiques'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement statistiques année');
  }

  static Future<List<dynamic>> historique() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/historique'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement historique');
  }

  // Aperçu en lecture seule du passage des élèves : moyenne et verdict
  // (admis/redoublant/sans_note) par élève, sans rien modifier en base.
  static Future<Map<String, dynamic>> apercuPassage(int anneeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/$anneeId/passage-apercu'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de l\'aperçu de passage');
  }

  static Future<List<dynamic>> rangsClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/annees/rangs?classe_id=$classeId&periode_id=$periodeId',
      ),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['eleves'] as List<dynamic>;
    }
    throw Exception('Erreur chargement du classement');
  }

  // Version complète de rangsClasse() : inclut moyenne_classe, classe_nom,
  // etc. en plus de la liste des élèves.
  static Future<Map<String, dynamic>> rangsClasseDetail({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/annees/rangs?classe_id=$classeId&periode_id=$periodeId',
      ),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement du classement');
  }

  static Future<Map<String, dynamic>> elevesNonEnRegle({
    List<String>? motif,
  }) async {
    final query = motif != null && motif.isNotEmpty
        ? '?${motif.map((m) => 'motif[]=$m').join('&')}'
        : '';
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/eleves-non-en-regle$query'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 404) {
      return data;
    }
    throw Exception(data['message'] ?? 'Erreur chargement des élèves non en règle');
  }

  // Télécharge le PDF du classement et retourne le chemin local du fichier.
  static Future<String> telechargerRangsPdf({
    required int classeId,
    required int periodeId,
  }) async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/annees/rangs/pdf?classe_id=$classeId&periode_id=$periodeId',
      ),
      headers: {
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du PDF de classement');
    }
    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/classement_${classeId}_$periodeId.pdf';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  // Télécharge le PDF des élèves non en règle et retourne le chemin local.
  static Future<String> telechargerElevesNonEnReglePdf({
    List<String>? motif,
  }) async {
    final token = await AuthService.getToken();
    final query = motif != null && motif.isNotEmpty
        ? '?${motif.map((m) => 'motif[]=$m').join('&')}'
        : '';
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/eleves-non-en-regle/pdf$query'),
      headers: {
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du PDF');
    }
    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/eleves_non_en_regle.pdf';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  // Télécharge le CSV (compatible Excel) des élèves non en règle.
  static Future<String> telechargerElevesNonEnRegleExcel({
    List<String>? motif,
  }) async {
    final token = await AuthService.getToken();
    final query = motif != null && motif.isNotEmpty
        ? '?${motif.map((m) => 'motif[]=$m').join('&')}'
        : '';
    final response = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/annees/eleves-non-en-regle/excel$query',
      ),
      headers: {
        'Accept': 'text/csv',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur génération du fichier Excel');
    }
    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/eleves_non_en_regle.csv';
    await File(chemin).writeAsBytes(response.bodyBytes);
    return chemin;
  }

  static Future<List<dynamic>> journal() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/annees/journal'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement du journal');
  }

  // ── Périodes académiques ────────────────────────────────

  static Future<List<dynamic>> listerPeriodes(int anneeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes?annee_id=$anneeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement périodes');
  }

  static Future<void> creerPeriode({
    required int anneeAcademiqueId,
    required String nom,
    String? code,
    required String dateDebut,
    required String dateFin,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes'),
      headers: await _headers(),
      body: jsonEncode({
        'annee_academique_id': anneeAcademiqueId,
        'nom': nom,
        'code': code,
        'date_debut': dateDebut,
        'date_fin': dateFin,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création période');
    }
  }

  static Future<void> ouvrirPeriode(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/ouvrir'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur ouverture période');
    }
  }

  static Future<Map<String, dynamic>> fermerPeriode(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/fermer'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur fermeture période');
    }
    return data;
  }

  static Future<void> mettreEnValidation(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/en-validation'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur mise en validation');
    }
  }

  static Future<void> reouvrir(int id, String motif) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/reouvrir'),
      headers: await _headers(),
      body: jsonEncode({'motif': motif}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur réouverture période');
    }
  }

  static Future<Map<String, dynamic>> etatEnseignants(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/etat-enseignants'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return {'enseignants': jsonDecode(response.body)};
    }
    throw Exception('Erreur chargement état des enseignants');
  }

  static Future<Map<String, dynamic>> verifierAvantCloture(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/verification'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur vérification avant clôture');
  }

  static Future<Map<String, dynamic>> genererBulletinsEnMasse(int id) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/$id/generer-bulletins'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur génération des bulletins');
    }
    return data;
  }

  static Future<Map<String, dynamic>> alertesPeriodes() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/periodes/alertes'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement alertes périodes');
  }
}
