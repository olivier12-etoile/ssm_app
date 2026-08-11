import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/note_model.dart';

class NoteService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Démarrer (ou reprendre) une session de saisie ──────
  static Future<SaisieNote> demarrerSaisie({
    required int classeId,
    required int matiereId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/saisie/demarrer'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id': classeId,
        'matiere_id': matiereId,
        'periode_id': periodeId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return SaisieNote.fromJson(data['saisie'] as Map<String, dynamic>);
  }

  // ── Élèves de la saisie + leurs notes déjà saisies ─────
  static Future<({bool verrouillee, List<EleveSaisie> eleves})> getElevesSaisie(int saisieId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/saisie/$saisieId/eleves'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (
      verrouillee: data['verrouillee'] as bool? ?? false,
      eleves: (data['eleves'] as List)
          .map((e) => EleveSaisie.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Saisies en cours de l'enseignant connecté ──────────
  static Future<List<SaisieNote>> getProgression() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/saisie/progression'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return (data['saisies'] as List).map((s) => SaisieNote.fromJson(s as Map<String, dynamic>)).toList();
  }

  // ── Enregistrer (ou mettre à jour) une note ────────────
  static Future<Note> enregistrerNote(Note note) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes'),
      headers: await _headers(),
      body: jsonEncode(note.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_messageErreur(data));
    }
    return Note.fromJson(data['note'] as Map<String, dynamic>);
  }

  // ── Enregistrement en masse (toute une classe en un appel) ──
  static Future<List<Note>> enregistrerNotesBulk({
    required int classeId,
    required int matiereId,
    required int periodeId,
    required List<Note> notes,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/bulk'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id': classeId,
        'matiere_id': matiereId,
        'periode_id': periodeId,
        'notes': notes
            .map((n) => {
                  'eleve_id': n.eleveId,
                  'type_evaluation': n.typeEvaluation.valeurApi,
                  'valeur': n.valeur,
                })
            .toList(),
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_messageErreur(data));
    }
    return (data['notes'] as List).map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
  }

  // ── Modifier une note existante (par son id) ───────────
  static Future<Note> modifierNote(int id, Note note) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/$id'),
      headers: await _headers(),
      body: jsonEncode({'valeur': note.valeur}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return Note.fromJson(data['note'] as Map<String, dynamic>);
  }

  // ── Supprimer une note (brouillon uniquement) ──────────
  static Future<void> supprimerNote(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(jsonDecode(response.body)));
    }
  }

  // ── Statistiques live (moyenne, meilleure/plus faible note, taux de
  // réussite, anomalies) pour une classe/matière/période ──
  static Future<StatistiquesSaisie> getStatistiques({
    required int classeId,
    required int matiereId,
    required int periodeId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notes/statistiques').replace(queryParameters: {
      'classe_id': '$classeId',
      'matiere_id': '$matiereId',
      'periode_id': '$periodeId',
    });
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return StatistiquesSaisie.fromJson(data);
  }

  // ── Soumettre la saisie pour validation ────────────────
  // Lève une exception avec un message détaillant les élèves incomplets si
  // le backend bloque la soumission (notes manquantes).
  static Future<String> soumettreSaisie(int saisieId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/notes/saisie/$saisieId/soumettre'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return data['message'] as String? ?? 'Notes soumises pour validation';
  }

  // Laravel renvoie {message} ou {message, eleves_incomplets:[...]} (422
  // lors du blocage de soumettreSaisie) ou {message, errors} (422 de
  // validation classique).
  static String _messageErreur(dynamic data) {
    if (data is Map && data['eleves_incomplets'] is List && (data['eleves_incomplets'] as List).isNotEmpty) {
      final noms = (data['eleves_incomplets'] as List).map((e) => '${e['nom']} ${e['prenom']}').join(', ');
      return '${data['message']}\nÉlèves concernés : $noms';
    }
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
