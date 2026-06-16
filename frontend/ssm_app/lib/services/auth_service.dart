import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/utilisateur.dart';

class AuthService {
  static const String _tokenKey      = 'token';
  static const String _utilisateurKey = 'utilisateur';

  // ── Sauvegarder le token ──────────────────────────────
  static Future<void> sauvegarderToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // ── Récupérer le token ────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ── Sauvegarder l'utilisateur ─────────────────────────
  static Future<void> sauvegarderUtilisateur(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_utilisateurKey, jsonEncode(json));
  }

  // ── Récupérer l'utilisateur ───────────────────────────
  static Future<Utilisateur?> getUtilisateur() async {
    final prefs = await SharedPreferences.getInstance();
    final str   = prefs.getString(_utilisateurKey);
    if (str == null) return null;
    return Utilisateur.fromJson(jsonDecode(str));
  }

  // ── Connexion ─────────────────────────────────────────
  static Future<Map<String, dynamic>> connecter({
    required String email,
    required String motDePasse,
    required String codeEcole,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/connexion'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email':      email,
        'password':   motDePasse,
        'code_ecole': codeEcole,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await sauvegarderToken(data['token']);
      await sauvegarderUtilisateur(data['utilisateur']);
      return data;
    }

    throw Exception(data['message'] ?? 'Erreur de connexion');
  }

  // ── Déconnexion ───────────────────────────────────────
  static Future<void> deconnecter() async {
    final token = await getToken();
    if (token != null) {
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deconnexion'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── Vérifier si connecté ──────────────────────────────
  static Future<bool> estConnecte() async {
    final token = await getToken();
    return token != null;
  }
}