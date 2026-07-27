import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _grisFonce = Color(0xFF475569);
const Color _bleuInfo = Color(0xFF0284C7);

const List<String> _moisLongs = [
  '',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const List<String> _suggestionsPeriodes = [
  '1er Trimestre',
  '2ème Trimestre',
  '3ème Trimestre',
  'Semestre 1',
  'Semestre 2',
];

String _formatDateLongue(DateTime d) =>
    '${d.day} ${_moisLongs[d.month]} ${d.year}';

String _formatDateApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDateCourt(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

Color _couleurStatutAnnee(String statut) {
  switch (statut) {
    case 'active':
      return _vert;
    case 'cloturee':
      return _ambre;
    case 'archivee':
      return _grisFonce;
    default:
      return _gris;
  }
}

String _labelStatutAnnee(String statut) {
  switch (statut) {
    case 'active':
      return '● Active';
    case 'cloturee':
      return 'Clôturée';
    case 'archivee':
      return 'Archivée';
    default:
      return 'En préparation';
  }
}

Color _couleurStatutPeriode(String statut) {
  switch (statut) {
    case 'ouvert':
      return _vert;
    case 'ferme':
      return _rouge;
    case 'archive':
      return _grisFonce;
    default:
      return _gris;
  }
}

class GestionAnneesScreen extends StatefulWidget {
  const GestionAnneesScreen({super.key});

  @override
  State<GestionAnneesScreen> createState() => _GestionAnneesScreenState();
}

class _GestionAnneesScreenState extends State<GestionAnneesScreen>
    with TickerProviderStateMixin {
  List<dynamic> _annees = [];
  Map<String, dynamic>? _anneeActiveData;
  List<dynamic> _alertes = [];
  List<dynamic> _historique = [];
  bool _chargement = true;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _chargerTout();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final resultats = await Future.wait([
        AnneeService.listerAnnees(),
        AnneeService.anneeActive(),
        AnneeService.alertesPeriodes(),
        AnneeService.historique(),
      ]);
      setState(() {
        _annees = resultats[0] as List<dynamic>;
        _anneeActiveData = resultats[1] as Map<String, dynamic>;
        _alertes =
            (resultats[2] as Map<String, dynamic>)['alertes'] as List? ?? [];
        _historique = resultats[3] as List<dynamic>;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _rouge));
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _vert));
  }

  void _bientot() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fonctionnalité à venir')));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _afficherDialogCreerAnnee,
          backgroundColor: _indigo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Nouvelle année',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _enTete(),
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: _indigo,
                  unselectedLabelColor: _gris,
                  indicatorColor: _indigo,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Années scolaires'),
                    Tab(text: 'Alertes & Historique'),
                  ],
                ),
              ),
              Expanded(
                child: _chargement
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [_ongletAnnees(), _ongletAlertesHistorique()],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE + BANNIÈRE ANNÉE ACTIVE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    final annee = _anneeActiveData?['annee'] as Map<String, dynamic>?;
    final periodeActive =
        _anneeActiveData?['periode_active'] as Map<String, dynamic>?;
    final joursRestants = _anneeActiveData?['jours_restants_periode'] as int?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Années & Périodes',
            style: GoogleFonts.sora(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Organisation de la vie scolaire',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (annee != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Opacity(
                            opacity: 0.6 + 0.4 * _pulseController.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _vert,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'ANNÉE ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          annee['libelle'] as String,
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_formatDateCourt(annee['date_debut'] as String?)} → ${_formatDateCourt(annee['date_fin'] as String?)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (periodeActive != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _ambre,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            periodeActive['nom'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$joursRestants j',
                          style: GoogleFonts.sora(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'avant la fin',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _rouge,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Aucune période ouverte',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — ANNÉES SCOLAIRES
  // ══════════════════════════════════════════════════════

  Widget _ongletAnnees() {
    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: _annees.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 64,
                          color: _gris,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune année académique',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _annees.length,
              itemBuilder: (context, index) => _carteAnnee(_annees[index]),
            ),
    );
  }

  Widget _carteAnnee(dynamic annee) {
    final statut = annee['statut'] as String;
    final couleur = _couleurStatutAnnee(statut);
    final estActive = statut == 'active';
    final periodes = (annee['periodes'] as List?) ?? [];
    final periodeActive = periodes.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['statut'] == 'ouvert',
      orElse: () => null,
    );

    Widget carte = Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: couleur, width: 6)),
        boxShadow: [
          BoxShadow(
            color: (estActive ? _vert : Colors.black).withValues(
              alpha: estActive ? 0.18 : 0.05,
            ),
            blurRadius: estActive ? 20 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            annee['libelle'] as String,
                            style: GoogleFonts.sora(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${_formatDateCourt(annee['date_debut'] as String?)} → ${_formatDateCourt(annee['date_fin'] as String?)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SSMBadge(
                      label: _labelStatutAnnee(statut),
                      couleur: couleur,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF334155),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'stats':
                            _afficherDialogStatistiques(annee);
                            break;
                          case 'periodes':
                          case 'ouvrir_periode':
                            _afficherDialogGererPeriodes(annee);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'stats',
                          child: Text('Voir les statistiques'),
                        ),
                        if (estActive) ...const [
                          PopupMenuItem(
                            value: 'periodes',
                            child: Text('Gérer les périodes'),
                          ),
                          PopupMenuItem(
                            value: 'ouvrir_periode',
                            child: Text('Ouvrir une période'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      _statRapide(
                        Icons.people,
                        '${annee['nombre_eleves'] ?? 0} élèves',
                      ),
                      const SizedBox(width: 16),
                      _statRapide(
                        Icons.class_,
                        '${annee['nombre_classes'] ?? 0} classes',
                      ),
                      const SizedBox(width: 16),
                      _statRapide(
                        Icons.school,
                        '${annee['nombre_enseignants'] ?? 0} enseignants',
                      ),
                    ],
                  ),
                ),
                if (periodes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'PÉRIODES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _gris,
                      letterSpacing: 0.5,
                    ),
                  ),
                  ...periodes.map(
                    (p) => _lignePeriode(p as Map<String, dynamic>, annee),
                  ),
                ],
                const SizedBox(height: 12),
                _actionsAnnee(annee, statut, periodeActive),
              ],
            ),
          ),
        ),
      ),
    );

    return carte;
  }

  Widget _statRapide(IconData icone, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: _gris),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _lignePeriode(Map<String, dynamic> p, dynamic annee) {
    final statut = p['statut'] as String;
    final couleur = _couleurStatutPeriode(statut);
    final estOuverte = statut == 'ouvert';

    double? progression;
    if (estOuverte) {
      final debut = DateTime.tryParse(p['date_debut'] as String? ?? '');
      final fin = DateTime.tryParse(p['date_fin'] as String? ?? '');
      if (debut != null && fin != null && fin.isAfter(debut)) {
        final total = fin.difference(debut).inDays;
        final passes = DateTime.now().difference(debut).inDays;
        progression = (passes / total).clamp(0.0, 1.0);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                p['nom'] as String,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (p['code'] != null) ...[
                const SizedBox(width: 6),
                Text(
                  p['code'] as String,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _gris),
                ),
              ],
              const SizedBox(width: 8),
              SSMBadge(label: statut.toUpperCase(), couleur: couleur),
              const Spacer(),
              Text(
                '${_formatDateCourt(p['date_debut'] as String?)} → ${_formatDateCourt(p['date_fin'] as String?)}',
                style: GoogleFonts.inter(fontSize: 11, color: _gris),
              ),
            ],
          ),
          if (progression != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progression,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: (1 - progression) > 0.5 ? _vert : _ambre,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_anneeActiveData?['annee']?['id'] == annee['id'] ? (_anneeActiveData?['jours_restants_periode'] ?? '—') : '—'} j restants',
                  style: GoogleFonts.inter(fontSize: 11, color: _gris),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsAnnee(
    dynamic annee,
    String statut,
    Map<String, dynamic>? periodeActive,
  ) {
    final id = annee['id'] as int;
    final vide =
        (annee['nombre_eleves'] ?? 0) == 0 &&
        (annee['nombre_classes'] ?? 0) == 0;

    switch (statut) {
      case 'en_preparation':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _vert,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _afficherDialogConfirmerActivation(annee),
              child: const Text('Activer'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _indigo,
                side: const BorderSide(color: _indigo),
              ),
              onPressed: _bientot,
              child: const Text('Modifier'),
            ),
            if (vide)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: _rouge),
                onPressed: _bientot,
                child: const Text('Supprimer'),
              ),
          ],
        );
      case 'active':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _rouge,
                side: const BorderSide(color: _rouge),
              ),
              onPressed: () => _afficherDialogCloturer(annee),
              child: const Text("Clôturer l'année"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  _afficherDialogPasserEleves(annee, cloturerApres: false),
              child: const Text('Passer les élèves'),
            ),
          ],
        );
      case 'cloturee':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _gris),
              onPressed: () => _archiver(id),
              child: const Text('Archiver'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _indigo,
                side: const BorderSide(color: _indigo),
              ),
              onPressed: () => _afficherDialogStatistiques(annee),
              child: const Text('Voir les stats'),
            ),
          ],
        );
      case 'archivee':
        return TextButton(
          style: TextButton.styleFrom(foregroundColor: _indigo),
          onPressed: () => _afficherDialogStatistiques(annee),
          child: const Text('Consulter les archives'),
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> _archiver(int id) async {
    try {
      await AnneeService.archiverAnnee(id);
      _afficherSucces('Année archivée avec succès');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CRÉER UNE ANNÉE
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogCreerAnnee() async {
    final libelleController = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;
    double reglePassage = 10.0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvelle année scolaire',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: libelleController,
                                    decoration: InputDecoration(
                                      labelText: 'Libellé *',
                                      hintText: 'ex: 2026-2027',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onChanged: (_) => setStateDialog(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    final now = DateTime.now().year;
                                    libelleController.text = '$now-${now + 1}';
                                    setStateDialog(() {});
                                  },
                                  child: const Text('Générer'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.date_range,
                                color: _indigo,
                              ),
                              title: Text(
                                'Date de début *',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _gris,
                                ),
                              ),
                              subtitle: Text(
                                dateDebut == null
                                    ? 'Choisir une date'
                                    : _formatDateLongue(dateDebut!),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null)
                                  setStateDialog(() => dateDebut = d);
                              },
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.date_range,
                                color: _indigo,
                              ),
                              title: Text(
                                'Date de fin *',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _gris,
                                ),
                              ),
                              subtitle: Text(
                                dateFin == null
                                    ? 'Choisir une date'
                                    : _formatDateLongue(dateFin!),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: dateDebut ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null)
                                  setStateDialog(() => dateFin = d);
                              },
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Règle de passage',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              'Moyenne minimale pour passer :',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _gris,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: _vert,
                                      thumbColor: _vert,
                                    ),
                                    child: Slider(
                                      value: reglePassage,
                                      min: 0,
                                      max: 20,
                                      divisions: 40,
                                      onChanged: (v) => setStateDialog(
                                        () => reglePassage = v,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    '${reglePassage.toStringAsFixed(1)}/20',
                                    style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _vert,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed:
                                libelleController.text.trim().isEmpty ||
                                    dateDebut == null ||
                                    dateFin == null
                                ? null
                                : () async {
                                    try {
                                      await AnneeService.creerAnnee(
                                        libelle: libelleController.text.trim(),
                                        dateDebut: _formatDateApi(dateDebut!),
                                        dateFin: _formatDateApi(dateFin!),
                                      );
                                      if (context.mounted)
                                        Navigator.pop(context);
                                      _afficherSucces(
                                        'Année créée avec succès',
                                      );
                                      _chargerTout();
                                    } catch (e) {
                                      _afficherErreur(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  },
                            child: const Text("Créer l'année"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    libelleController.dispose();
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CONFIRMATION ACTIVATION
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogConfirmerActivation(dynamic annee) async {
    final autreActive = _annees.firstWhere(
      (a) => a['statut'] == 'active' && a['id'] != annee['id'],
      orElse: () => null,
    );

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch, color: _indigo, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Activer ${annee['libelle']} ?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cette année deviendra l\'année de référence pour toutes les données (notes, absences, paiements, bulletins).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                  ),
                ),
                if (autreActive != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '⚠️ L\'année ${autreActive['libelle']} est actuellement active. Elle sera mise en veille.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _ambre,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Activer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirme != true) return;

    try {
      await AnneeService.activerAnnee(annee['id'] as int);
      _afficherSucces('Année activée avec succès');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — VOIR LES STATISTIQUES
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogStatistiques(dynamic annee) async {
    Map<String, dynamic>? stats;
    String? erreur;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (stats == null && erreur == null) {
            AnneeService.statistiquesAnnee(annee['id'] as int)
                .then((data) {
                  setStateDialog(() => stats = data);
                })
                .catchError((e) {
                  setStateDialog(
                    () => erreur = e.toString().replaceAll('Exception: ', ''),
                  );
                });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistiques — ${annee['libelle']}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (erreur != null)
                      Text(erreur!, style: GoogleFonts.inter(color: _rouge))
                    else if (stats == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _statChip(
                            'Élèves',
                            '${stats!['nombre_eleves']}',
                            _indigo,
                          ),
                          _statChip('Garçons', '${stats!['garcons']}', _indigo),
                          _statChip('Filles', '${stats!['filles']}', _teal),
                          _statChip(
                            'Classes',
                            '${stats!['nombre_classes']}',
                            _indigo,
                          ),
                          _statChip(
                            'Enseignants',
                            '${stats!['nombre_enseignants']}',
                            _indigo,
                          ),
                          _statChip(
                            'Taux réussite',
                            '${stats!['taux_reussite']}%',
                            _vert,
                          ),
                          _statChip(
                            'Taux échec',
                            '${stats!['taux_echec']}%',
                            _rouge,
                          ),
                          _statChip(
                            'Absences',
                            '${stats!['absences_total']}',
                            _ambre,
                          ),
                          _statChip(
                            'Encaissé',
                            '${stats!['total_paiements']} FCFA',
                            _teal,
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valeur,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — GÉRER LES PÉRIODES
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogGererPeriodes(dynamic annee) async {
    List<dynamic> periodes = List<dynamic>.from(
      (annee['periodes'] as List?) ?? [],
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> recharger() async {
            try {
              final liste = await AnneeService.listerPeriodes(
                annee['id'] as int,
              );
              setStateDialog(() => periodes = liste);
            } catch (_) {}
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Périodes de ${annee['libelle']}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: periodes.isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'Aucune période',
                                      style: GoogleFonts.inter(color: _gris),
                                    ),
                                  ),
                                ]
                              : periodes.map((p) {
                                  final statut = p['statut'] as String;
                                  final couleur = _couleurStatutPeriode(statut);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: couleur,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${p['nom']}${p['code'] != null ? ' (${p['code']})' : ''}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${_formatDateCourt(p['date_debut'] as String?)} → ${_formatDateCourt(p['date_fin'] as String?)}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: _gris,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (statut == 'planifie')
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: _vert,
                                            ),
                                            onPressed: () async {
                                              try {
                                                await AnneeService.ouvrirPeriode(
                                                  p['id'] as int,
                                                );
                                                _afficherSucces(
                                                  'Période ouverte',
                                                );
                                                await recharger();
                                                _chargerTout();
                                              } catch (e) {
                                                _afficherErreur(
                                                  e.toString().replaceAll(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Ouvrir'),
                                          )
                                        else if (statut == 'ouvert')
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: _rouge,
                                            ),
                                            onPressed: () async {
                                              try {
                                                await AnneeService.fermerPeriode(
                                                  p['id'] as int,
                                                );
                                                _afficherSucces(
                                                  'Période fermée',
                                                );
                                                await recharger();
                                                _chargerTout();
                                              } catch (e) {
                                                _afficherErreur(
                                                  e.toString().replaceAll(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Fermer'),
                                          )
                                        else
                                          SSMBadge(
                                            label: statut == 'ferme'
                                                ? 'Fermée'
                                                : statut.toUpperCase(),
                                            couleur: _gris,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (periodes.length < 3)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _indigo,
                            side: const BorderSide(color: _indigo),
                          ),
                          onPressed: () async {
                            await _afficherDialogAjouterPeriode(annee);
                            await recharger();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter une période'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — AJOUTER UNE PÉRIODE
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogAjouterPeriode(dynamic annee) async {
    final nomController = TextEditingController();
    final codeController = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvelle période',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomController,
                      decoration: InputDecoration(
                        labelText: 'Nom *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestionsPeriodes.map((s) {
                        return GestureDetector(
                          onTap: () =>
                              setStateDialog(() => nomController.text = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _indigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _indigo,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Code',
                        hintText: 'T1, T2, S1...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: GoogleFonts.jetBrainsMono(fontSize: 14),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.date_range, color: _indigo),
                      title: Text(
                        dateDebut == null
                            ? 'Date de début *'
                            : _formatDateLongue(dateDebut!),
                      ),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setStateDialog(() => dateDebut = d);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.date_range, color: _indigo),
                      title: Text(
                        dateFin == null
                            ? 'Date de fin *'
                            : _formatDateLongue(dateFin!),
                      ),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: dateDebut ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setStateDialog(() => dateFin = d);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                nomController.text.trim().isEmpty ||
                                    dateDebut == null ||
                                    dateFin == null
                                ? null
                                : () async {
                                    try {
                                      await AnneeService.creerPeriode(
                                        anneeAcademiqueId: annee['id'] as int,
                                        nom: nomController.text.trim(),
                                        code: codeController.text.trim().isEmpty
                                            ? null
                                            : codeController.text.trim(),
                                        dateDebut: _formatDateApi(dateDebut!),
                                        dateFin: _formatDateApi(dateFin!),
                                      );
                                      if (context.mounted)
                                        Navigator.pop(context);
                                      _afficherSucces(
                                        'Période créée avec succès',
                                      );
                                      _chargerTout();
                                    } catch (e) {
                                      _afficherErreur(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Créer la période'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nomController.dispose();
    codeController.dispose();
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — PASSER LES ÉLÈVES (autonome)
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogPasserEleves(
    dynamic annee, {
    required bool cloturerApres,
  }) async {
    Map<String, dynamic>? apercu;
    String? erreur;
    bool passerAutomatique = true;
    final redoublants = <int>{};
    final diplomes = <int>{};
    bool initialise = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (apercu == null && erreur == null) {
            AnneeService.apercuPassage(annee['id'] as int)
                .then((data) {
                  setStateDialog(() {
                    apercu = data;
                    if (!initialise) {
                      final eleves = (data['eleves'] as List?) ?? [];
                      for (final e in eleves) {
                        final id = e['eleve_id'] as int;
                        if (e['verdict'] == 'redoublant' ||
                            e['verdict'] == 'sans_note')
                          redoublants.add(id);
                        if (e['est_terminale'] == true) diplomes.add(id);
                      }
                      initialise = true;
                    }
                  });
                })
                .catchError((e) {
                  setStateDialog(
                    () => erreur = e.toString().replaceAll('Exception: ', ''),
                  );
                });
          }

          final eleves = (apercu?['eleves'] as List?) ?? [];
          final total = eleves.length;
          final passeront = total - redoublants.length - diplomes.length;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Passage des élèves — ${annee['libelle']}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (erreur != null)
                      Text(erreur!, style: GoogleFonts.inter(color: _rouge))
                    else if (apercu == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Les élèves avec moyenne ≥ ${apercu!['regle_passage_moyenne']}/20 passeront automatiquement en classe supérieure',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: passerAutomatique,
                                    activeThumbColor: _teal,
                                    onChanged: (v) => setStateDialog(
                                      () => passerAutomatique = v,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _statChip('Passeront', '$passeront', _vert),
                                  _statChip(
                                    'Redoublent',
                                    '${redoublants.length}',
                                    _ambre,
                                  ),
                                  _statChip(
                                    'Diplômés',
                                    '${diplomes.length}',
                                    _teal,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SSMSectionTitre(titre: 'Redoublants manuels'),
                              ...eleves
                                  .where((e) => !(e['est_terminale'] == true))
                                  .map((e) {
                                    final id = e['eleve_id'] as int;
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: redoublants.contains(id),
                                      activeColor: _ambre,
                                      title: Text(
                                        '${e['nom']} ${e['prenom']} — ${e['classe_nom']}',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        e['moyenne'] != null
                                            ? 'Moyenne : ${e['moyenne']}/20'
                                            : 'Aucune note',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: _gris,
                                        ),
                                      ),
                                      onChanged: (v) => setStateDialog(() {
                                        if (v == true) {
                                          redoublants.add(id);
                                        } else {
                                          redoublants.remove(id);
                                        }
                                      }),
                                    );
                                  }),
                              const SizedBox(height: 12),
                              SSMSectionTitre(titre: 'Diplômés (Terminale)'),
                              ...eleves
                                  .where((e) => e['est_terminale'] == true)
                                  .map((e) {
                                    final id = e['eleve_id'] as int;
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: diplomes.contains(id),
                                      activeColor: _teal,
                                      title: Text(
                                        '${e['nom']} ${e['prenom']} — ${e['classe_nom']}',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                      onChanged: (v) => setStateDialog(() {
                                        if (v == true) {
                                          diplomes.add(id);
                                          redoublants.remove(id);
                                        } else {
                                          diplomes.remove(id);
                                        }
                                      }),
                                    );
                                  }),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      cloturerApres
                          ? "Cette action clôturera aussi l'année. Elle est irréversible."
                          : 'Cette action est irréversible.',
                      style: GoogleFonts.inter(fontSize: 11, color: _rouge),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cloturerApres ? _rouge : _teal,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: apercu == null
                                ? null
                                : () async {
                                    try {
                                      await AnneeService.passerEleves(
                                        annee['id'] as int,
                                        passerAutomatique: passerAutomatique,
                                        redoublants: redoublants.toList(),
                                        diplomes: diplomes.toList(),
                                      );
                                      if (cloturerApres) {
                                        await AnneeService.cloturerAnnee(
                                          annee['id'] as int,
                                        );
                                      }
                                      if (context.mounted)
                                        Navigator.pop(context);
                                      _afficherSucces(
                                        cloturerApres
                                            ? 'Année clôturée avec succès'
                                            : 'Passage effectué avec succès',
                                      );
                                      _chargerTout();
                                    } catch (e) {
                                      _afficherErreur(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  },
                            child: Text(
                              cloturerApres
                                  ? "Clôturer l'année"
                                  : 'Confirmer le passage',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CLÔTURER L'ANNÉE (stepper 3 étapes)
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogCloturer(dynamic annee) async {
    int etape = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(3, (i) {
                        final actif = i <= etape;
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                            height: 4,
                            decoration: BoxDecoration(
                              color: actif ? _indigo : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.checklist, color: _indigo, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Avant de clôturer, vérifiez :',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _lignePreCloture('Toutes les notes sont validées'),
                    _lignePreCloture('Tous les bulletins sont générés'),
                    _lignePreCloture('Tous les paiements sont enregistrés'),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _afficherDialogPasserEleves(
                                annee,
                                cloturerApres: true,
                              );
                            },
                            child: const Text('Continuer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _lignePreCloture(String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: _vert),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — ALERTES & HISTORIQUE
  // ══════════════════════════════════════════════════════

  Widget _ongletAlertesHistorique() {
    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          SSMSectionTitre(titre: '⚠️ Alertes actives'),
          if (_alertes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: _vert, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Tout est en ordre ✓',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _vert,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._alertes.map((a) => _carteAlerte(a as Map<String, dynamic>)),
          const SizedBox(height: 24),
          SSMSectionTitre(titre: 'Historique des actions'),
          if (_historique.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Aucune action enregistrée',
                style: GoogleFonts.inter(color: _gris),
              ),
            )
          else
            ..._historique.map(
              (h) => _ligneHistorique(h as Map<String, dynamic>),
            ),
        ],
      ),
    );
  }

  Widget _carteAlerte(Map<String, dynamic> alerte) {
    final type = alerte['type'] as String? ?? '';
    Color couleur;
    IconData icone;
    switch (type) {
      case 'aucune_periode_active':
        couleur = _rouge;
        icone = Icons.error_outline;
        break;
      case 'fin_periode_proche':
        couleur = _ambre;
        icone = Icons.timer_outlined;
        break;
      case 'enseignants_en_retard':
        couleur = _ambre;
        icone = Icons.person_off_outlined;
        break;
      default:
        couleur = _bleuInfo;
        icone = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alerte['message'] as String? ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneHistorique(Map<String, dynamic> h) {
    final action = h['action'] as String? ?? '';
    IconData icone;
    Color couleur;
    switch (action) {
      case 'creation':
        icone = Icons.add_circle;
        couleur = _indigo;
        break;
      case 'activation':
        icone = Icons.rocket_launch;
        couleur = _vert;
        break;
      case 'cloture':
        icone = Icons.lock;
        couleur = _rouge;
        break;
      case 'archivage':
        icone = Icons.archive;
        couleur = _gris;
        break;
      case 'passage_eleves':
        icone = Icons.compare_arrows;
        couleur = _teal;
        break;
      default:
        icone = Icons.history;
        couleur = _gris;
    }

    final createdAt = DateTime.tryParse(h['created_at'] as String? ?? '');
    final dateHeure = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : null;

    return SSMListeTile(
      icone: icone,
      couleurIcone: couleur,
      titre: '$action — ${h['annee_libelle'] ?? ''}',
      sousTitre: 'Par ${h['utilisateur_nom'] ?? '—'}',
      dateHeure: dateHeure,
    );
  }
}
