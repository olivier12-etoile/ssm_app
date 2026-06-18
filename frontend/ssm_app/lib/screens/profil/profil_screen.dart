import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';

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
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Color _couleurRole(String role) {
    switch (role) {
      case 'directeur':  return Colors.blue;
      case 'censeur':    return Colors.purple;
      case 'secretaire': return Colors.teal;
      case 'enseignant': return Colors.orange;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: Colors.blueGrey,
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
                      // ── Avatar ────────────────────────────
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: _couleurRole(
                            _profil!['role'] as String),
                        child: Text(
                          (_profil!['nom'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _profil!['nom'] as String,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _couleurRole(_profil!['role'] as String)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _couleurRole(
                                    _profil!['role'] as String)
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          (_profil!['role'] as String).toUpperCase(),
                          style: TextStyle(
                            color: _couleurRole(
                                _profil!['role'] as String),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Infos personnelles ────────────────
                      _sectionCard(
                        titre: 'Informations personnelles',
                        enfants: [
                          _infoLigne(
                              Icons.email, 'Email', _profil!['email']),
                          _infoLigne(
                              Icons.badge, 'Rôle', _profil!['role']),
                        ],
                        bouton: TextButton.icon(
                          onPressed: _afficherDialogModifierNom,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modifier le nom'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Infos école ───────────────────────
                      if (_profil!['ecole'] != null)
                        _sectionCard(
                          titre: 'Mon école',
                          enfants: [
                            _infoLigne(
                                Icons.school,
                                'Nom',
                                _profil!['ecole']['nom']),
                            _infoLigne(
                                Icons.qr_code,
                                'Code école',
                                _profil!['ecole']['code_ecole']),
                            if (_profil!['ecole']['telephone'] != null)
                              _infoLigne(
                                  Icons.phone,
                                  'Téléphone',
                                  _profil!['ecole']['telephone']),
                            if (_profil!['ecole']['adresse'] != null)
                              _infoLigne(
                                  Icons.location_on,
                                  'Adresse',
                                  _profil!['ecole']['adresse']),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // ── Sécurité ──────────────────────────
                      _sectionCard(
                        titre: 'Sécurité',
                        enfants: [
                          _infoLigne(
                            Icons.lock,
                            'Mot de passe',
                            '••••••••',
                          ),
                        ],
                        bouton: TextButton.icon(
                          onPressed: _afficherDialogMotDePasse,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Changer le mot de passe'),
                        ),
                      ),
                      const SizedBox(height: 24),

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
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Se déconnecter',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionCard({
    required String titre,
    required List<Widget> enfants,
    Widget? bouton,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
                if (bouton != null) bouton,
              ],
            ),
            const Divider(),
            ...enfants,
          ],
        ),
      ),
    );
  }

  Widget _infoLigne(IconData icone, String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: const TextStyle(color: Colors.grey),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}