import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController      = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _codeEcoleController  = TextEditingController();
  bool _chargement            = false;
  bool _motDePasseVisible     = false;

  @override
  void dispose() {
    _emailController.dispose();
    _motDePasseController.dispose();
    _codeEcoleController.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
  if (_emailController.text.isEmpty ||
      _motDePasseController.text.isEmpty ||
      _codeEcoleController.text.isEmpty) {
    _afficherErreur('Veuillez remplir tous les champs');
    return;
  }

  setState(() => _chargement = true);

  try {
    await AuthService.connecter(
      email:      _emailController.text.trim(),
      motDePasse: _motDePasseController.text,
      codeEcole:  _codeEcoleController.text.trim().toUpperCase(),
    );

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/tableau-de-bord');
    }
  } catch (e) {
    // Affiche l'erreur exacte pour déboguer
    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    debugPrint('ERREUR CONNEXION: $e');
  } finally {
    if (mounted) setState(() => _chargement = false);
  }
}

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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
                    // Logo
                    const Icon(Icons.school, size: 64, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart School Manager',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connectez-vous à votre espace',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // Code école
                    TextField(
                      controller: _codeEcoleController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Code école',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mot de passe
                    TextField(
                      controller: _motDePasseController,
                      obscureText: !_motDePasseVisible,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _motDePasseVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _motDePasseVisible = !_motDePasseVisible,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton connexion
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _chargement ? null : _connecter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _chargement
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 16),
                              ),
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