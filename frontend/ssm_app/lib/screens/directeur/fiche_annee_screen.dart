import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/annee_service.dart';
import '../../services/dashboard_frais_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

Color _couleurStatutPeriode(String statut) {
  switch (statut) {
    case 'ouverte':
      return SSMPalette.teal;
    case 'en_veille':
      return SSMPalette.ambre;
    case 'en_validation':
      return SSMPalette.indigo;
    case 'cloturee':
      return SSMPalette.rouge;
    case 'archivee':
      return SSMPalette.texte3;
    default:
      return SSMPalette.texte3;
  }
}

Color _couleurStatutEleve(String? statut) {
  switch (statut) {
    case 'admis':
      return SSMPalette.teal;
    case 'redoublant':
      return SSMPalette.ambre;
    case 'diplome':
      return SSMPalette.indigo;
    default:
      return SSMPalette.texte3;
  }
}

Color _couleurMoyenne(double? m) {
  if (m == null) return SSMPalette.texte3;
  if (m >= 14) return SSMPalette.teal;
  if (m >= 10) return SSMPalette.indigo;
  return SSMPalette.rouge;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge),
    );
  }

  void _bientot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à venir')),
    );
  }

  Color get _couleurStatutAnneeActuelle {
    switch (widget.statut) {
      case 'active':
        return SSMPalette.teal;
      case 'cloturee':
        return SSMPalette.ambre;
      case 'archivee':
        return SSMPalette.texte3;
      default:
        return SSMPalette.texte3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: SSMPalette.fond,
        appBar: AppBar(
          backgroundColor: SSMPalette.blanc,
          foregroundColor: SSMPalette.texte1,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: SSMPalette.texte2),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: SSMPalette.texte2),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.libelle,
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SSMPill.couleur(label: widget.statut.toUpperCase(), couleur: _couleurStatutAnneeActuelle),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: SSMPalette.indigo,
            labelColor: SSMPalette.indigo,
            unselectedLabelColor: SSMPalette.texte3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
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
            ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
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
      color: SSMPalette.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Années', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
          ),
          const Icon(Icons.chevron_right, size: 14, color: SSMPalette.texte3),
          Text(
            widget.libelle,
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1, fontWeight: FontWeight.w600),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth >= 620 ? 4 : 2;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: colonnes,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 168,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, i) => [
                SSMStatCard(
                  icone: Icons.people,
                  couleur: SSMPalette.indigo,
                  valeur: '${stats['nombre_eleves'] ?? 0}',
                  label: 'Total élèves',
                ),
                SSMStatCard(
                  icone: Icons.school,
                  couleur: SSMPalette.teal,
                  valeur: '${stats['taux_reussite'] ?? 0}%',
                  label: 'Taux de réussite',
                ),
                SSMStatCard(
                  icone: Icons.payments,
                  couleur: SSMPalette.teal,
                  valeur: '${finances['total_encaisse'] ?? 0} FCFA',
                  label: 'Total encaissé',
                ),
                SSMStatCard(
                  icone: Icons.event_busy,
                  couleur: SSMPalette.ambre,
                  valeur: '${stats['absences_total'] ?? 0}',
                  label: 'Absences totales',
                ),
              ][i],
            );
          }),
          const SizedBox(height: 20),
          SSMPanel(
            titre: 'Périodes',
            padding: EdgeInsets.zero,
            child: periodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Aucune période', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SSMDataTable(
                      colonnes: const [
                        SSMDataColumn('Période'),
                        SSMDataColumn('Dates'),
                        SSMDataColumn('Notes saisies'),
                        SSMDataColumn('Bulletins'),
                        SSMDataColumn('Statut'),
                      ],
                      lignes: [
                        for (final p in periodes) _lignePeriode(p as Map<String, dynamic>),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          SSMPanel(
            titre: 'Classes',
            padding: EdgeInsets.zero,
            child: classes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Aucune classe', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SSMDataTable(
                      colonnes: const [
                        SSMDataColumn('Classe'),
                        SSMDataColumn('Effectif'),
                        SSMDataColumn('Moyenne'),
                        SSMDataColumn('Réussite'),
                      ],
                      lignes: [
                        for (final c in classes) _ligneClasse(c as Map<String, dynamic>),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _lignePeriode(Map<String, dynamic> p) {
    final couleur = _couleurStatutPeriode(p['statut'] as String);
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p['nom']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          if (p['code'] != null) ...[
            const SizedBox(width: 6),
            Text('${p['code']}', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: SSMPalette.texte3)),
          ],
        ],
      ),
      Text('${p['date_debut']} → ${p['date_fin']}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      Text('${p['notes_saisies']}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text('${p['bulletins_generes']}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      SSMPill.couleur(label: (p['statut'] as String).toUpperCase(), couleur: couleur),
    ];
  }

  List<Widget> _ligneClasse(Map<String, dynamic> c) {
    final moyenne = (c['moyenne'] as num?)?.toDouble();
    final taux = (c['taux_reussite'] as num?)?.toDouble() ?? 0;
    return [
      Text('${c['nom']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
      Text('${c['nombre_eleves']} élèves', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      Text(
        moyenne != null ? '${moyenne.toStringAsFixed(1)}/20' : '—',
        style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: _couleurMoyenne(moyenne)),
      ),
      SSMPill.couleur(label: '$taux%', couleur: taux >= 50 ? SSMPalette.teal : SSMPalette.rouge),
    ];
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
                  Expanded(child: _miniCarte('$admis admis ✅', SSMPalette.teal)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniCarte('$redoublants redoublants ⚠️', SSMPalette.ambre)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniCarte('$diplomes diplômés 🎓', SSMPalette.indigo)),
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
              ? Center(child: Text('Aucun élève', style: GoogleFonts.inter(color: SSMPalette.texte3)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtres.length,
                  itemBuilder: (context, index) => _carteEleve(filtres[index] as Map<String, dynamic>),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.indigo, side: const BorderSide(color: SSMPalette.indigo, width: 1.5)),
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
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: couleur),
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
          color: actif ? SSMPalette.indigo : SSMPalette.blanc,
          borderRadius: BorderRadius.circular(SSMRayons.pilule),
          border: Border.all(color: actif ? SSMPalette.indigo : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.white : SSMPalette.texte1),
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
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        children: [
          SSMAvatar(nom: nom, photoUrl: photoUrl, rayon: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nom ${e['prenom'] ?? ''}', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                Text(e['classe_nom'] as String? ?? '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moyenne != null ? '${moyenne.toStringAsFixed(1)}/20' : '—',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _couleurMoyenne(moyenne)),
              ),
              const SizedBox(height: 2),
              if (statut != null) SSMPill.couleur(label: statut.toUpperCase(), couleur: _couleurStatutEleve(statut)),
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
        child: Text('Aucun enseignant affecté cette année', style: GoogleFonts.inter(color: SSMPalette.texte3)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: enseignants.length,
      itemBuilder: (context, index) => _carteEnseignant(enseignants[index] as Map<String, dynamic>),
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
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SSMAvatar(nom: nom, photoUrl: photoUrl, couleur: SSMPalette.teal, rayon: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    if (e['fonction'] != null)
                      Text('${e['fonction']}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: SSMPalette.tealClair,
                  borderRadius: BorderRadius.circular(SSMRayons.pilule),
                ),
                child: Text(
                  '${c['classe_nom']} - ${c['matiere_nom']}',
                  style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.teal),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text('${e['notes_saisies']} notes saisies', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
          Text('${e['evaluations_creees']} évaluations créées', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
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
    final recouvrement = attendu > 0 ? (encaisse / attendu).clamp(0.0, 1.0) : 0.0;
    final dettes = (finances['eleves_dettes'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SSMPalette.blanc,
              borderRadius: BorderRadius.circular(SSMRayons.grand),
              border: Border.all(color: SSMPalette.bordure),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _colonneFinance('Total attendu', attendu, SSMPalette.texte1),
                    _colonneFinance('Total encaissé', encaisse, SSMPalette.teal),
                    _colonneFinance('Total restant', restant, SSMPalette.rouge),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: recouvrement,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: recouvrement > 0.8 ? SSMPalette.teal : (recouvrement > 0.5 ? SSMPalette.ambre : SSMPalette.rouge),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${(recouvrement * 100).toStringAsFixed(0)}% de recouvrement', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SSMPanel(
            titre: '💸 Dettes non soldées',
            padding: EdgeInsets.zero,
            child: dettes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, color: SSMPalette.teal, size: 44),
                        const SizedBox(height: 8),
                        Text('Tous les élèves sont en règle', style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1)),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SSMDataTable(
                      colonnes: const [
                        SSMDataColumn('Élève'),
                        SSMDataColumn('Classe'),
                        SSMDataColumn('Dû'),
                        SSMDataColumn('Payé'),
                      ],
                      lignes: [
                        for (final d in dettes) _ligneDette(d as Map<String, dynamic>),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  final chemin = await DashboardFraisService.telechargerRapport(anneeScolaireId: widget.anneeId);
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
        Text(valeur.toStringAsFixed(0), style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: couleur)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
      ],
    );
  }

  List<Widget> _ligneDette(Map<String, dynamic> d) {
    final du = (d['montant_du'] as num?)?.toDouble() ?? 0;
    final paye = (d['montant_paye'] as num?)?.toDouble() ?? 0;
    final nom = d['nom'] as String? ?? '';

    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SSMAvatar(nom: nom, couleur: SSMPalette.rouge, rayon: 14),
          const SizedBox(width: 8),
          Text('$nom ${d['prenom'] ?? ''}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
        ],
      ),
      Text(d['classe_nom'] as String? ?? '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      Text(du.toStringAsFixed(0), style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
      Text(paye.toStringAsFixed(0), style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.teal)),
    ];
  }
}
