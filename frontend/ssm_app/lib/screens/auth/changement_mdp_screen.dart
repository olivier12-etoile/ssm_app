import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        final utilisateur = await AuthService.getUtilisateur();
        final route = _routeSelonRole(utilisateur?.role);
        Navigator.pushReplacementNamed(context, route);
      }
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
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
                    // ── Icône ambre ───────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 40,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 32),

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
                            'Changement de mot de passe',
                            style: GoogleFonts.sora(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vous devez changer votre mot de passe\navant de continuer.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Mot de passe temporaire
                          TextField(
                            controller: _ancienController,
                            obscureText: !_ancienVisible,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe temporaire',
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: Color(0xFF1E3A8A)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ancienVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _ancienVisible = !_ancienVisible,
                                ),
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
                              prefixIcon: const Icon(Icons.lock,
                                  color: Color(0xFF1E3A8A)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _nouveauVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _nouveauVisible = !_nouveauVisible,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Bouton confirmer ──────────────
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD97706)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _chargement ? null : _changer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
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
                                      'Confirmer',
                                      style: GoogleFonts.sora(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
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
