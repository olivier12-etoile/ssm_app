import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/emploi_du_temps_model.dart';

// Levée quand le serveur renvoie un 422 accompagné d'une liste de conflits
// (créneau enseignant/salle/classe déjà occupé), plutôt qu'une simple
// erreur de validation — permet à l'UI d'afficher chaque conflit au lieu
// d'un message générique.
class ConflitEmploiDuTempsException implements Exception {
  final String message;
  final List<ConflitDetecte> conflits;

  ConflitEmploiDuTempsException(this.message, this.conflits);

  @override
  String toString() => message;
}

class EmploiDuTempsService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Créneaux horaires ────────────────────────────────────

  static Future<List<CreneauHoraire>> getCreneauxHoraires({int? anneeScolaireId}) async {
    final query = <String, String>{};
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/creneaux-horaires')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final liste = data['creneaux'] as List;
      return liste.map((c) => CreneauHoraire.fromJson(c as Map<String, dynamic>)).toList();
    }
    throw Exception(_messageErreur(data));
  }

  static Future<CreneauHoraire> creerCreneauHoraire(
    CreneauHoraire creneau, {
    required int anneeScolaireId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/creneaux-horaires'),
      headers: await _headers(),
      body: jsonEncode({...creneau.toJson(), 'annee_scolaire_id': anneeScolaireId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_messageErreur(data));
    }
    return CreneauHoraire.fromJson(data['creneau'] as Map<String, dynamic>);
  }

  // ── Jours travaillés ─────────────────────────────────────

  static Future<List<JourTravaille>> getJoursTravailles({int? anneeScolaireId}) async {
    final query = <String, String>{};
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/jours-travailles')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final liste = data['jours'] as List;
      return liste.map((j) => JourTravaille.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_messageErreur(data));
  }

  // Active/désactive un jour travaillé (upsert côté backend : un seul
  // appel sert aussi bien à créer qu'à modifier).
  static Future<JourTravaille> definirJourTravaille(
    JourSemaine jour,
    bool actif, {
    required int anneeScolaireId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/jours-travailles'),
      headers: await _headers(),
      body: jsonEncode({
        'jour': jour.valeurApi,
        'actif': actif,
        'annee_scolaire_id': anneeScolaireId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_messageErreur(data));
    }
    return JourTravaille.fromJson(data['jour'] as Map<String, dynamic>);
  }

  // ── Emplois du temps ─────────────────────────────────────

  static Future<EmploiDuTemps> creerEmploiDuTemps({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/emplois-du-temps'),
      headers: await _headers(),
      body: jsonEncode({'classe_id': classeId, 'periode_id': periodeId}),
    );
    final data = jsonDecode(response.body);
    // 409 : un emploi du temps existe déjà pour cette classe/période — le
    // backend le renvoie quand même dans ce cas, on le récupère au lieu
    // d'échouer (évite un doublon accidentel côté UI).
    if (response.statusCode != 201 && response.statusCode != 409) {
      throw Exception(_messageErreur(data));
    }
    return EmploiDuTemps.fromJson(data['emploi_du_temps'] as Map<String, dynamic>);
  }

  static Future<EmploiDuTemps> getEmploiDuTemps(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/emplois-du-temps/$id'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return EmploiDuTemps.fromApiResponse(data as Map<String, dynamic>);
    }
    throw Exception(_messageErreur(data));
  }

  // Emploi du temps existant d'une classe pour une période, ou null si
  // aucun n'a encore été créé (l'écran de création doit alors proposer
  // de le créer plutôt que d'afficher une erreur).
  static Future<EmploiDuTemps?> consulterParClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/consultation/classe/$classeId?periode_id=$periodeId'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    if (data['emploi_du_temps'] == null) return null;
    return EmploiDuTemps.fromApiResponse(data);
  }

  static Future<EmploiDuTemps> validerEmploiDuTemps(int id) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/emplois-du-temps/$id/valider'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 422 && data['conflits'] != null) {
      throw ConflitEmploiDuTempsException(
        data['message'] as String? ?? 'Des conflits empêchent la validation',
        _conflitsDepuisValidation(data['conflits'] as List),
      );
    }
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return EmploiDuTemps.fromJson(data['emploi_du_temps'] as Map<String, dynamic>);
  }

  // La validation renvoie les conflits regroupés par séance
  // ([{seance_id, conflits: [...]}, ...]) — on les aplatit pour l'affichage.
  static List<ConflitDetecte> _conflitsDepuisValidation(List brut) {
    final resultat = <ConflitDetecte>[];
    for (final item in brut) {
      final map = item as Map<String, dynamic>;
      for (final c in (map['conflits'] as List? ?? [])) {
        resultat.add(ConflitDetecte.fromJson(c as Map<String, dynamic>));
      }
    }
    return resultat;
  }

  // ── Séances ───────────────────────────────────────────────

  static Future<Seance> creerSeance(Seance seance, {required int emploiDuTempsId}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/seances'),
      headers: await _headers(),
      body: jsonEncode({...seance.toJson(), 'emploi_du_temps_id': emploiDuTempsId}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 422 && data['conflits'] != null) {
      throw ConflitEmploiDuTempsException(
        data['message'] as String? ?? 'Conflit détecté',
        (data['conflits'] as List).map((c) => ConflitDetecte.fromJson(c as Map<String, dynamic>)).toList(),
      );
    }
    if (response.statusCode != 201) {
      throw Exception(_messageErreur(data));
    }
    return Seance.fromJson(data['seance'] as Map<String, dynamic>);
  }

  // Renvoie la réponse brute ({message, reussies, echouees}) : chaque
  // ligne échouée porte son index et ses conflits, utile pour un import
  // en masse où l'appelant veut traiter chaque cas individuellement.
  static Future<Map<String, dynamic>> creerSeancesBulk(
    List<Seance> seances, {
    required int emploiDuTempsId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/seances/bulk'),
      headers: await _headers(),
      body: jsonEncode({
        'emploi_du_temps_id': emploiDuTempsId,
        'seances': seances.map((s) => s.toJson()).toList(),
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 207) {
      throw Exception(_messageErreur(data));
    }
    return data;
  }

  static Future<Seance> modifierSeance(int id, Seance seance) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/seances/$id'),
      headers: await _headers(),
      body: jsonEncode(seance.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 422 && data['conflits'] != null) {
      throw ConflitEmploiDuTempsException(
        data['message'] as String? ?? 'Conflit détecté',
        (data['conflits'] as List).map((c) => ConflitDetecte.fromJson(c as Map<String, dynamic>)).toList(),
      );
    }
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return Seance.fromJson(data['seance'] as Map<String, dynamic>);
  }

  static Future<void> supprimerSeance(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/seances/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(_messageErreur(data));
    }
  }

  // ── Duplication ───────────────────────────────────────────

  // Copie les séances d'un emploi du temps vers une autre classe. Renvoie
  // la réponse brute ({message, emploi_du_temps, seances_copiees,
  // seances_en_conflit}) : les séances en conflit enseignant n'ont pas
  // été copiées et doivent être traitées manuellement par l'utilisateur.
  static Future<Map<String, dynamic>> dupliquer({
    required int emploiSourceId,
    required int classeDestinationId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/emploi-du-temps/duplication'),
      headers: await _headers(),
      body: jsonEncode({
        'emploi_du_temps_source_id': emploiSourceId,
        'classe_destination_id': classeDestinationId,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 207) {
      throw Exception(_messageErreur(data));
    }
    return data;
  }

  // ── Aide interne ──────────────────────────────────────────

  static String _messageErreur(dynamic data) {
    if (data is Map && data['errors'] is Map) {
      final erreurs = (data['errors'] as Map).values.first;
      if (erreurs is List && erreurs.isNotEmpty) return erreurs.first.toString();
    }
    if (data is Map && data['message'] != null) return data['message'].toString();
    return 'Une erreur est survenue';
  }
}
