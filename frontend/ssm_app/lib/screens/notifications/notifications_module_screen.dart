import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'detail_notification_screen.dart';
import 'historique_notifications_screen.dart';
import 'modeles_messages_screen.dart';
import 'nouvelle_notification_screen.dart';
import 'parametres_declencheurs_screen.dart';
import 'statistiques_notifications_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFF8FAFC);

bool _estAujourdhui(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Notifications.
// ══════════════════════════════════════════════════════════
class NotificationsModuleScreen extends StatefulWidget {
  const NotificationsModuleScreen({super.key});

  @override
  State<NotificationsModuleScreen> createState() => _NotificationsModuleScreenState();
}

class _NotificationsModuleScreenState extends State<NotificationsModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargementUtilisateur = true;
  List<NotificationSSM> _notifications = [];
  bool _chargementListe = true;
  String? _erreur;

  String? _filtreStatut;
  String? _filtreCanal;
  String? _filtreCategorie;

  bool get _peutCreer => !(_utilisateur?.estEnseignant ?? true);
  bool get _estDirecteur => (_utilisateur?.estDirecteur ?? false) || (_utilisateur?.estSuperAdmin ?? false);

  int get _totalEnvoyes => _notifications.fold(0, (s, n) => s + n.nombreEnvoyes);
  int get _totalEnvoyesAujourdhui => _notifications
      .where((n) => n.createdAt != null && _estAujourdhui(n.createdAt!))
      .fold(0, (s, n) => s + n.nombreEnvoyes);
  int get _enAttenteCount => _notifications.where((n) => n.estEnAttente).length;
  int get _echoueesCount => _notifications.where((n) => n.estEnEchec).length;
  int get _delivreesCount => _notifications.where((n) => n.statut == StatutNotification.envoyee).length;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (!mounted) return;
    setState(() {
      _utilisateur = utilisateur;
      _chargementUtilisateur = false;
    });
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargementListe = true;
      _erreur = null;
    });
    try {
      final notifications = await NotificationService.getNotifications(
        statut: _filtreStatut,
        canal: _filtreCanal,
        categorie: _filtreCategorie,
      );
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _chargementListe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementListe = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String get _routeDashboardPrincipal {
    switch (_utilisateur?.role) {
      case 'enseignant':
        return '/dashboard/enseignant';
      case 'censeur':
        return '/dashboard/censeur';
      case 'secretaire':
        return '/dashboard/secretaire';
      default:
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

  Future<void> _ouvrirNouvelleNotification() async {
    final cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen()),
    );
    if (cree == true) _charger();
  }

  Future<void> _ouvrirDetail(int id) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailNotificationScreen(notificationId: id)),
    );
    if (modifie == true) _charger();
  }

  Future<void> _ouvrirModeles() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelesMessagesScreen()));
  }

  Future<void> _ouvrirParametresDeclencheurs() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ParametresDeclencheursScreen()));
  }

  Future<void> _ouvrirHistorique() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueNotificationsScreen()));
    _charger();
  }

  Future<void> _ouvrirStatistiques() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StatistiquesNotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _retour),
        title: Text('Notifications', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargementUtilisateur
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _cartesResume(),
                  const SizedBox(height: 20),
                  _boutonsNavigation(),
                  const SizedBox(height: 20),
                  _filtres(),
                  const SizedBox(height: 16),
                  SSMSectionTitre(titre: 'Notifications récentes'),
                  _corpsListe(),
                ],
              ),
            ),
      floatingActionButton: _peutCreer
          ? FloatingActionButton.extended(
              onPressed: _ouvrirNouvelleNotification,
              backgroundColor: _indigo,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Nouvelle notification', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  // ── Cartes résumé ──
  Widget _cartesResume() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        SSMStatCard(
          titre: "Total envoyées${_totalEnvoyesAujourdhui > 0 ? ' ($_totalEnvoyesAujourdhui aujourd\'hui)' : ''}",
          valeur: '$_totalEnvoyes',
          icone: Icons.send_outlined,
          couleurIcone: _indigo,
        ),
        SSMStatCard(
          titre: 'En attente',
          valeur: '$_enAttenteCount',
          icone: Icons.hourglass_empty,
          couleurIcone: _ambre,
        ),
        SSMStatCard(
          titre: 'Échouées',
          valeur: '$_echoueesCount',
          icone: Icons.error_outline,
          couleurIcone: _rouge,
        ),
        SSMStatCard(
          titre: 'Délivrées',
          valeur: '$_delivreesCount',
          icone: Icons.check_circle_outline,
          couleurIcone: _vert,
        ),
      ],
    );
  }

  Widget _boutonsNavigation() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _ouvrirModeles,
                icon: const Icon(Icons.article_outlined),
                label: const Text('Modèles de messages'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _ouvrirHistorique,
                icon: const Icon(Icons.history),
                label: const Text('Historique complet'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _ouvrirStatistiques,
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text('Statistiques'),
              ),
            ),
            if (_estDirecteur) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ouvrirParametresDeclencheurs,
                  icon: const Icon(Icons.tune),
                  label: const Text('Déclencheurs'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── Filtres ──
  Widget _filtres() {
    return Row(
      children: [
        Expanded(
          child: _dropdownFiltre(
            valeur: _filtreStatut,
            hint: 'Statut',
            options: {for (final s in StatutNotification.values) s.valeurApi: s.libelle},
            onChanged: (v) {
              setState(() => _filtreStatut = v);
              _charger();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdownFiltre(
            valeur: _filtreCanal,
            hint: 'Canal',
            options: {for (final c in CanalNotification.values) c.valeurApi: c.libelle},
            onChanged: (v) {
              setState(() => _filtreCanal = v);
              _charger();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdownFiltre(
            valeur: _filtreCategorie,
            hint: 'Catégorie',
            options: {for (final c in CategorieNotification.values) c.valeurApi: c.libelle},
            onChanged: (v) {
              setState(() => _filtreCategorie = v);
              _charger();
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownFiltre({
    required String? valeur,
    required String hint,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gris.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: valeur,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 12, color: _gris)),
          style: GoogleFonts.inter(fontSize: 12, color: _texteFonce),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('Tout ($hint)')),
            ...options.entries.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Liste ──
  Widget _corpsListe() {
    if (_chargementListe) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _indigo)),
      );
    }
    if (_erreur != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge))),
      );
    }
    if (_notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.notifications_none, size: 48, color: _gris),
              const SizedBox(height: 12),
              Text('Aucune notification pour ces filtres.', style: GoogleFonts.inter(color: _gris)),
            ],
          ),
        ),
      );
    }
    return Column(children: _notifications.map(_carteNotification).toList());
  }

  Widget _carteNotification(NotificationSSM n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _ouvrirDetail(n.id!),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: n.canal.couleur.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(n.canal.icone, color: n.canal.couleur, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (n.urgent) ...[
                            const Icon(Icons.priority_high, color: _rouge, size: 14),
                            const SizedBox(width: 2),
                          ],
                          Expanded(
                            child: Text(
                              n.titre,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${n.typeCible.libelle} · ${_formatDate(n.createdAt)}',
                        style: GoogleFonts.inter(fontSize: 11, color: _gris),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SSMBadge(label: n.statut.libelle, couleur: n.statut.couleur),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
