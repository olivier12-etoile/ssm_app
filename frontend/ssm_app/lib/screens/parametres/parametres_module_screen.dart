import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
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

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Paramètres de l'École (même logique que
// notes_module_screen.dart / statistiques_module_screen.dart / dernier
// module migré vers le design flat/clean). Les 10 sections de
// l'arborescence du brief sont toutes câblées : Établissement, Direction,
// Scolarité, Finance et Notifications (première moitié) ; Utilisateurs &
// permissions, Sécurité, Apparence, Système et Actions avancées (seconde
// moitié). Utilisateurs & permissions et Actions avancées restent
// réservées au directeur dans ce menu ; Sécurité/Apparence/Système sont
// ouvertes à tous les rôles (chaque écran applique ensuite ses propres
// restrictions internes).
// ══════════════════════════════════════════════════════════
class ParametresModuleScreen extends StatefulWidget {
  const ParametresModuleScreen({super.key});

  @override
  State<ParametresModuleScreen> createState() => _ParametresModuleScreenState();
}

class _ParametresModuleScreenState extends State<ParametresModuleScreen> {
  Utilisateur? _utilisateur;
  String _nomEcole = 'Mon établissement';
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (!mounted) return;
    setState(() {
      _utilisateur = utilisateur;
      _chargement = false;
    });
    _chargerNomEcole();
  }

  Future<void> _chargerNomEcole() async {
    try {
      final infos = await ParametreEcoleService.getInformationsEtablissement();
      final nom = infos.nomCourt ?? infos.nomOfficiel;
      if (mounted && nom != null) setState(() => _nomEcole = nom);
    } catch (_) {
      // Le nom générique de repli reste affiché si le chargement échoue.
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

  void _naviguer(String route) {
    if (route == '/parametres') return;
    Navigator.pushNamed(context, route);
  }

  void _ouvrir(Widget ecran) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
  }

  List<SSMNavSection> _sections() {
    final role = _utilisateur?.role;

    if (role == 'enseignant') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/enseignant'),
        ]),
        const SSMNavSection(titre: 'Mes classes', items: [
          SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
          SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Mon emploi du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    if (role == 'censeur') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/censeur'),
        ]),
        const SSMNavSection(titre: 'Pédagogie', items: [
          SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
          SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins', route: '/bulletins'),
          SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emplois du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Pilotage', items: [
          SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
          SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    if (role == 'secretaire') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/secretaire'),
          SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
          SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    // Directeur, comptable, super_admin : même structure que le dashboard
    // directeur (voir notes_module_screen.dart pour le précédent).
    return [
      const SSMNavSection(titre: 'Principal', items: [
        SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      const SSMNavSection(titre: 'Pilotage', items: [
        SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
    ];
  }

  String _libelleRole(String? role) {
    switch (role) {
      case 'directeur':
        return 'Directeur';
      case 'censeur':
        return 'Censeur';
      case 'secretaire':
        return 'Secrétaire';
      case 'comptable':
        return 'Comptable';
      case 'enseignant':
        return 'Enseignant';
      default:
        return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(
        backgroundColor: SSMPalette.fond,
        body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }
    if (_utilisateur == null) {
      return Scaffold(
        backgroundColor: SSMPalette.fond,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger votre profil. Reconnectez-vous.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: SSMPalette.texte2),
            ),
          ),
        ),
      );
    }

    return SSMPageScaffold(
      nomEcole: _nomEcole,
      codeEcole: _utilisateur!.codeEcole,
      nomUtilisateur: _utilisateur!.nom,
      role: _libelleRole(_utilisateur!.role),
      sections: _sections(),
      routeActuelle: '/parametres',
      onNavigate: _naviguer,
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Paramètres école',
      child: _corps(),
    );
  }

  Widget _corps() {
    final visibles = _sectionsVisibles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Paramètres de l'École", style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        const SizedBox(height: 3),
        Text('Configuration générale, académique, financière et sécurité', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
        const SizedBox(height: 16),
        if (!_estDirecteur) ...[
          const SSMAlertItem(
            type: SSMAlerteType.avertissement,
            icone: Icons.info_outline,
            titre: 'Lecture seule',
            sousTitre: 'Seul le directeur peut modifier les paramètres de l\'école.',
          ),
          const SizedBox(height: 16),
        ],
        if (visibles.contains('etablissement')) ...[
          _sectionPanel(
            emoji: '🏫',
            titre: 'Établissement',
            items: [
              _SousItem('Informations générales', () => _ouvrir(const InformationsEtablissementScreen())),
              _SousItem('Identité visuelle (logo, couleurs)', () => _ouvrir(const IdentiteVisuelleScreen())),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (visibles.contains('direction')) ...[
          _sectionPanel(
            emoji: '🧑‍💼',
            titre: 'Direction',
            items: [
              _SousItem('Informations du directeur', () => _ouvrir(const DirectionScreen())),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (visibles.contains('scolarite')) ...[
          _sectionPanel(
            emoji: '🎓',
            titre: 'Scolarité',
            items: [
              _SousItem('Organisation académique', () => _ouvrir(const ScolariteScreen(ongletInitial: 0))),
              _SousItem('Notes & moyennes', () => _ouvrir(const ScolariteScreen(ongletInitial: 1))),
              _SousItem('Bulletins', () => _ouvrir(const ScolariteScreen(ongletInitial: 2))),
              _SousItem('Règles de validation', () => _ouvrir(const ScolariteScreen(ongletInitial: 3))),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (visibles.contains('finance')) ...[
          _sectionPanel(
            emoji: '💰',
            titre: 'Finance',
            items: [
              _SousItem('Frais scolaires et pénalités', () => _ouvrir(const FinanceEcoleScreen())),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (visibles.contains('notifications')) ...[
          _sectionPanel(
            emoji: '🔔',
            titre: 'Notifications',
            items: [
              _SousItem('Types de notifications', () => _ouvrir(const NotificationsEcoleScreen())),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_estDirecteur) ...[
          _sectionSimple(emoji: '👥', titre: 'Utilisateurs & permissions', sousTitre: 'Matrice des droits par rôle', onTap: () => _ouvrir(const PermissionsScreen())),
          const SizedBox(height: 12),
        ],
        // Sécurité, Apparence et Système concernent le compte de
        // l'utilisateur connecté (mot de passe, sessions, préférences
        // personnelles) ou sont de simples écrans d'information : pas de
        // raison de les masquer aux rôles non-directeur. Chaque écran
        // applique ensuite ses propres restrictions internes (ex. Journal
        // des actions réservé directeur/censeur dans SecuriteScreen).
        _sectionSimple(emoji: '🔐', titre: 'Sécurité', sousTitre: 'Mot de passe, sessions, historique', onTap: () => _ouvrir(const SecuriteScreen())),
        const SizedBox(height: 12),
        _sectionSimple(emoji: '🎨', titre: 'Apparence', sousTitre: 'Préférences personnelles d\'affichage', onTap: () => _ouvrir(const ApparenceScreen())),
        const SizedBox(height: 12),
        _sectionSimple(emoji: '🛠️', titre: 'Système', sousTitre: 'Version, serveur, synchronisation', onTap: () => _ouvrir(const SystemeScreen())),
        if (_estDirecteur) ...[
          const SizedBox(height: 12),
          _sectionDanger(emoji: '⚠️', titre: 'Actions avancées', sousTitre: 'Archivage, réinitialisation — zone sensible', onTap: () => _ouvrir(const ActionsAvanceesScreen())),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionPanel({required String emoji, required String titre, required List<_SousItem> items}) {
    return SSMPanel(
      titre: '$emoji  $titre',
      padding: EdgeInsets.zero,
      child: Column(
        children: [for (final item in items) _ligneMenu(item, dernier: item == items.last)],
      ),
    );
  }

  Widget _ligneMenu(_SousItem item, {required bool dernier}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: dernier ? null : const Border(bottom: BorderSide(color: SSMPalette.bordure))),
          child: Row(
            children: [
              Expanded(child: Text(item.titre, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1))),
              const Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionSimple({required String emoji, required String titre, required String sousTitre, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: SSMPalette.blanc,
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                    const SizedBox(height: 2),
                    Text(sousTitre, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SSMPalette.texte3, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionDanger({required String emoji, required String titre, required String sousTitre, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F5),
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.rouge.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
                    const SizedBox(height: 2),
                    Text(sousTitre, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SSMPalette.rouge, size: 20),
            ],
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
