import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'detail_notification_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _gris = Color(0xFF94A3B8);
const Color _rouge = Color(0xFFDC2626);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFF8FAFC);

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
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
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
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Historique des notifications', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: _exportEnCours
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_outlined),
            tooltip: 'Exporter Excel',
            onPressed: _exportEnCours ? null : _exporter,
          ),
        ],
      ),
      body: Column(
        children: [
          _panneauFiltres(),
          Expanded(child: _corpsListe()),
        ],
      ),
    );
  }

  Widget _panneauFiltres() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _rechercheController,
            onChanged: _onRechercheChangee,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Rechercher par titre',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
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
                IconButton(icon: const Icon(Icons.close, size: 18, color: _gris), onPressed: _effacerDates),
              const SizedBox(width: 4),
              _segmentTri(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmentTri() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _gris.withValues(alpha: 0.4))),
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
          decoration: BoxDecoration(color: actif ? _indigo : Colors.transparent, borderRadius: BorderRadius.circular(6)),
          child: Icon(icone, size: 16, color: actif ? Colors.white : _gris),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _gris.withValues(alpha: 0.4))),
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

  Widget _corpsListe() {
    if (_chargementInitial) {
      return const Center(child: CircularProgressIndicator(color: _indigo));
    }
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _rouge, size: 40),
              const SizedBox(height: 12),
              Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
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
            const Icon(Icons.inbox_outlined, size: 48, color: _gris),
            const SizedBox(height: 12),
            Text('Aucune notification ne correspond à ces filtres.', style: GoogleFonts.inter(color: _gris)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _chargementPage
                    ? const CircularProgressIndicator(color: _indigo)
                    : _pageActuelle >= _dernierePage
                        ? Text('${_items.length} notification(s) au total', style: GoogleFonts.inter(fontSize: 12, color: _gris))
                        : const SizedBox.shrink(),
              ),
            );
          }
          return _carteNotification(_items[i]);
        },
      ),
    );
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (n.urgent) ...[const Icon(Icons.priority_high, color: _rouge, size: 14), const SizedBox(width: 2)],
                    Expanded(
                      child: Text(
                        n.titre,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SSMBadge(label: n.statut.libelle, couleur: n.statut.couleur),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _infoLigne(n.canal.icone, n.canal.libelle),
                    _infoLigne(n.typeCible.icone, n.typeCible.libelle),
                    _infoLigne(Icons.groups_outlined, '${n.nombreDestinataires} destinataire(s)'),
                    _infoLigne(Icons.schedule, _formatDate(n.createdAt)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoLigne(IconData icone, String texte) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: _gris),
        const SizedBox(width: 4),
        Text(texte, style: GoogleFonts.inter(fontSize: 11, color: _gris)),
      ],
    );
  }
}
