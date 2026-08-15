import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/frais_scolaire_model.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import 'frais_scolaire_form_screen.dart';

String _formatDateCourt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '${buffer.toString()} FCFA';
}

class FraisScolairesScreen extends StatefulWidget {
  const FraisScolairesScreen({super.key});

  @override
  State<FraisScolairesScreen> createState() => _FraisScolairesScreenState();
}

class _FraisScolairesScreenState extends State<FraisScolairesScreen> {
  Utilisateur? _utilisateur;

  List<FraisScolaire> _frais = [];
  List<dynamic> _classes = [];
  List<dynamic> _annees = [];

  int? _filtreClasseId;
  int? _filtreAnneeId;
  bool? _filtreActif;

  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    AuthService.getUtilisateur().then((u) {
      if (mounted) setState(() => _utilisateur = u);
    });
    _chargerReferences();
    _chargerListe();
  }

  Future<void> _chargerReferences() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      setState(() {
        _classes = resultats[0];
        _annees = resultats[1];
        _filtreAnneeId ??= _anneeParDefaut();
      });
    } catch (_) {
      // Listes de référence non bloquantes pour l'affichage.
    }
  }

  int? _anneeParDefaut() {
    if (_annees.isEmpty) return null;
    final active = _annees.firstWhere(
      (a) => a['statut'] == 'active',
      orElse: () => null,
    );
    return active?['id'] as int?;
  }

  Future<void> _chargerListe() async {
    setState(() => _chargement = true);
    try {
      final frais = await FraisScolaireService.getFrais(
        classeId: _filtreClasseId,
        anneeScolaireId: _filtreAnneeId,
        actif: _filtreActif,
      );
      setState(() {
        _frais = frais;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.teal),
    );
  }

  Future<void> _ouvrirFormulaire({FraisScolaire? frais}) async {
    final resultat = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FraisScolaireFormScreen(
          fraisExistant: frais,
          anneeScolaireParDefaut: _filtreAnneeId ?? _anneeParDefaut(),
        ),
      ),
    );
    if (resultat == true) _chargerListe();
  }

  Future<void> _confirmerDesactivation(FraisScolaire frais) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Désactiver ce frais ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          '"${frais.nom}" ne sera plus proposé aux nouveaux paiements, mais son historique reste conservé.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await FraisScolaireService.desactiverFrais(frais.id!);
      _afficherSucces('Frais "${frais.nom}" désactivé');
      _chargerListe();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _naviguer(BuildContext context, String route) {
    if (route == '/directeur/frais') return;
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

  List<SSMNavSection> _sections() {
    final actifs = _frais.where((f) => f.actif).length;
    return [
      SSMNavSection(titre: 'Principal', items: [
        const SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        const SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        const SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        SSMNavItem(
          icone: Icons.price_change_outlined,
          label: 'Frais scolaires',
          route: '/directeur/frais',
          badge: (!_chargement && actifs > 0) ? actifs : null,
        ),
        const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        const SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      const SSMNavSection(titre: 'Pilotage', items: [
        SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/directeur/frais',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Frais scolaires',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        backgroundColor: SSMPalette.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nouveau frais',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frais scolaires',
            style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 3),
          Text(
            '${_frais.where((f) => f.actif).length} frais actif(s) sur ${_frais.length}',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 16),
          _barreFiltres(),
          const SizedBox(height: 16),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
            )
          else if (_frais.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Aucun frais scolaire trouvé', style: GoogleFonts.inter(color: SSMPalette.texte3)),
              ),
            )
          else
            LayoutBuilder(builder: (context, contraintes) {
              return contraintes.maxWidth >= 760 ? _tableFrais() : _listeCartes();
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FILTRES
  // ══════════════════════════════════════════════════════

  Widget _barreFiltres() {
    return Row(
      children: [
        Expanded(child: _dropdown<int?>(
          valeur: _filtreClasseId,
          hint: 'Classe',
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Toutes les classes')),
            ..._classes.map(
              (c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['nom'] as String)),
            ),
          ],
          onChanged: (v) {
            setState(() => _filtreClasseId = v);
            _chargerListe();
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: _dropdown<int?>(
          valeur: _filtreAnneeId,
          hint: 'Année',
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Toutes')),
            ..._annees.map(
              (a) => DropdownMenuItem<int?>(value: a['id'] as int, child: Text(a['libelle'] as String)),
            ),
          ],
          onChanged: (v) {
            setState(() => _filtreAnneeId = v);
            _chargerListe();
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: _dropdown<bool?>(
          valeur: _filtreActif,
          hint: 'Statut',
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Tous')),
            DropdownMenuItem<bool?>(value: true, child: Text('Actifs')),
            DropdownMenuItem<bool?>(value: false, child: Text('Inactifs')),
          ],
          onChanged: (v) {
            setState(() => _filtreActif = v);
            _chargerListe();
          },
        )),
      ],
    );
  }

  Widget _dropdown<T>({
    required T valeur,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valeur,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16, color: SSMPalette.texte3),
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLEAU (desktop large)
  // ══════════════════════════════════════════════════════

  Widget _tableFrais() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Nom'),
        SSMDataColumn('Classe'),
        SSMDataColumn('Montant'),
        SSMDataColumn('Échéance'),
        SSMDataColumn('Statut'),
        SSMDataColumn('Actions'),
      ],
      onLigneTap: (i) => _ouvrirFormulaire(frais: _frais[i]),
      lignes: [for (final f in _frais) _ligneFrais(f)],
    );
  }

  List<Widget> _ligneFrais(FraisScolaire frais) {
    final classeLabel = frais.classeNom ?? 'Toutes classes';
    return [
      Text(frais.nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
      Text(
        frais.serie != null ? '$classeLabel (${frais.serie})' : classeLabel,
        style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
      ),
      Text(
        _formatMontant(frais.montant),
        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: frais.actif ? SSMPalette.indigo : SSMPalette.texte3),
      ),
      Text(_formatDateCourt(frais.dateLimite), style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          frais.obligatoire ? const SSMPill.retard(label: 'Obligatoire') : const SSMPill.paye(label: 'Facultatif'),
          SSMPill.couleur(label: frais.actif ? 'Actif' : 'Inactif', couleur: frais.actif ? SSMPalette.teal : SSMPalette.texte3),
        ],
      ),
      _menuActions(frais),
    ];
  }

  Widget _menuActions(FraisScolaire frais) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: SSMPalette.texte3, size: 20),
      onSelected: (valeur) {
        if (valeur == 'modifier') {
          _ouvrirFormulaire(frais: frais);
        } else if (valeur == 'desactiver') {
          _confirmerDesactivation(frais);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
        if (frais.actif) const PopupMenuItem(value: 'desactiver', child: Text('Désactiver')),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTES (mobile / tablette étroite)
  // ══════════════════════════════════════════════════════

  Widget _listeCartes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final f in _frais) _carteFrais(f)],
    );
  }

  Widget _carteFrais(FraisScolaire frais) {
    final couleur = frais.actif ? SSMPalette.indigo : SSMPalette.texte3;
    final classeLabel = frais.classeNom ?? 'Toutes classes';

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _ouvrirFormulaire(frais: frais),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 3),
            ),
          ),
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
                        Text(frais.nom, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.class_outlined, size: 13, color: SSMPalette.texte3),
                            const SizedBox(width: 4),
                            Text(classeLabel, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                            if (frais.serie != null) ...[
                              const SizedBox(width: 4),
                              Text('(${frais.serie})', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMontant(frais.montant),
                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: couleur),
                  ),
                  _menuActions(frais),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event, size: 13, color: SSMPalette.texte3),
                  const SizedBox(width: 4),
                  Text('Échéance : ${_formatDateCourt(frais.dateLimite)}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  const Spacer(),
                  frais.obligatoire ? const SSMPill.retard(label: 'Obligatoire') : const SSMPill.paye(label: 'Facultatif'),
                  const SizedBox(width: 6),
                  SSMPill.couleur(label: frais.actif ? 'Actif' : 'Inactif', couleur: frais.actif ? SSMPalette.teal : SSMPalette.texte3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
