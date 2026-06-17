import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class UtilisateurService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Liste des utilisateurs ────────────────────────────
  static Future<List<dynamic>> listerUtilisateurs() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement utilisateurs');
  }

  // ── Créer un utilisateur ──────────────────────────────
  static Future<Map<String, dynamic>> creerUtilisateur({
    required String nom,
    required String email,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs'),
      headers: await _headers(),
      body: jsonEncode({'nom': nom, 'email': email, 'role': role}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Erreur création utilisateur');
  }

  // ── Modifier le rôle ──────────────────────────────────
  static Future<void> modifierRole(int id, String role) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/utilisateurs/$id/role'),
      headers: await _headers(),
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur modification rôle');
    }
  }

  // ── Changer mot de passe ──────────────────────────────
  static Future<void> changerMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/changer-mot-de-passe'),
      headers: await _headers(),
      body: jsonEncode({
        'ancien_mot_de_passe':             ancienMotDePasse,
        'nouveau_mot_de_passe':            nouveauMotDePasse,
        'nouveau_mot_de_passe_confirmation': nouveauMotDePasse,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur changement mot de passe');
    }
  }
}