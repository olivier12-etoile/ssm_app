import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import 'informations_etablissement_screen.dart';
import 'identite_visuelle_screen.dart';
import 'direction_screen.dart';
import 'scolarite_screen.dart';
import 'finance_ecole_screen.dart';
import 'notifications_ecole_screen.dart';
import 'permissions_screen.dart';
import 'securite_screen.dart';
import 'apparence_screen.dart';
import 'systeme_screen.dart';
import 'actions_avancees_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _rouge = Color(0xFFDC2626);
const Color _violet = Color(0xFF7C3AED);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _gris = Color(0xFF94A3B8);
const Color _fond = Color(0xFFEFF6FF);

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Paramètres de l'École (même logique que
// notes_module_screen.dart / statistiques_module_screen.dart). Les 10
// sections de l'arborescence du brief sont toutes câblées :
// Établissement, Direction, Scolarité, Finance et Notifications
// (première moitié) ; Utilisateurs & permissions, Sécurité, Apparence,
// Système et Actions avancées (seconde moitié). Utilisateurs &
// permissions et Actions avancées restent réservées au directeur dans ce
// menu ; Sécurité/Apparence/Système sont ouvertes à tous les rôles
// (chaque écran applique ensuite ses propres restrictions internes).
// ══════════════════════════════════════════════════════════
class ParametresModuleScreen extends StatefulWidget {
  const ParametresModuleScreen({super.key});

  @override
  State<ParametresModuleScreen> createState() => _ParametresModuleScreenState();
}

