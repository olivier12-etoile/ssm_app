import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class ClasseService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste paginée des classes ──────────────────────────
  static Future<Map<String, dynamic>> lister({
    String? statut,
    String? niveau,
    int? anneeId,
    String? recherche,
    String tri = 'nom',
    int page = 1,
  }) async {
    final query = <String, String>{
      'tri':  tri,
      'page': '$page',
    };
    if (statut != null)    query['statut']    = statut;
    if (niveau != null)    query['niveau']    = niveau;
    if (anneeId != null)   query['annee_id']  = '$anneeId';
    if (recherche != null && recherche.isNotEmpty) query['search'] = recherche;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/classes')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement classes');
  }

  // ── Fiche détaillée d'une classe ───────────────────────
  static Future<Map<String, dynamic>> details(int classeId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/$classeId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement de la classe');
  }

  // ── Créer une classe ───────────────────────────────────
  static Future<void> creer({
    required String nom,
    required String niveau,
    String? serie,
    String? salle,
    required int capaciteMax,
    String statut = 'active',
    int? professeurPrincipalId,
    int? anneeAcademiqueId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/classes'),
      headers: await _headers(),
      body: jsonEncode({
        'nom':                     nom,
        'niveau':                  niveau,
        'serie':                   serie,
        'salle':                   salle,
        'capacite_max':            capaciteMax,
        'statut':                  statut,
        'professeur_principal_id': professeurPrincipalId,
        'annee_academique_id':     anneeAcademiqueId,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur création classe');
    }
  }

  // ── Modifier une classe ────────────────────────────────
  // Note : le backend exige nom + niveau (champs required sur la
  // route PUT) — bien que nullables ici, ils doivent toujours être
  // fournis par l'appelant pour que la requête aboutisse.
  static Future<void> modifier(
    int id, {
    String? nom,
    String? niveau,
    String? serie,
    String? salle,
    int? capaciteMax,
    String? statut,
    int? professeurPrincipalId,
  }) async {
    final donnees = <String, dynamic>{};
    if (nom != null)                    donnees['nom']                     = nom;
    if (niveau != null)                 donnees['niveau']                  = niveau;
    if (serie != null)                  donnees['serie']                   = serie;
    if (salle != null)                  donnees['salle']                   = salle;
    if (capaciteMax != null)            donnees['capacite_max']            = capaciteMax;
    if (statut != null)                 donnees['statut']                  = statut;
    if (professeurPrincipalId != null)  donnees['professeur_principal_id'] = professeurPrincipalId;

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/$id'),
      headers: await _headers(),
      body: jsonEncode(donnees),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur modification classe');
    }
  }

  // ── Archiver une classe ────────────────────────────────
  static Future<void> archiver(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/$id/archiver'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur archivage classe');
    }
  }

  // ── Réactiver une classe ───────────────────────────────
  static Future<void> activer(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/$id/activer'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur réactivation classe');
    }
  }

  // ── Transférer un élève vers une autre classe ──────────
  static Future<void> transfererEleve({
    required int eleveId,
    required int classeSourceId,
    required int classeDestinationId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/transferer-eleve'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id':              eleveId,
        'classe_source_id':      classeSourceId,
        'classe_destination_id': classeDestinationId,
      }),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur transfert élève');
    }
  }

  // ── Exporter la liste des élèves en PDF ────────────────
  static Future<String> exporterPdf(int classeId) async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/$classeId/exporter-pdf'),
      headers: {
        'Accept':        'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier = '${dossier.path}/classe_${classeId}_eleves.pdf';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }

  // ── Exporter la liste des élèves en Excel ──────────────
  static Future<String> exporterExcel(int classeId) async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/classes/$classeId/exporter-excel'),
      headers: {
        'Accept':        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur export Excel');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier = '${dossier.path}/classe_${classeId}_eleves.xlsx';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }

  // ── Compatibilité écrans existants ─────────────────────
  // `GET /classes` renvoie désormais une réponse paginée. Les écrans
  // qui attendent encore un tableau simple (non paginé) continuent
  // de fonctionner via ces deux méthodes, qui s'appuient sur la
  // nouvelle API ci-dessus sans dupliquer la logique réseau.
  static Future<List<dynamic>> listerClasses() async {
    final toutes = <dynamic>[];
    var page = 1;
    while (true) {
      final resultat = await lister(page: page);
      toutes.addAll((resultat['data'] as List?) ?? []);
      final dernierePage = resultat['last_page'] as int? ?? 1;
      if (page >= dernierePage) break;
      page++;
    }
    return toutes;
  }

  static Future<void> creerClasse({
    required String nom,
    required String niveau,
    int capaciteMax = 50,
  }) async {
    await creer(nom: nom, niveau: niveau, capaciteMax: capaciteMax);
  }
}
