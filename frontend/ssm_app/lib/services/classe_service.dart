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

  // ── Liste des classes groupées par cycle ───────────────
  // Renvoie {college: [...], lycee_moderne: [...], lycee_technique: [...]}
  static Future<Map<String, dynamic>> lister({
    String? statut,
    String? niveau,
    String? cycle,
    int? anneeId,
    String? recherche,
    String tri = 'nom',
  }) async {
    final query = <String, String>{'tri': tri};
    if (statut != null)    query['statut']    = statut;
    if (niveau != null)    query['niveau']    = niveau;
    if (cycle != null)     query['cycle']     = cycle;
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
  // Le nom est généré côté backend à partir de niveau + série + indice —
  // il n'est jamais envoyé par le client.
  static Future<void> creer({
    required String niveau,
    String? serie,
    String? indice,
    String? salle,
    int capaciteMax = 40,
    String statut = 'active',
    String cycle = 'college',
    int? professeurPrincipalId,
    int? anneeAcademiqueId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/classes'),
      headers: await _headers(),
      body: jsonEncode({
        'niveau':                  niveau,
        'serie':                   serie,
        'indice':                  indice,
        'salle':                   salle,
        'capacite_max':            capaciteMax,
        'statut':                  statut,
        'cycle':                   cycle,
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
    String? cycle,
    int? professeurPrincipalId,
  }) async {
    final donnees = <String, dynamic>{};
    if (nom != null)                    donnees['nom']                     = nom;
    if (niveau != null)                 donnees['niveau']                  = niveau;
    if (serie != null)                  donnees['serie']                   = serie;
    if (salle != null)                  donnees['salle']                   = salle;
    if (capaciteMax != null)            donnees['capacite_max']            = capaciteMax;
    if (statut != null)                 donnees['statut']                  = statut;
    if (cycle != null)                  donnees['cycle']                   = cycle;
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
  // `GET /classes` renvoie désormais les classes groupées par cycle,
  // puis par niveau, puis par série pour les lycées (cycle → niveau →
  // [classes] pour le collège ; cycle → niveau → série → [classes]
  // pour les lycées). Les écrans qui attendent encore un tableau
  // simple continuent de fonctionner via cette méthode, qui aplatit
  // récursivement cette structure quel que soit son niveau d'imbrication.
  static Future<List<dynamic>> listerClasses() async {
    final resultat = await lister();
    final toutes = <dynamic>[];

    void aplatir(dynamic valeur) {
      if (valeur is List) {
        toutes.addAll(valeur);
      } else if (valeur is Map) {
        for (final v in valeur.values) {
          aplatir(v);
        }
      }
    }

    aplatir(resultat);
    return toutes;
  }
}