class _ParametresModuleScreenState extends State<ParametresModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargement = true;
  String? _sectionOuverte;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (mounted) {
      setState(() {
        _utilisateur = utilisateur;
        _chargement = false;
      });
    }
  }

  bool get _estDirecteur => _utilisateur?.estDirecteur == true;

  // Sous-ensemble de sections visibles pour les rôles non-directeur,
  // aligné sur les modules déjà accordés à ces rôles par défaut dans la
  // matrice de permissions (PermissionRole::defauts(), Phase 4 backend) :
  // le censeur supervise pédagogie + validation + notifications, le
  // secrétariat/comptabilité gère élèves + finances, l'enseignant n'a rien
  // de spécifique aux réglages d'école.
  Set<String> get _sectionsVisibles {
    if (_estDirecteur) return _toutesLesSections;
    switch (_utilisateur?.role) {
      case 'censeur':
        return {'etablissement', 'scolarite', 'notifications'};
      case 'secretaire':
      case 'comptable':
        return {'etablissement', 'finance'};
      default: // enseignant, super_admin, ou profil non résolu
        return {'etablissement'};
    }
  }

  static const _toutesLesSections = {
    'etablissement',
    'direction',
    'scolarite',
    'finance',
    'notifications',
    'utilisateurs',
    'securite',
    'apparence',
    'systeme',
    'actions_avancees',
  };

  // ── Navigation ────────────────────────────────────────

  String get _routeDashboardPrincipal {
    switch (_utilisateur?.role) {
      case 'enseignant':
        return '/dashboard/enseignant';
      case 'censeur':
        return '/dashboard/censeur';
      case 'secretaire':
        return '/dashboard/secretaire';
      default: // directeur, comptable, super_admin
        return '/tableau-de-bord';
    }
  }

  void _retour() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, _routeDashboardPrincipal);
    }
  }

  void _ouvrir(Widget ecran) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
  }

  void _basculerSection(String cle) {
    setState(() => _sectionOuverte = _sectionOuverte == cle ? null : cle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _retour),
        title: Text("Paramètres de l'École", style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _corps(),
    );
  }

  Widget _corps() {
    final visibles = _sectionsVisibles;

    return Stack(
      children: [
        Positioned(top: -80, right: -60, child: _blob(size: 260, couleur: _indigo.withValues(alpha: 0.08))),
        Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10))),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_estDirecteur) _bandeauLectureSeule(),
              if (!_estDirecteur) const SizedBox(height: 16),

              _carteSection(
                cle: 'etablissement',
                icone: Icons.apartment_outlined,
                couleur: _indigo,
                titre: 'Établissement',
                sousTitre: 'Informations générales, logo, identité visuelle',
                visible: visibles.contains('etablissement'),
                sousItems: [
                  _SousItem('Informations générales', () => _ouvrir(const InformationsEtablissementScreen())),
                  _SousItem('Identité visuelle (logo, couleurs)', () => _ouvrir(const IdentiteVisuelleScreen())),
                ],
              ),
              const SizedBox(height: 12),

              _carteSection(
                cle: 'direction',
                icone: Icons.badge_outlined,
                couleur: _teal,
                titre: 'Direction',
                sousTitre: 'Informations du directeur',
                visible: visibles.contains('direction'),
                sousItems: [
                  _SousItem('Informations du directeur', () => _ouvrir(const DirectionScreen())),
                ],
              ),
              const SizedBox(height: 12),

              _carteSection(
                cle: 'scolarite',
                icone: Icons.school_outlined,
                couleur: _ambre,
                titre: 'Scolarité',
                sousTitre: 'Organisation académique, notes & moyennes, bulletins, validation',
                visible: visibles.contains('scolarite'),
                sousItems: [
                  _SousItem('Organisation académique', () => _ouvrir(const ScolariteScreen(ongletInitial: 0))),
                  _SousItem('Notes & moyennes', () => _ouvrir(const ScolariteScreen(ongletInitial: 1))),
                  _SousItem('Bulletins', () => _ouvrir(const ScolariteScreen(ongletInitial: 2))),
                  _SousItem('Règles de validation', () => _ouvrir(const ScolariteScreen(ongletInitial: 3))),
                ],
              ),
              const SizedBox(height: 12),

              _carteSection(
                cle: 'finance',
                icone: Icons.payments_outlined,
                couleur: const Color(0xFF16A34A),
                titre: 'Finance',
                sousTitre: 'Frais scolaires, échéances, règles élèves non en règle',
                visible: visibles.contains('finance'),
                sousItems: [
                  _SousItem('Frais scolaires et pénalités', () => _ouvrir(const FinanceEcoleScreen())),
                ],
              ),
              const SizedBox(height: 12),

              _carteSection(
                cle: 'notifications',
                icone: Icons.notifications_active_outlined,
                couleur: _rouge,
                titre: 'Notifications',
                sousTitre: 'Parents, enseignants',
                visible: visibles.contains('notifications'),
                sousItems: [
                  _SousItem('Types de notifications', () => _ouvrir(const NotificationsEcoleScreen())),
                ],
              ),
              const SizedBox(height: 12),

              if (_estDirecteur) ...[
                _carteSimple(
                  icone: Icons.admin_panel_settings_outlined,
                  couleur: _violet,
                  titre: 'Utilisateurs & permissions',
                  sousTitre: 'Matrice des droits par rôle',
                  onTap: () => _ouvrir(const PermissionsScreen()),
                ),
                const SizedBox(height: 12),
              ],

              // Sécurité, Apparence et Système concernent le compte de
              // l'utilisateur connecté (mot de passe, sessions, préférences
              // personnelles) ou sont de simples écrans d'information : pas
              // de raison de les masquer aux rôles non-directeur. Chaque
              // écran applique ensuite ses propres restrictions internes
              // (ex. Journal des actions réservé directeur/censeur dans
              // SecuriteScreen).
              _carteSimple(
                icone: Icons.lock_outline,
                couleur: _texteFonce,
                titre: 'Sécurité',
                sousTitre: 'Mot de passe, sessions, historique',
                onTap: () => _ouvrir(const SecuriteScreen()),
              ),
              const SizedBox(height: 12),
              _carteSimple(
                icone: Icons.palette_outlined,
                couleur: const Color(0xFFDB2777),
                titre: 'Apparence',
                sousTitre: 'Préférences personnelles d\'affichage',
                onTap: () => _ouvrir(const ApparenceScreen()),
              ),
              const SizedBox(height: 12),
              _carteSimple(
                icone: Icons.settings_suggest_outlined,
                couleur: const Color(0xFF0891B2),
                titre: 'Système',
                sousTitre: 'Version, serveur, synchronisation',
                onTap: () => _ouvrir(const SystemeScreen()),
              ),

              if (_estDirecteur) ...[
                const SizedBox(height: 12),
                _carteSimple(
                  icone: Icons.warning_amber_outlined,
                  couleur: _rouge,
                  titre: 'Actions avancées',
                  sousTitre: 'Archivage, réinitialisation — zone sensible',
                  onTap: () => _ouvrir(const ActionsAvanceesScreen()),
                  accentDanger: true,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bandeauLectureSeule() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ambre.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ambre.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _ambre, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lecture seule — seul le directeur peut modifier les paramètres de l\'école.',
              style: GoogleFonts.inter(fontSize: 12, color: _texte),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({required double size, required Color couleur}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
        ),
      ),
    );
  }

  // ── Cartes glassmorphism ─────────────────────────────────

  Widget _carteSection({
    required String cle,
    required IconData icone,
    required Color couleur,
    required String titre,
    required String sousTitre,
    required bool visible,
    required List<_SousItem> sousItems,
  }) {
    if (!visible) return const SizedBox.shrink();

    final ouverte = _sectionOuverte == cle;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _basculerSection(cle),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                          child: Icon(icone, color: couleur, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
                              const SizedBox(height: 2),
                              Text(sousTitre, style: GoogleFonts.inter(fontSize: 12, color: _texte), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(ouverte ? Icons.expand_less : Icons.expand_more, color: _gris),
                      ],
                    ),
                  ),
                ),
              ),
              if (ouverte)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Column(
                    children: sousItems
                        .map((item) => Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: item.onTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.chevron_right, size: 16, color: couleur),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(item.titre, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteSimple({
    required IconData icone,
    required Color couleur,
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
    bool accentDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentDanger ? _rouge.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(icone, color: couleur, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
                        const SizedBox(height: 2),
                        Text(sousTitre, style: GoogleFonts.inter(fontSize: 12, color: _texte), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _gris, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SousItem {
  final String titre;
  final VoidCallback onTap;
  const _SousItem(this.titre, this.onTap);
}
