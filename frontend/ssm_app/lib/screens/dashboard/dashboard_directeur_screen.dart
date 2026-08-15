import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/statistique_detail_model.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import '../../widgets/ssm/ssm_topbar.dart';
import '../statistiques/centre_decision_screen.dart';
import 'dashboard_directeur_view_model.dart';

// ══════════════════════════════════════════════════════════
// DashboardDirecteurScreen — Tableau de bord du directeur,
// reconstruit avec le design system SSM (flat/clean) et
// entièrement connecté aux services existants.
// ══════════════════════════════════════════════════════════
class DashboardDirecteurScreen extends StatefulWidget {
  const DashboardDirecteurScreen({super.key});

  @override
  State<DashboardDirecteurScreen> createState() => _DashboardDirecteurScreenState();
}

class _DashboardDirecteurScreenState extends State<DashboardDirecteurScreen> {
  DashboardDirecteurDonnees? _donnees;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final donnees = await DashboardDirecteurViewModel.charger();
    if (!mounted) return;
    setState(() {
      _donnees = donnees;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _donnees;
    final utilisateur = d?.utilisateur;

    return SSMPageScaffold(
      nomEcole: d?.nomEcole ?? 'Mon établissement',
      codeEcole: utilisateur?.codeEcole ?? '—',
      nomUtilisateur: utilisateur?.nom ?? '…',
      role: _libelleRole(utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/tableau-de-bord',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Tableau de bord',
      periodePill: (d?.libellePeriodeActive != null)
          ? SSMPeriodePill(
              texte: d!.libellePeriodeActive!,
              badge: d.periodeEnCours ? 'EN COURS' : null,
            )
          : null,
      onNotificationTap: () => Navigator.pushNamed(context, '/notifications'),
      hasNotification: (d?.notificationsNonLues ?? 0) > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeRow(),
          const SizedBox(height: 18),
          _statsGrid(),
          const SizedBox(height: 12),
          _deuxColonnes(context),
          const SizedBox(height: 14),
          _actionsRapides(context),
        ],
      ),
    );
  }

  void _naviguer(BuildContext context, String route) {
    if (route == '/tableau-de-bord') return;
    Navigator.pushNamed(context, route);
  }

  String _libelleRole(String? role) {
    switch (role) {
      case 'directeur':
        return 'Directeur';
      case 'censeur':
        return 'Censeur';
      case 'secretaire':
        return 'Secrétaire';
      case 'enseignant':
        return 'Enseignant';
      case 'comptable':
        return 'Comptable';
      case 'super_admin':
        return 'Super admin';
      default:
        return role ?? '';
    }
  }

