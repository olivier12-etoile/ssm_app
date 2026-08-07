import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/annee_service.dart';
import '../../services/dashboard_frais_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _orange = Color(0xFFEA580C);
const Color _gris = Color(0xFF94A3B8);
const Color _grisFonce = Color(0xFF475569);

Color _couleurStatutPeriode(String statut) {
  switch (statut) {
    case 'ouverte':
      return _vert;
    case 'en_veille':
      return _orange;
    case 'en_validation':
      return _orange;
    case 'cloturee':
      return _rouge;
    case 'archivee':
      return _grisFonce;
    default:
      return _gris;
  }
}

Color _couleurStatutEleve(String? statut) {
  switch (statut) {
    case 'admis':
      return _vert;
    case 'redoublant':
      return _orange;
    case 'diplome':
      return _indigo;
    default:
      return _gris;
  }
}

Color _couleurMoyenne(double? m) {
  if (m == null) return _gris;
  if (m >= 14) return _vert;
  if (m >= 10) return _teal;
  return _rouge;
}

class FicheAnneeScreen extends StatefulWidget {
  final int anneeId;
  final String libelle;
  final String statut;

  const FicheAnneeScreen({
    super.key,
    required this.anneeId,
    required this.libelle,
    required this.statut,
  });

  @override
  State<FicheAnneeScreen> createState() => _FicheAnneeScreenState();
}

