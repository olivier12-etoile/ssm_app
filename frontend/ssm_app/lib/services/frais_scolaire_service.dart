import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/frais_scolaire_model.dart';

class FraisScolaireService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste des frais scolaires de l'école ───────────────
  static Future<List<FraisScolaire>> getFrais({
    int? classeId,
    int? anneeScolaireId,
    bool? actif,
  }) async {
    final query = <String, String>{};
    if (classeId != null) query['classe_id'] = '$classeId';
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';
    if (actif != null) query['actif'] = actif ? '1' : '0';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final liste = jsonDecode(response.body) as List;
      return liste
          .map((e) => FraisScolaire.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Erreur chargement des frais scolaires');
  }

  // ── Détail d'un frais scolaire (avec ses échéances) ────
  static Future<FraisScolaire> getFraisById(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/$id'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return FraisScolaire.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur chargement du frais scolaire');
  }

  // ── Créer un frais scolaire (+ ses échéances) ──────────
  static Future<FraisScolaire> creerFrais(FraisScolaire frais) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires'),
      headers: await _headers(),
      body: jsonEncode(frais.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_messageErreur(data));
    }
    return FraisScolaire.fromJson(data['frais'] as Map<String, dynamic>);
  }

  // ── Modifier un frais scolaire ─────────────────────────
  static Future<FraisScolaire> modifierFrais(int id, FraisScolaire frais) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/$id'),
      headers: await _headers(),
      body: jsonEncode(frais.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_messageErreur(data));
    }
    return FraisScolaire.fromJson(data['frais'] as Map<String, dynamic>);
  }

  // ── Désactiver un frais scolaire (suppression soft) ────
  static Future<void> desactiverFrais(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/frais-scolaires/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(_messageErreur(data));
    }
  }

  // Laravel renvoie soit {message}, soit {message, errors:{champ:[...]}}
  // pour les erreurs de validation (422) — on affiche le premier message
  // de champ s'il est présent, sinon le message générique.
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