  // ── Navigation latérale, badges alimentés par les vraies données ──
  List<SSMNavSection> _sections() {
    final d = _donnees;
    int? badge(int valeur) => (!_chargement && valeur > 0) ? valeur : null;

    return [
      SSMNavSection(titre: 'Principal', items: [
        const SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(
          icone: Icons.people_outline,
          label: 'Élèves',
          route: '/directeur/eleves',
          badge: badge(d?.totalEleves ?? 0),
        ),
        SSMNavItem(
          icone: Icons.grade_outlined,
          label: 'Notes & évaluations',
          route: '/notes',
          badge: badge(d?.notesEnAttenteValidation ?? 0),
          couleurBadge: SSMPalette.teal,
        ),
        SSMNavItem(
          icone: Icons.price_change_outlined,
          label: 'Frais scolaires',
          route: '/directeur/frais',
          badge: badge(d?.debiteurs ?? 0),
        ),
        const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        const SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      SSMNavSection(titre: 'Pilotage', items: [
        const SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        SSMNavItem(
          icone: Icons.notifications_outlined,
          label: 'Notifications',
          route: '/notifications',
          badge: badge(d?.notificationsNonLues ?? 0),
        ),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
    ];
  }

  // ── a) Bandeau de bienvenue ──
  Widget _welcomeRow() {
    final d = _donnees;
    final prenom = _chargement ? '…' : (d?.prenomUtilisateur ?? 'Directeur');
    final parties = <String>[
      if ((d?.nomEcole ?? '').isNotEmpty) d!.nomEcole,
      _formaterDateComplete(DateTime.now()),
      if (!_chargement && d?.periode != null)
        '${d?.periode?['nom'] ?? 'Période'} ${d?.periodeEnCours == true ? 'en cours' : ''}'.trim(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour, $prenom 👋',
          style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        const SizedBox(height: 3),
        Text(
          parties.join('  ·  '),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
        ),
      ],
    );
  }

  // ── b) 4 cartes statistiques ──
  Widget _statsGrid() {
    final d = _donnees;

    final cartes = <Widget>[
      SSMStatCard(
        icone: Icons.people_outline,
        couleur: SSMPalette.indigo,
        valeur: _chargement ? '—' : '${d?.totalEleves ?? 0}',
        label: 'Élèves inscrits',
        sousTexte: _chargement ? null : '+${d?.nouveauxInscrits ?? 0} nouveaux cette année',
        tendance: SSMTendance.hausse,
      ),
      SSMStatCard(
        icone: Icons.payments_outlined,
        couleur: SSMPalette.teal,
        valeur: _chargement ? '—' : '${(d?.resumeFinancier?.tauxRecouvrement ?? 0).toStringAsFixed(0)}%',
        label: 'Frais collectés · période active',
        sousTexte: _chargement ? null : '${_formaterMontant(d?.resumeFinancier?.montantEncaisse ?? 0)} FCFA',
        tendance: SSMTendance.hausse,
      ),
      SSMStatCard(
        icone: Icons.school_outlined,
        couleur: SSMPalette.ambre,
        valeur: _chargement ? '—' : '${d?.classesActives ?? 0}',
        label: 'Classes actives',
        sousTexte: _chargement ? null : '${d?.classesCollege ?? 0} Collège · ${d?.classesLycee ?? 0} Lycée',
        tendance: SSMTendance.neutre,
      ),
      SSMStatCard(
        icone: Icons.warning_amber_rounded,
        couleur: SSMPalette.rouge,
        valeur: _chargement ? '—' : '${d?.debiteurs ?? 0}',
        label: 'Débiteurs · période active',
        sousTexte: _chargement ? null : '${_formaterMontant(d?.resumeFinancier?.montantRestant ?? 0)} FCFA restants',
        tendance: SSMTendance.baisse,
      ),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 760 ? 4 : (contraintes.maxWidth >= 520 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 128,
        ),
        itemBuilder: (context, i) => cartes[i],
      );
    });
  }

  // ── c) Colonne Alertes + Colonne Paiements récents ──
  Widget _deuxColonnes(BuildContext context) {
    return LayoutBuilder(builder: (context, contraintes) {
      final panneauAlertes = _panelAlertes(context);
      final panneauPaiements = _panelPaiements(context);

      if (contraintes.maxWidth < 760) {
        return Column(children: [panneauAlertes, const SizedBox(height: 12), panneauPaiements]);
      }

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 320, child: panneauAlertes),
            const SizedBox(width: 12),
            Expanded(child: panneauPaiements),
          ],
        ),
      );
    });
  }

  Widget _panelAlertes(BuildContext context) {
    final d = _donnees;
    final alertes = d?.alertes.take(6).toList() ?? const <Alerte>[];

    return SSMPanel(
      titre: 'Alertes importantes',
      lienAction: 'Voir tout →',
      onLienAction: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CentreDecisionScreen(
            anneeScolaireId: d?.annee?['id'] as int?,
            periodeId: d?.periode?['id'] as int?,
          ),
        ),
      ),
      child: _chargement
          ? const _EtatChargementPanel()
          : alertes.isEmpty
              ? const _EtatVide(
                  icone: Icons.check_circle_outline,
                  texte: 'Aucune alerte pour le moment',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < alertes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 7),
                      SSMAlertItem(
                        type: _typeAlerte(alertes[i].type),
                        icone: _iconeAlerte(alertes[i].type),
                        titre: alertes[i].titre,
                        sousTitre: alertes[i].description,
                      ),
                    ],
                  ],
                ),
    );
  }

  SSMAlerteType _typeAlerte(String type) {
    switch (type) {
      case 'danger':
        return SSMAlerteType.danger;
      case 'warning':
        return SSMAlerteType.avertissement;
      default:
        return SSMAlerteType.succes;
    }
  }

  IconData _iconeAlerte(String type) {
    switch (type) {
      case 'danger':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Widget _panelPaiements(BuildContext context) {
    final d = _donnees;
    final paiements = d?.derniersPaiements ?? const <Map<String, dynamic>>[];

    return SSMPanel(
      titre: 'Paiements récents',
      lienAction: 'Voir la caisse →',
      onLienAction: () => Navigator.pushNamed(context, '/paiements/caisse'),
      padding: EdgeInsets.zero,
      child: _chargement
          ? const _EtatChargementPanel()
          : paiements.isEmpty
              ? const _EtatVide(icone: Icons.receipt_long_outlined, texte: 'Aucun paiement récent')
              : SSMDataTable(
                  colonnes: const [
                    SSMDataColumn('Élève'),
                    SSMDataColumn('Classe'),
                    SSMDataColumn('Montant'),
                    SSMDataColumn('Type'),
                    SSMDataColumn('Date'),
                    SSMDataColumn('Statut'),
                  ],
                  lignes: [for (final p in paiements) _ligneDePaiement(p)],
                ),
    );
  }

  List<Widget> _ligneDePaiement(Map<String, dynamic> p) {
    final eleve = p['eleve'] is Map ? p['eleve'] as Map : const {};
    final classe = eleve['classe'] is Map ? eleve['classe'] as Map : const {};
    final frais = p['frais_scolaire'] is Map ? p['frais_scolaire'] as Map : const {};
    final nomEleve = (eleve['nom'] != null && eleve['prenom'] != null)
        ? '${eleve['nom']} ${eleve['prenom']}'
        : 'Élève inconnu';
    final estAnnule = p['statut'] == 'annule';
    final montant = double.tryParse(p['montant']?.toString() ?? '') ?? 0;

    return [
      Text(nomEleve, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
      Text('${classe['nom'] ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text('${_formaterMontant(montant)} FCFA', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text('${frais['nom'] ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text(_formaterDateCourte(p['date_paiement']?.toString()), style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      estAnnule ? const SSMPill.retard(label: 'Annulé') : const SSMPill.paye(label: 'Payé'),
    ];
  }

  // ── d) Actions rapides ──
  Widget _actionsRapides(BuildContext context) {
    final d = _donnees;
    final debiteurs = d?.debiteurs ?? 0;
    final caisseOuverte = d?.caisseOuverte ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions rapides',
            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMQuickActionButton(
                icone: Icons.person_add_alt_1,
                label: 'Inscrire un élève',
                variante: SSMActionVariante.primaire,
                onTap: () => Navigator.pushNamed(context, '/directeur/eleves'),
              ),
              SSMQuickActionButton(
                icone: Icons.receipt_long,
                label: 'Enregistrer un paiement',
                variante: SSMActionVariante.teal,
                onTap: () => Navigator.pushNamed(context, '/paiements'),
              ),
              SSMQuickActionButton(
                icone: Icons.description_outlined,
                label: 'Générer les bulletins',
                variante: SSMActionVariante.ambre,
                onTap: () => Navigator.pushNamed(context, '/bulletins'),
              ),
              SSMQuickActionButton(
                icone: Icons.chat_bubble_outline,
                label: 'Rappels WhatsApp ($debiteurs)',
                variante: SSMActionVariante.gris,
                onTap: () => Navigator.pushNamed(context, '/directeur/eleves-non-regle'),
              ),
              SSMQuickActionButton(
                icone: Icons.bar_chart_outlined,
                label: 'Rapport du mois',
                variante: SSMActionVariante.gris,
                onTap: () => Navigator.pushNamed(context, '/paiements/rapports'),
              ),
              SSMQuickActionButton(
                icone: caisseOuverte ? Icons.lock_outline : Icons.lock_open_outlined,
                label: caisseOuverte ? 'Fermer la caisse' : 'Ouvrir la caisse',
                variante: SSMActionVariante.gris,
                onTap: () => Navigator.pushNamed(context, '/paiements/caisse'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Petits états d'affichage internes à cet écran
// ══════════════════════════════════════════════════════════
class _EtatChargementPanel extends StatelessWidget {
  const _EtatChargementPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo),
        ),
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _EtatVide({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Column(
          children: [
            Icon(icone, size: 22, color: SSMPalette.texte3),
            const SizedBox(height: 6),
            Text(texte, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
          ],
        ),
      ),
    );
  }
}

// ── Formatage (pas de dépendance intl dans ce projet) ──

String _formaterMontant(num montant) {
  final entier = montant.round();
  final chiffres = entier.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(chiffres[i]);
  }
  return (entier < 0 ? '-' : '') + buffer.toString();
}

const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _formaterDateComplete(DateTime date) {
  final jour = _jours[date.weekday - 1];
  final moisNom = _mois[date.month - 1];
  final jourCapitalise = jour[0].toUpperCase() + jour.substring(1);
  return '$jourCapitalise ${date.day} $moisNom ${date.year}';
}

String _formaterDateCourte(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return '${date.day.toString().padLeft(2, '0')} ${_mois[date.month - 1].substring(0, 3)}, ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
}