class _FicheAnneeScreenState extends State<FicheAnneeScreen> {
  Map<String, dynamic>? _details;
  bool _chargement = true;
  String _filtreEleves = 'tous';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final data = await AnneeService.detailsAnnee(widget.anneeId);
      setState(() {
        _details = data;
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

  void _bientot() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fonctionnalité à venir')));
  }

  @override
  Widget build(BuildContext context) {
    final couleurAppBar = widget.statut == 'active' ? _vert : _grisFonce;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: couleurAppBar,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.libelle,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.statut.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            isScrollable: true,
            tabs: const [
              Tab(text: '📊 Vue générale'),
              Tab(text: '👥 Élèves'),
              Tab(text: '👨‍🏫 Enseignants'),
              Tab(text: '💰 Finances'),
            ],
          ),
        ),
        body: _chargement
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _breadcrumb(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _tabVueGenerale(),
                        _tabEleves(),
                        _tabEnseignants(),
                        _tabFinances(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _breadcrumb() {
    return Container(
      width: double.infinity,
      color: Colors.white.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Années',
              style: GoogleFonts.inter(fontSize: 12, color: _gris),
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: _gris),
          Text(
            widget.libelle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _grisFonce,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 1 — VUE GÉNÉRALE
  // ══════════════════════════════════════════════════════

  Widget _tabVueGenerale() {
    final stats = (_details?['stats'] as Map?) ?? {};
    final finances = (_details?['finances'] as Map?) ?? {};
    final periodes = (_details?['periodes'] as List?) ?? [];
    final classes = (_details?['classes'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              SSMStatCard(
                titre: 'Total élèves',
                valeur: '${stats['nombre_eleves'] ?? 0}',
                icone: Icons.people,
                couleurIcone: _indigo,
              ),
              SSMStatCard(
                titre: 'Taux de réussite',
                valeur: '${stats['taux_reussite'] ?? 0}%',
                icone: Icons.school,
                couleurIcone: _vert,
              ),
              SSMStatCard(
                titre: 'Total encaissé',
                valeur: '${finances['total_encaisse'] ?? 0} FCFA',
                icone: Icons.payments,
                couleurIcone: _teal,
              ),
              SSMStatCard(
                titre: 'Absences totales',
                valeur: '${stats['absences_total'] ?? 0}',
                icone: Icons.event_busy,
                couleurIcone: _orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SSMSectionTitre(titre: 'Périodes'),
          if (periodes.isEmpty)
            Text('Aucune période', style: GoogleFonts.inter(color: _gris))
          else
            ...periodes.map((p) => _cartePeriode(p as Map<String, dynamic>)),
          const SizedBox(height: 20),
          SSMSectionTitre(titre: 'Classes'),
          if (classes.isEmpty)
            Text('Aucune classe', style: GoogleFonts.inter(color: _gris))
          else
            ...classes.map((c) => _carteClasse(c as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _cartePeriode(Map<String, dynamic> p) {
    final couleur = _couleurStatutPeriode(p['statut'] as String);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${p['nom']}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (p['code'] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${p['code']}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: _gris,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${p['date_debut']} → ${p['date_fin']}',
                  style: GoogleFonts.inter(fontSize: 12, color: _gris),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p['notes_saisies']} notes saisies',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF334155),
                  ),
                ),
                Text(
                  '${p['bulletins_generes']} bulletins générés',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          SSMBadge(
            label: (p['statut'] as String).toUpperCase(),
            couleur: couleur,
          ),
        ],
      ),
    );
  }

  Widget _carteClasse(Map<String, dynamic> c) {
    final moyenne = (c['moyenne'] as num?)?.toDouble();
    final taux = (c['taux_reussite'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SSMListeTile(
        titre: c['nom'] as String,
        sousTitre: '${c['nombre_eleves']} élèves',
        icone: Icons.class_,
        couleurIcone: _indigo,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              moyenne != null ? '${moyenne.toStringAsFixed(1)}/20' : '—',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _couleurMoyenne(moyenne),
              ),
            ),
            const SizedBox(height: 2),
            SSMBadge(
              label: '$taux% réussite',
              couleur: taux >= 50 ? _vert : _rouge,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 2 — ÉLÈVES
  // ══════════════════════════════════════════════════════

  Widget _tabEleves() {
    final eleves = (_details?['eleves'] as List?) ?? [];
    final admis = eleves.where((e) => e['statut'] == 'admis').length;
    final redoublants = eleves.where((e) => e['statut'] == 'redoublant').length;
    final diplomes = eleves.where((e) => e['statut'] == 'diplome').length;

    final filtres = eleves.where((e) {
      if (_filtreEleves == 'tous') return true;
      return e['statut'] == _filtreEleves;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _miniCarte('$admis admis ✅', _vert)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniCarte('$redoublants redoublants ⚠️', _orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _miniCarte('$diplomes diplômés 🎓', _indigo)),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chipFiltre('Tous', 'tous'),
                    const SizedBox(width: 8),
                    _chipFiltre('Admis', 'admis'),
                    const SizedBox(width: 8),
                    _chipFiltre('Redoublants', 'redoublant'),
                    const SizedBox(width: 8),
                    _chipFiltre('Diplômés', 'diplome'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtres.isEmpty
              ? Center(
                  child: Text(
                    'Aucun élève',
                    style: GoogleFonts.inter(color: _gris),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtres.length,
                  itemBuilder: (context, index) =>
                      _carteEleve(filtres[index] as Map<String, dynamic>),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _indigo,
                side: const BorderSide(color: _indigo),
              ),
              onPressed: _bientot,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Exporter liste PDF'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniCarte(String texte, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: couleur,
        ),
      ),
    );
  }

  Widget _chipFiltre(String label, String valeur) {
    final actif = _filtreEleves == valeur;
    return GestureDetector(
      onTap: () => setState(() => _filtreEleves = valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? _indigo : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: actif ? _indigo : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: actif ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _carteEleve(Map<String, dynamic> e) {
    final photoUrl = e['photo_url'] as String?;
    final nom = e['nom'] as String? ?? '';
    final moyenne = (e['moyenne'] as num?)?.toDouble();
    final statut = e['statut'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _indigo.withValues(alpha: 0.15),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      color: _indigo,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nom ${e['prenom'] ?? ''}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  e['classe_nom'] as String? ?? '—',
                  style: GoogleFonts.inter(fontSize: 12, color: _gris),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moyenne != null ? '${moyenne.toStringAsFixed(1)}/20' : '—',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _couleurMoyenne(moyenne),
                ),
              ),
              const SizedBox(height: 2),
              if (statut != null)
                SSMBadge(
                  label: statut.toUpperCase(),
                  couleur: _couleurStatutEleve(statut),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — ENSEIGNANTS
  // ══════════════════════════════════════════════════════

  Widget _tabEnseignants() {
    final enseignants = (_details?['enseignants'] as List?) ?? [];

    if (enseignants.isEmpty) {
      return Center(
        child: Text(
          'Aucun enseignant affecté cette année',
          style: GoogleFonts.inter(color: _gris),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: enseignants.length,
        itemBuilder: (context, index) =>
            _carteEnseignant(enseignants[index] as Map<String, dynamic>),
      ),
    );
  }

  Widget _carteEnseignant(Map<String, dynamic> e) {
    final photoUrl = e['photo_url'] as String?;
    final nom = e['nom'] as String? ?? '';
    final classes = (e['classes'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _teal.withValues(alpha: 0.15),
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Text(
                        nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (e['fonction'] != null)
                      Text(
                        '${e['fonction']}',
                        style: GoogleFonts.inter(fontSize: 12, color: _gris),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: classes.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${c['classe_nom']} - ${c['matiere_nom']}',
                  style: GoogleFonts.inter(fontSize: 11, color: _teal),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '${e['notes_saisies']} notes saisies',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            '${e['evaluations_creees']} évaluations créées',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 4 — FINANCES
  // ══════════════════════════════════════════════════════

  Widget _tabFinances() {
    final finances = (_details?['finances'] as Map?) ?? {};
    final attendu = (finances['total_attendu'] as num?)?.toDouble() ?? 0;
    final encaisse = (finances['total_encaisse'] as num?)?.toDouble() ?? 0;
    final restant = (finances['total_restant'] as num?)?.toDouble() ?? 0;
    final recouvrement = attendu > 0
        ? (encaisse / attendu).clamp(0.0, 1.0)
        : 0.0;
    final dettes = (finances['eleves_dettes'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _colonneFinance(
                      'Total attendu',
                      attendu,
                      const Color(0xFF334155),
                    ),
                    _colonneFinance('Total encaissé', encaisse, _vert),
                    _colonneFinance('Total restant', restant, _rouge),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: recouvrement,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: recouvrement > 0.8
                        ? _vert
                        : (recouvrement > 0.5 ? _orange : _rouge),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(recouvrement * 100).toStringAsFixed(0)}% de recouvrement',
                  style: GoogleFonts.inter(fontSize: 12, color: _gris),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SSMSectionTitre(titre: '💸 Dettes non soldées'),
          if (dettes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: _vert, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Tous les élèves sont en règle',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            )
          else
            ...dettes.map((d) => _carteDette(d as Map<String, dynamic>)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                try {
                  final chemin = await DashboardFraisService.telechargerRapport(
                    anneeScolaireId: widget.anneeId,
                  );
                  await OpenFile.open(chemin);
                } catch (e) {
                  _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                }
              },
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Exporter rapport financier PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colonneFinance(String label, double valeur, Color couleur) {
    return Column(
      children: [
        Text(
          valeur.toStringAsFixed(0),
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: couleur,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _gris)),
      ],
    );
  }

  Widget _carteDette(Map<String, dynamic> d) {
    final du = (d['montant_du'] as num?)?.toDouble() ?? 0;
    final paye = (d['montant_paye'] as num?)?.toDouble() ?? 0;
    final progression = du > 0 ? (paye / du).clamp(0.0, 1.0) : 0.0;
    final nom = d['nom'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _rouge.withValues(alpha: 0.12),
            child: Text(
              nom.isNotEmpty ? nom[0].toUpperCase() : '?',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                color: _rouge,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nom ${d['prenom'] ?? ''}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  d['classe_nom'] as String? ?? '—',
                  style: GoogleFonts.inter(fontSize: 12, color: _gris),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progression,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: _vert,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                du.toStringAsFixed(0),
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _rouge,
                ),
              ),
              Text(
                paye.toStringAsFixed(0),
                style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _vert,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
