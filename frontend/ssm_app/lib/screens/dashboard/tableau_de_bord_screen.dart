import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_service.dart';
import '../../services/absence_service.dart';
import '../../services/paiement_service.dart';
import 'menu_lateral.dart';

class TableauDeBordScreen extends StatefulWidget {
  const TableauDeBordScreen({super.key});

  @override
  State<TableauDeBordScreen> createState() => _TableauDeBordScreenState();
}

class _TableauDeBordScreenState extends State<TableauDeBordScreen> {
  Utilisateur? _utilisateur;

  String? _anneeLibelle;
  Map<String, dynamic>? _statistiques;
  Map<String, dynamic>? _statsAbsences;
  List<dynamic> _derniersPaiements = [];
  bool _chargementDonnees = true;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateur();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await AuthService.getUtilisateur();

    if (u != null && !u.motDePasseChange && mounted) {
      Navigator.pushReplacementNamed(context, '/changer-mot-de-passe');
      return;
    }

    setState(() => _utilisateur = u);
    _chargerDonneesTableauDeBord();
  }

  Future<void> _chargerDonneesTableauDeBord() async {
    setState(() => _chargementDonnees = true);
    try {
      final annees = await AnneeService.listerAnnees();
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;

      final resultats = await Future.wait([
        StatistiqueService.chargerStatistiques(anneeId: anneeId),
        AbsenceService.statistiques(),
        PaiementService.listerPaiements(),
      ]);

      setState(() {
        _anneeLibelle = anneeEnCours?['libelle'] as String?;
        _statistiques = resultats[0] as Map<String, dynamic>;
        _statsAbsences = resultats[1] as Map<String, dynamic>;
        _derniersPaiements = (resultats[2] as List).take(5).toList();
        _chargementDonnees = false;
      });
    } catch (e) {
      setState(() => _chargementDonnees = false);
    }
  }

  int get _totalEleves =>
      (_statistiques?['effectifs']?['total'] as num?)?.toInt() ?? 0;

  int get _notesAValider =>
      (_statistiques?['notes']?['par_statut']?['soumis'] as num?)?.toInt() ?? 0;

  int get _absencesAujourdhui =>
      (_statsAbsences?['absents_aujourdhui'] as num?)?.toInt() ?? 0;

  List<dynamic> get _paiementsParMois =>
      (_statistiques?['finances']?['paiements_mois'] as List?) ?? [];

  double _montantPourMois(int mois, int annee) {
    final entree = _paiementsParMois.firstWhere(
      (p) => p['mois'] == mois && p['annee'] == annee,
      orElse: () => null,
    );
    return entree != null
        ? double.tryParse(entree['total'].toString()) ?? 0
        : 0;
  }

  double get _montantMoisActuel {
    final now = DateTime.now();
    return _montantPourMois(now.month, now.year);
  }

  // Variation réelle mois en cours vs mois précédent (null si pas de référence)
  double? get _variationPaiements {
    final now = DateTime.now();
    final moisPrecedent = now.month == 1 ? 12 : now.month - 1;
    final anneePrecedente = now.month == 1 ? now.year - 1 : now.year;
    final montantPrecedent = _montantPourMois(moisPrecedent, anneePrecedente);

    if (montantPrecedent <= 0) return null;
    return (_montantMoisActuel - montantPrecedent) / montantPrecedent * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (_utilisateur == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Text(
          'Tableau de bord',
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonneesTableauDeBord,
          ),
        ],
      ),
      drawer: MenuLateral(utilisateur: _utilisateur!),
      body: RefreshIndicator(
        onRefresh: _chargerDonneesTableauDeBord,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionBienvenue(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionStatistiques(),
                    const SizedBox(height: 28),
                    _sectionActionsRapides(context),
                    const SizedBox(height: 28),
                    _sectionActiviteRecente(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 1 — Bandeau de bienvenue
  // ══════════════════════════════════════════════════════

  Widget _sectionBienvenue() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, ${_utilisateur!.nom} 👋',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'École ${_utilisateur!.codeEcole}'
                  '${_anneeLibelle != null ? ' — Année $_anneeLibelle' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$_totalEleves',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'élèves',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 2 — Cartes statistiques
  // ══════════════════════════════════════════════════════

  Widget _sectionStatistiques() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _carteStatistique(
          icone: Icons.people,
          couleur: const Color(0xFF1E3A8A),
          valeur: _chargementDonnees ? '—' : '$_totalEleves',
          label: 'Total Élèves',
        ),
        _carteStatistique(
          icone: Icons.payments,
          couleur: const Color(0xFF0D9488),
          valeur: _chargementDonnees
              ? '—'
              : '${_montantMoisActuel.toStringAsFixed(0)} FCFA',
          label: 'Paiements du mois',
          variation: _variationPaiements,
        ),
        _carteStatistique(
          icone: Icons.event_busy,
          couleur: const Color(0xFFEA580C),
          valeur: _chargementDonnees ? '—' : '$_absencesAujourdhui',
          label: 'Absences aujourd\'hui',
        ),
        _carteStatistique(
          icone: Icons.grade,
          couleur: const Color(0xFFD97706),
          valeur: _chargementDonnees ? '—' : '$_notesAValider',
          label: 'Notes à valider',
        ),
      ],
    );
  }

  Widget _carteStatistique({
    required IconData icone,
    required Color couleur,
    required String valeur,
    required String label,
    double? variation,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleur, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            valeur,
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
            ),
          ),
          if (variation != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (variation >= 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${variation >= 0 ? '+' : ''}${variation.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: variation >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 3 — Actions rapides
  // ══════════════════════════════════════════════════════

  Widget _sectionActionsRapides(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accès rapide',
          style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: _actionsRapides(context),
        ),
      ],
    );
  }

  List<Widget> _actionsRapides(BuildContext context) {
    final actions = <Widget>[
      // Pour tout le monde
      _boutonAction(context,
        icone: Icons.sync,
        label: 'Synchronisation',
        route: '/sync',
      ),
    ];

    // ── Directeur ─────────────────────────────────────────
    if (_utilisateur!.estDirecteur) {
      actions.addAll([
        _boutonAction(context, icone: Icons.people, label: 'Utilisateurs', route: '/directeur/utilisateurs'),
        _boutonAction(context, icone: Icons.class_, label: 'Classes', route: '/directeur/classes'),
        _boutonAction(context, icone: Icons.book, label: 'Matières', route: '/directeur/matieres'),
        _boutonAction(context, icone: Icons.calendar_month, label: 'Années & Périodes', route: '/directeur/annees'),
        _boutonAction(context, icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        _boutonAction(context, icone: Icons.price_change, label: 'Frais scolaires', route: '/directeur/frais'),
        _boutonAction(context, icone: Icons.edit_note, label: 'Saisie Notes', route: '/enseignant/notes'),
        _boutonAction(context, icone: Icons.grade, label: 'Validation Notes', route: '/notes/validation'),
        _boutonAction(context, icone: Icons.payment, label: 'Paiements', route: '/paiements'),
        _boutonAction(context, icone: Icons.person_remove, label: 'Liste de renvoi', route: '/paiements/renvoi'),
        _boutonAction(context, icone: Icons.bar_chart, label: 'Statistiques', route: '/statistiques'),
        _boutonAction(context, icone: Icons.description, label: 'Bulletins', route: '/bulletins'),
        _boutonAction(context, icone: Icons.event_busy, label: 'Absences', route: '/enseignant/absences'),
        _boutonAction(context, icone: Icons.send_to_mobile, label: 'Notifications', route: '/notifications'),
      ]);
    }

    // ── Censeur ───────────────────────────────────────────
    if (_utilisateur!.estCenseur) {
      actions.addAll([
        _boutonAction(context, icone: Icons.grade, label: 'Validation Notes', route: '/notes/validation'),
        _boutonAction(context, icone: Icons.description, label: 'Bulletins', route: '/bulletins'),
        _boutonAction(context, icone: Icons.event_busy, label: 'Absences', route: '/enseignant/absences'),
      ]);
    }

    // ── Secrétaire ────────────────────────────────────────
    if (_utilisateur!.estSecretaire) {
      actions.addAll([
        _boutonAction(context, icone: Icons.payment, label: 'Paiements', route: '/paiements'),
        _boutonAction(context, icone: Icons.person_remove, label: 'Liste de renvoi', route: '/paiements/renvoi'),
        _boutonAction(context, icone: Icons.send_to_mobile, label: 'Notifications', route: '/notifications'),
      ]);
    }

    // ── Enseignant ────────────────────────────────────────
    if (_utilisateur!.estEnseignant) {
      actions.addAll([
        _boutonAction(context, icone: Icons.edit_note, label: 'Saisie des notes', route: '/enseignant/notes'),
        _boutonAction(context, icone: Icons.event_busy, label: 'Absences', route: '/enseignant/absences'),
      ]);
    }

    return actions;
  }

  Widget _boutonAction(
    BuildContext context, {
    required IconData icone,
    required String label,
    required String route,
  }) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
        highlightColor: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 28, color: const Color(0xFF1E3A8A)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 4 — Activité récente
  // ══════════════════════════════════════════════════════

  Widget _sectionActiviteRecente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité récente',
          style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_chargementDonnees)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ))
        else if (_derniersPaiements.isEmpty)
          Text(
            'Aucune activité récente',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          )
        else
          ..._derniersPaiements.map((p) {
            final eleve = p['eleve'];
            final nomEleve =
                eleve != null ? '${eleve['nom']} ${eleve['prenom']}' : 'Élève inconnu';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: Color(0xFF16A34A), width: 3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF16A34A),
                  child: Icon(Icons.payment, color: Colors.white, size: 18),
                ),
                title: Text(
                  nomEleve,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${p['tranche']} • ${p['montant']} FCFA',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                trailing: Text(
                  '${p['date_paiement']}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                ),
              ),
            );
          }),
      ],
    );
  }
}
