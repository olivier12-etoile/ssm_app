import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // ── Détermine la route selon le rôle de l'utilisateur ──
  String _routeSelonRole(String? role) {
    switch (role) {
      case 'enseignant':
        return '/dashboard/enseignant';
      case 'censeur':
        return '/dashboard/censeur';
      case 'secretaire':
        return '/dashboard/secretaire';
      default: // directeur, super_admin
        return '/tableau-de-bord';
    }
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
        final utilisateur = await AuthService.getUtilisateur();

        // Si mot de passe pas encore changé, priorité à cet écran
        if (utilisateur != null && !utilisateur.motDePasseChange) {
          Navigator.pushReplacementNamed(context, '/changer-mot-de-passe');
          return;
        }

        final route = _routeSelonRole(utilisateur?.role);
        Navigator.pushReplacementNamed(context, route);
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
      body: Stack(
        children: [
          // ── Fond dégradé ─────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.6, 1.0],
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF1E3A8A),
                    Color(0xFFF1F5F9),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo SSM ─────────────────────────────
                    const Icon(Icons.school, size: 64, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'SSM',
                      style: GoogleFonts.sora(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart School Manager',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Carte formulaire ─────────────────────
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connexion',
                            style: GoogleFonts.sora(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Accédez à votre espace école',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Code école
                          TextField(
                            controller: _codeEcoleController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Code école',
                              prefixIcon: Icon(Icons.business_outlined,
                                  color: Color(0xFF1E3A8A)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: Color(0xFF1E3A8A)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Mot de passe
                          TextField(
                            controller: _motDePasseController,
                            obscureText: !_motDePasseVisible,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outlined,
                                  color: Color(0xFF1E3A8A)),
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

                          // ── Bouton connexion ──────────────
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E3A8A)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _chargement ? null : _connecter,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _chargement
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Se connecter',
                                      style: GoogleFonts.sora(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Lien inscription ──────────────
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Fonctionnalité d\'inscription à venir'),
                                  ),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Pas encore inscrit ? ',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Inscrire mon école',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
