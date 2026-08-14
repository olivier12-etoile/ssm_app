import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/caisse_model.dart';

class CaisseService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Caisses ──────────────────────────────────────────────

  static Future<List<Caisse>> getCaisses() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/caisses'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement des caisses');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((c) => Caisse.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<Caisse> creerCaisse(String nom) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/caisses'),
      headers: await _headers(),
      body: jsonEncode({'nom': nom}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur création de la caisse');
    }
    return Caisse.fromJson(data['caisse'] as Map<String, dynamic>);
  }

  // ── Sessions de caisse ───────────────────────────────────

  static Future<SessionCaisse> ouvrirCaisse(int caisseId, double montantInitial) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/caisses/ouvrir'),
      headers: await _headers(),
      body: jsonEncode({
        'caisse_id': caisseId,
        'montant_initial': montantInitial,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur ouverture de la caisse');
    }
    return SessionCaisse.fromJson(data['session'] as Map<String, dynamic>);
  }

  static Future<SessionCaisse> fermerCaisse(
    int sessionId,
    double montantReel,
    String? observation,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/caisses/fermer'),
      headers: await _headers(),
      body: jsonEncode({
        'session_id': sessionId,
        'montant_reel': montantReel,
        'observation': observation,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur fermeture de la caisse');
    }
    return SessionCaisse.fromJson(data['session'] as Map<String, dynamic>);
  }

  static Future<SessionCaisse?> getSessionActive(int caisseId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/caisses/$caisseId/session-active'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement de la session active');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final session = data['session_active'];
    return session == null ? null : SessionCaisse.fromJson(session as Map<String, dynamic>);
  }

  static Future<List<SessionCaisse>> getHistoriqueSessions(
    int caisseId, {
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{};
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/paiements/caisses/$caisseId/historique')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement de l\'historique des sessions');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((s) => SessionCaisse.fromJson(s as Map<String, dynamic>)).toList();
  }

  // ── Statut financier élève ───────────────────────────────

  static Future<StatutFinancierEleve> getStatutFinancier(int eleveId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/eleves/$eleveId/statut-financier'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement du statut financier');
    }
    return StatutFinancierEleve.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Corrections de paiement (réservé au directeur) ──────

  static Future<Correction> creerCorrection({
    required int paiementId,
    double? nouveauMontant,
    String? nouveauModePaiement,
    required String motif,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/corrections'),
      headers: await _headers(),
      body: jsonEncode({
        'paiement_id': paiementId,
        'nouveau_montant': nouveauMontant,
        'nouveau_mode_paiement': nouveauModePaiement,
        'motif': motif,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur lors de la correction du paiement');
    }
    return Correction.fromJson(data['correction'] as Map<String, dynamic>);
  }

  static Future<List<Correction>> getHistoriqueCorrections(int paiementId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/corrections/$paiementId/historique'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur chargement de l\'historique des corrections');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((c) => Correction.fromJson(c as Map<String, dynamic>)).toList();
  }
}
