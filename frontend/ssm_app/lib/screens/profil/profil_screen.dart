import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/ssm_widgets.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Map<String, dynamic>? _profil;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _chargerProfil() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/profil'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        setState(() {
          _profil     = jsonDecode(response.body);
          _chargement = false;
        });
      }
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogModifierNom() async {
    final nomController = TextEditingController(
      text: _profil?['nom'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier mon nom'),
        content: TextField(
          controller: nomController,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) return;
              try {
                final response = await http.patch(
                  Uri.parse('${AppConfig.apiBaseUrl}/profil'),
                  headers: await _headers(),
                  body: jsonEncode({'nom': nomController.text}),
                );
                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _afficherSucces('Nom mis à jour');
                  _chargerProfil();
                }
              } catch (e) {
                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherDialogMotDePasse() async {
    final ancienController  = TextEditingController();
    final nouveauController = TextEditingController();
    bool ancienVisible      = false;
    bool nouveauVisible     = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Changer le mot de passe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ancienController,
                  obscureText: !ancienVisible,
                  decoration: InputDecoration(
                    labelText: 'Ancien mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(ancienVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setStateDialog(
                          () => ancienVisible = !ancienVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nouveauController,
                  obscureText: !nouveauVisible,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(nouveauVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setStateDialog(
                          () => nouveauVisible = !nouveauVisible),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (ancienController.text.isEmpty ||
                      nouveauController.text.isEmpty) return;
                  if (nouveauController.text.length < 6) {
                    _afficherErreur('Minimum 6 caractères');
                    return;
                  }
                  try {
                    final response = await http.post(
                      Uri.parse(
                          '${AppConfig.apiBaseUrl}/profil/mot-de-passe'),
                      headers: await _headers(),
                      body: jsonEncode({
                        'ancien_mot_de_passe':                 ancienController.text,
                        'nouveau_mot_de_passe':                nouveauController.text,
                        'nouveau_mot_de_passe_confirmation':   nouveauController.text,
                      }),
                    );
                    final data = jsonDecode(response.body);
                    if (response.statusCode == 200) {
                      Navigator.pop(context);
                      _afficherSucces('Mot de passe changé');
                    } else {
                      _afficherErreur(
                          data['message'] ?? 'Erreur');
                    }
                  } catch (e) {
                    _afficherErreur(
                        e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mon profil',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _profil == null
              ? const Center(child: Text('Erreur chargement profil'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // ── En-tête profil ─────────────────────
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF1E3A8A),
                        child: Text(
                          (_profil!['nom'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: GoogleFonts.sora(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _profil!['nom'] as String,
                        style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SSMBadge(
                        label: (_profil!['role'] as String).toUpperCase(),
                        couleur: const Color(0xFF1E3A8A),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _profil!['email'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Informations personnelles ──────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SSMSectionTitre(titre: 'Informations personnelles'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            SSMListeTile(
                              titre: 'Email',
                              sousTitre: _profil!['email'] as String,
                              icone: Icons.email,
                              couleurIcone: const Color(0xFF1E3A8A),
                            ),
                            SSMListeTile(
                              titre: 'Rôle',
                              sousTitre: _profil!['role'] as String,
                              icone: Icons.badge,
                              couleurIcone: const Color(0xFF1E3A8A),
                            ),
                            if (_profil!['ecole'] != null) ...[
                              SSMListeTile(
                                titre: 'École',
                                sousTitre: _profil!['ecole']['nom'] as String,
                                icone: Icons.school,
                                couleurIcone: const Color(0xFF1E3A8A),
                              ),
                              SSMListeTile(
                                titre: 'Code école',
                                icone: Icons.qr_code,
                                couleurIcone: const Color(0xFF1E3A8A),
                                trailing: Text(
                                  _profil!['ecole']['code_ecole'] as String,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (_profil!['ecole']['telephone'] != null)
                                SSMListeTile(
                                  titre: 'Téléphone',
                                  sousTitre:
                                      _profil!['ecole']['telephone'] as String,
                                  icone: Icons.phone,
                                  couleurIcone: const Color(0xFF1E3A8A),
                                ),
                              if (_profil!['ecole']['adresse'] != null)
                                SSMListeTile(
                                  titre: 'Adresse',
                                  sousTitre:
                                      _profil!['ecole']['adresse'] as String,
                                  icone: Icons.location_on,
                                  couleurIcone: const Color(0xFF1E3A8A),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _afficherDialogModifierNom,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modifier'),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Sécurité ────────────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SSMSectionTitre(titre: 'Sécurité'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SSMListeTile(
                          titre: 'Mot de passe',
                          sousTitre: '••••••••',
                          icone: Icons.lock,
                          couleurIcone: const Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _afficherDialogMotDePasse,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modifier'),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Déconnexion ───────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await AuthService.deconnecter();
                            if (mounted) {
                              Navigator.pushReplacementNamed(
                                  context, '/login');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: Text(
                            'Se déconnecter',
                            style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
