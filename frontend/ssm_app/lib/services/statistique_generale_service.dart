import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/statistique_generale_model.dart';

// Le projet n'utilise pas Dio (voir pubspec.yaml : seul `http` est
// dépendance) — ce service suit donc le même pattern `http` + _headers()
// que tous les autres services (annee_service, dashboard_emploi_du_temps_service...).
class StatistiqueGeneraleService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // GET /statistiques/dashboard/general
  static Future<DashboardGeneral> getDashboardGeneral({
    required int anneeScolaireId,
    int? periodeId,
  }) async {
    final query = <String, String>{'annee_scolaire_id': '$anneeScolaireId'};
    if (periodeId != null) query['periode_id'] = '$periodeId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/statistiques/dashboard/general')
        .replace(queryParameters: query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return DashboardGeneral.fromJson(data as Map<String, dynamic>);
    throw Exception(_messageErreur(data));
  }

  // POST /statistiques/dashboard/snapshot
  static Future<Map<String, dynamic>> creerSnapshot(int anneeScolaireId, String type) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/statistiques/dashboard/snapshot'),
      headers: await _headers(),
      body: jsonEncode({'annee_scolaire_id': anneeScolaireId, 'type': type}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data as Map<String, dynamic>;
    throw Exception(_messageErreur(data));
  }

  // GET /statistiques/dashboard/comparaison
  static Future<Map<String, dynamic>> comparerAnnees(int annee1, int annee2, String type) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/statistiques/dashboard/comparaison').replace(
      queryParameters: {'annee1': '$annee1', 'annee2': '$annee2', 'type': type},
    );
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data as Map<String, dynamic>;
    throw Exception(_messageErreur(data));
  }

  // GET /statistiques/inscriptions/evolution — réutilisé ici pour le
  // graphique "évolution des effectifs" du tableau de bord général ;
  // {labels, valeurs, detail}, déjà prêt côté API pour un graphique.
  static Future<Map<String, dynamic>> getEvolutionEffectifs({int nombreAnnees = 5}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/statistiques/inscriptions/evolution')
        .replace(queryParameters: {'nombre_annees': '$nombreAnnees'});
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data as Map<String, dynamic>;
    throw Exception(_messageErreur(data));
  }

  // GET /statistiques/centre-decision/alertes — réutilisé ici uniquement
  // pour le total (badge "Centre de Décision" du tableau de bord général) ;
  // le détail des alertes revient à l'écran dédié (Phase 5).
  static Future<int> getNombreAlertes({required int anneeScolaireId, required int periodeId}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/statistiques/centre-decision/alertes').replace(
      queryParameters: {'annee_scolaire_id': '$anneeScolaireId', 'periode_id': '$periodeId'},
    );
    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return (data['total'] as num?)?.toInt() ?? 0;
    throw Exception(_messageErreur(data));
  }

  static String _messageErreur(dynamic data) {
    if (data is Map && data['errors'] is Map) {
      final erreurs = (data['errors'] as Map).values.first;
      if (erreurs is List && erreurs.isNotEmpty) return erreurs.first.toString();
    }
    if (data is Map && data['message'] != null) return data['message'].toString();
    return 'Une erreur est survenue';
  }
}
