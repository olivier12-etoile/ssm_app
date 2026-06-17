import 'package:flutter/material.dart';
import '../../services/utilisateur_service.dart';
import '../../services/auth_service.dart';

class ChangementMdpScreen extends StatefulWidget {
  const ChangementMdpScreen({super.key});

  @override
  State<ChangementMdpScreen> createState() => _ChangementMdpScreenState();
}

class _ChangementMdpScreenState extends State<ChangementMdpScreen> {
  final _ancienController   = TextEditingController();
  final _nouveauController  = TextEditingController();
  bool _chargement          = false;
  bool _ancienVisible       = false;
  bool _nouveauVisible      = false;

  @override
  void dispose() {
    _ancienController.dispose();
    _nouveauController.dispose();
    super.dispose();
  }

  Future<void> _changer() async {
    if (_ancienController.text.isEmpty || _nouveauController.text.isEmpty) {
      _afficherErreur('Veuillez remplir tous les champs');
      return;
    }
    if (_nouveauController.text.length < 6) {
      _afficherErreur('Le nouveau mot de passe doit faire au moins 6 caractères');
      return;
    }

    setState(() => _chargement = true);

    try {
      await UtilisateurService.changerMotDePasse(
        ancienMotDePasse:  _ancienController.text,
        nouveauMotDePasse: _nouveauController.text,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/tableau-de-bord');
      }
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_reset, size: 64, color: Colors.orange),
                    const SizedBox(height: 8),
                    const Text(
                      'Changement de mot de passe',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous devez changer votre mot de passe\navant de continuer.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Ancien mot de passe
                    TextField(
                      controller: _ancienController,
                      obscureText: !_ancienVisible,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe temporaire',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_ancienVisible
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _ancienVisible = !_ancienVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nouveau mot de passe
                    TextField(
                      controller: _nouveauController,
                      obscureText: !_nouveauVisible,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_nouveauVisible
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _nouveauVisible = !_nouveauVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _chargement ? null : _changer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _chargement
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Confirmer',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}