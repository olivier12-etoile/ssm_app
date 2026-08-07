import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/paiement_model.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PaiementService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste des paiements (filtrable) ────────────────────
  static Future<List<dynamic>> lister({
    int? eleveId,
    int? fraisScolaireId,
    String? modePaiement,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{};
    if (eleveId != null) query['eleve_id'] = '$eleveId';
    if (fraisScolaireId != null) query['frais_scolaire_id'] = '$fraisScolaireId';
    if (modePaiement != null) query['mode_paiement'] = modePaiement;
    if (statut != null) query['statut'] = statut;
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/paiements')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement des paiements');
  }

  // Paiements d'un élève (compatibilité : conserve la forme
  // {paiements, total_paye} attendue par les écrans existants).
  static Future<Map<String, dynamic>> paiementsEleve(int eleveId) async {
    final paiements = await lister(eleveId: eleveId);
    final totalPaye = paiements
        .where((p) => p['statut'] == 'valide')
        .fold<double>(0, (total, p) => total + double.parse(p['montant'].toString()));
    return {'paiements': paiements, 'total_paye': totalPaye};
  }

  // ── Enregistrer un paiement ─────────────────────────────
  static Future<Map<String, dynamic>> enregistrer({
    required int eleveId,
    required int fraisScolaireId,
    int? echeanceId,
    required double montant,
    required String modePaiement,
    String? reference,
    required String datePaiement,
    String? observation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id': eleveId,
        'frais_scolaire_id': fraisScolaireId,
        'echeance_id': echeanceId,
        'montant': montant,
        'mode_paiement': modePaiement,
        'reference': reference,
        'date_paiement': datePaiement,
        'observation': observation,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur enregistrement du paiement');
    }
    return data['paiement'] as Map<String, dynamic>;
  }

  // ── Annuler un paiement (réservé au directeur) ──────────
  static Future<void> annuler(int id, String motifAnnulation) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/$id/annuler'),
      headers: await _headers(),
      body: jsonEncode({'motif_annulation': motifAnnulation}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Erreur annulation du paiement');
    }
  }

  // ── Télécharger le reçu en PDF ──────────────────────────
  static Future<String> telechargerRecuPdf(int paiementId) async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/$paiementId/recu'),
      headers: {'Accept': 'application/pdf', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur génération reçu PDF');
    }

    final dossier = await getApplicationDocumentsDirectory();
    final cheminFichier = '${dossier.path}/recu_$paiementId.pdf';
    final fichier = File(cheminFichier);
    await fichier.writeAsBytes(response.bodyBytes);

    return cheminFichier;
  }

  // ════════════════════════════════════════════════════════
  // API typée (Paiement / SituationFinanciere) — utilisée par
  // situation_financiere_screen.dart et nouveau_paiement_screen.dart.
  // Coexiste avec les méthodes ci-dessus (lister/enregistrer/annuler/
  // telechargerRecuPdf), déjà utilisées par d'autres écrans.
  // ════════════════════════════════════════════════════════

  // ── Situation financière complète d'un élève ────────────
  static Future<SituationFinanciere> getSituationFinanciere(
    int eleveId, {
    int? anneeScolaireId,
  }) async {
    final query = <String, String>{};
    if (anneeScolaireId != null) query['annee_scolaire_id'] = '$anneeScolaireId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/eleves/$eleveId/situation-financiere')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement de la situation financière');
    }
    return SituationFinanciere.fromJson(data as Map<String, dynamic>);
  }

  // ── Enregistrer un paiement (version typée) ─────────────
  static Future<Paiement> enregistrerPaiement(Paiement paiement) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements'),
      headers: await _headers(),
      body: jsonEncode(paiement.toJsonCreation()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erreur enregistrement du paiement');
    }
    return Paiement.fromJson(data['paiement'] as Map<String, dynamic>);
  }

  // ── Annuler un paiement (version typée, réservé au directeur) ──
  static Future<Paiement> annulerPaiement(int id, String motif) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/$id/annuler'),
      headers: await _headers(),
      body: jsonEncode({'motif_annulation': motif}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur annulation du paiement');
    }
    return Paiement.fromJson(data['paiement'] as Map<String, dynamic>);
  }

  // ── Télécharger le reçu en PDF (retourne les octets bruts) ──
  static Future<Uint8List> telechargerRecu(int paiementId) async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/paiements/$paiementId/recu'),
      headers: {'Accept': 'application/pdf', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur génération reçu PDF');
    }

    return response.bodyBytes;
  }
}
