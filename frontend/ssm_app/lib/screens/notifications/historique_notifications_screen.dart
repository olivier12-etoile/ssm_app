import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'detail_notification_screen.dart';

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _formatDateCourt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ══════════════════════════════════════════════════════════
// Historique complet et détaillé des notifications, avec filtres
// avancés, tri, recherche par titre, export CSV et scroll infini.
// ══════════════════════════════════════════════════════════
class HistoriqueNotificationsScreen extends StatefulWidget {
  const HistoriqueNotificationsScreen({super.key});

  @override
  State<HistoriqueNotificationsScreen> createState() => _HistoriqueNotificationsScreenState();
}

class _HistoriqueNotificationsScreenState extends State<HistoriqueNotificationsScreen> {
  final List<NotificationSSM> _items = [];
  int _pageActuelle = 1;
  int _dernierePage = 1;
  bool _chargementInitial = true;
  bool _chargementPage = false;
  bool _exportEnCours = false;
  String? _erreur;

  DateTime? _dateDebut;
  DateTime? _dateFin;
  String? _statut;
  String? _canal;
  String? _categorie;
  String _tri = 'recent';
  final _rechercheController = TextEditingController();
  Timer? _debounceRecherche;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _charger();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _rechercheController.dispose();
    _debounceRecherche?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _chargerPageSuivante();
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargementInitial = true;
      _erreur = null;
      _items.clear();
      _pageActuelle = 1;
    });
    try {
      final resultat = await NotificationService.getHistorique(
        statut: _statut,
        canal: _canal,
        categorie: _categorie,
        recherche: _rechercheController.text.trim(),
        dateDebut: _dateDebut != null ? _formatDateCourt(_dateDebut!) : null,
        dateFin: _dateFin != null ? _formatDateCourt(_dateFin!) : null,
        tri: _tri,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(resultat['items'] as List<NotificationSSM>);
        _pageActuelle = resultat['page_actuelle'] as int;
        _dernierePage = resultat['derniere_page'] as int;
        _chargementInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementInitial = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerPageSuivante() async {
    if (_chargementPage || _pageActuelle >= _dernierePage) return;
    setState(() => _chargementPage = true);
    try {
      final resultat = await NotificationService.getHistorique(
        statut: _statut,
        canal: _canal,
        categorie: _categorie,
        recherche: _rechercheController.text.trim(),
        dateDebut: _dateDebut != null ? _formatDateCourt(_dateDebut!) : null,
        dateFin: _dateFin != null ? _formatDateCourt(_dateFin!) : null,
        tri: _tri,
        page: _pageActuelle + 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(resultat['items'] as List<NotificationSSM>);
        _pageActuelle = resultat['page_actuelle'] as int;
        _dernierePage = resultat['derniere_page'] as int;
        _chargementPage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargementPage = false);
    }
  }

  void _onRechercheChangee(String texte) {
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 500), _charger);
  }

  Future<void> _choisirPlageDates() async {
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateDebut != null && _dateFin != null
          ? DateTimeRange(start: _dateDebut!, end: _dateFin!)
          : null,
    );
    if (plage == null) return;
    setState(() {
      _dateDebut = plage.start;
      _dateFin = plage.end;
    });
    _charger();
  }

  void _effacerDates() {
    setState(() {
      _dateDebut = null;
      _dateFin = null;
    });
    _charger();
  }

  Future<void> _exporter() async {
    setState(() => _exportEnCours = true);
    try {
      final chemin = await NotificationService.telechargerExportExcel(
        statut: _statut,
        canal: _canal,
        categorie: _categorie,
        recherche: _rechercheController.text.trim(),
        dateDebut: _dateDebut != null ? _formatDateCourt(_dateDebut!) : null,
        dateFin: _dateFin != null ? _formatDateCourt(_dateFin!) : null,
        tri: _tri,
      );
      if (!mounted) return;
      setState(() => _exportEnCours = false);
      await OpenFile.open(chemin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  Future<void> _ouvrirDetail(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailNotificationScreen(notificationId: id)));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Historique des notifications',
              onRetour: () => Navigator.pop(context),
              actions: [
                IconButton(
                  icon: _exportEnCours
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo))
                      : const Icon(Icons.file_download_outlined, color: SSMPalette.texte2),
                  tooltip: 'Exporter Excel',
                  onPressed: _exportEnCours ? null : _exporter,
                ),
              ],
            ),
            _panneauFiltres(),
            Expanded(child: _corpsListe()),
          ],
        ),
      ),
    );
  }

  Widget _panneauFiltres() {
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: Column(
        children: [
          _rechercheTopbar(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dropdownFiltre(
                  valeur: _statut,
                  hint: 'Statut',
                  options: {for (final s in StatutNotification.values) s.valeurApi: s.libelle},
                  onChanged: (v) {
                    setState(() => _statut = v);
                    _charger();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdownFiltre(
                  valeur: _canal,
                  hint: 'Canal',
                  options: {for (final c in CanalNotification.values) c.valeurApi: c.libelle},
                  onChanged: (v) {
                    setState(() => _canal = v);
                    _charger();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdownFiltre(
                  valeur: _categorie,
                  hint: 'Catégorie',
                  options: {for (final c in CategorieNotification.values) c.valeurApi: c.libelle},
                  onChanged: (v) {
                    setState(() => _categorie = v);
                    _charger();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _choisirPlageDates,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _dateDebut != null && _dateFin != null
                        ? '${_formatDateCourt(_dateDebut!)} → ${_formatDateCourt(_dateFin!)}'
                        : 'Plage de dates',
                    style: GoogleFonts.inter(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_dateDebut != null)
                IconButton(icon: const Icon(Icons.close, size: 18, color: SSMPalette.texte3), onPressed: _effacerDates),
              const SizedBox(width: 4),
              _segmentTri(),
            ],
          ),
        ],
      ),
    );
  }

  // Recherche restylée à l'identique de la barre de recherche de SSMTopbar
  // (fond gris clair F9FAFB, bordure E5E7EB, icône loupe).
  Widget _rechercheTopbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: SSMPalette.texte3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _rechercheController,
              onChanged: _onRechercheChangee,
              style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Rechercher par titre',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentTri() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(SSMRayons.moyen), border: Border.all(color: SSMPalette.bordure)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _boutonTri('recent', Icons.schedule, 'Récent'),
          _boutonTri('destinataires', Icons.groups_outlined, 'Destinataires'),
        ],
      ),
    );
  }

  Widget _boutonTri(String valeur, IconData icone, String tooltip) {
    final actif = _tri == valeur;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() => _tri = valeur);
          _charger();
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: actif ? SSMPalette.indigo : Colors.transparent, borderRadius: BorderRadius.circular(SSMRayons.petit)),
          child: Icon(icone, size: 16, color: actif ? Colors.white : SSMPalette.texte3),
        ),
      ),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(SSMRayons.moyen), border: Border.all(color: SSMPalette.bordure)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: valeur,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('Tout ($hint)')),
            ...options.entries.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _corpsListe() {
    if (_chargementInitial) {
      return const Center(child: CircularProgressIndicator(color: SSMPalette.indigo));
    }
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
              const SizedBox(height: 12),
              Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 40, color: SSMPalette.texte3),
            const SizedBox(height: 12),
            Text('Aucune notification ne correspond à ces filtres.', style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      color: SSMPalette.indigo,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _table(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _chargementPage
                    ? const CircularProgressIndicator(color: SSMPalette.indigo)
                    : _pageActuelle >= _dernierePage
                        ? Text('${_items.length} notification(s) au total', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3))
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    return Container(
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SSMDataTable(
        colonnes: const [
          SSMDataColumn('Titre'),
          SSMDataColumn('Canal'),
          SSMDataColumn('Cible'),
          SSMDataColumn('Destinataires'),
          SSMDataColumn('Date'),
          SSMDataColumn('Statut'),
        ],
        onLigneTap: (i) => _ouvrirDetail(_items[i].id!),
        lignes: [
          for (final n in _items)
            [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (n.urgent) ...[
                    const Icon(Icons.priority_high, size: 13, color: SSMPalette.rouge),
                    const SizedBox(width: 3),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      n.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(n.canal.icone, size: 13, color: n.canal.couleur),
                  const SizedBox(width: 5),
                  Text(n.canal.libelle, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                ],
              ),
              Text(n.typeCible.libelle, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
              Text('${n.nombreDestinataires}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.texte2)),
              Text(_formatDate(n.createdAt), style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte3)),
              SSMPill.couleur(label: n.statut.libelle, couleur: n.statut.couleur),
            ],
        ],
      ),
    );
  }
}
