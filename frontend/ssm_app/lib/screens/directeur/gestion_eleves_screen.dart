import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

const List<Map<String, String>> _statutsEleve = [
  {'valeur': 'actif', 'label': 'Actif'},
  {'valeur': 'suspendu', 'label': 'Suspendu'},
  {'valeur': 'exclu', 'label': 'Exclu'},
  {'valeur': 'transfere', 'label': 'Transféré'},
  {'valeur': 'diplome', 'label': 'Diplômé'},
  {'valeur': 'abandon', 'label': 'Abandon'},
];

Color _couleurStatutEleve(String? statut) {
  switch (statut) {
    case 'actif':
      return SSMPalette.indigo;
    case 'suspendu':
      return SSMPalette.ambre;
    case 'exclu':
      return SSMPalette.rouge;
    case 'diplome':
      return SSMPalette.teal;
    case 'transfere':
      return SSMPalette.teal;
    case 'abandon':
      return SSMPalette.texte3;
    default:
      return SSMPalette.texte3;
  }
}

enum _OngletEleves { tableauDeBord, liste }

class GestionElevesScreen extends StatefulWidget {
  const GestionElevesScreen({super.key});

  @override
  State<GestionElevesScreen> createState() => _GestionElevesScreenState();
}

class _GestionElevesScreenState extends State<GestionElevesScreen> {
  _OngletEleves _onglet = _OngletEleves.tableauDeBord;

  Utilisateur? _utilisateur;

  bool _chargementDashboard = true;
  Map<String, dynamic> _dashboard = {};

  List<dynamic> _classes = [];
  List<dynamic> _annees = [];
  Map<String, dynamic>? _anneeActive;

  bool _chargementListe = true;
  Map<String, dynamic> _elevesPage = {};
  int _page = 1;

  int? _filtreClasseId;
  String? _filtreSexe;
  String? _filtreStatut;
  bool? _filtreEnRegle;
  final _rechercheController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AuthService.getUtilisateur().then((u) {
      if (mounted) setState(() => _utilisateur = u);
    });
    _chargerTout();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerTout() async {
    setState(() {
      _chargementDashboard = true;
      _chargementListe = true;
    });
    try {
      final resultats = await Future.wait([
        EleveService.tableauDeBord(),
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final annees = resultats[1] as List<dynamic>;
      setState(() {
        _dashboard = resultats[0] as Map<String, dynamic>;
        _classes = resultats[1] as List<dynamic>;
        _annees = annees;
        _anneeActive = annees
            .cast<Map<String, dynamic>>()
            .firstWhere((a) => a['statut'] == 'active', orElse: () => {});
        _chargementDashboard = false;
      });
    } catch (e) {
      setState(() => _chargementDashboard = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
    await _chargerListe();
  }

  Future<void> _chargerListe() async {
    setState(() => _chargementListe = true);
    try {
      final data = await EleveService.lister(
        classeId: _filtreClasseId,
        sexe: _filtreSexe,
        statut: _filtreStatut,
        enRegle: _filtreEnRegle,
        recherche: _rechercheController.text.trim().isEmpty
            ? null
            : _rechercheController.text.trim(),
        page: _page,
      );
      setState(() {
        _elevesPage = data;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge),
    );
  }

  void _ouvrirListeIntelligente(String type, String titre) {
    Navigator.pushNamed(context, '/eleves/liste-intelligente', arguments: {'type': type, 'titre': titre});
  }

  void _naviguer(BuildContext context, String route) {
    if (route == '/directeur/eleves') return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _exporter({required bool pdf}) async {
    try {
      final chemin = pdf
          ? await EleveService.exporterPdf()
          : await EleveService.exporterExcel();
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/directeur/eleves',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Élèves',
      floatingActionButton: _onglet == _OngletEleves.liste
          ? FloatingActionButton.extended(
              backgroundColor: SSMPalette.indigo,
              foregroundColor: Colors.white,
              onPressed: _dialogCreerEleve,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nouvel élève'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Élèves',
            style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 12),
          _segments(),
          const SizedBox(height: 16),
          if (_onglet == _OngletEleves.tableauDeBord) _ongletTableauDeBord() else _ongletListe(),
        ],
      ),
    );
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
    final total = _dashboard['total'] as int?;
    return [
      SSMNavSection(titre: 'Principal', items: [
        const SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(
          icone: Icons.people_outline,
          label: 'Élèves',
          route: '/directeur/eleves',
          badge: (!_chargementDashboard && (total ?? 0) > 0) ? total : null,
        ),
        const SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        const SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        const SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      SSMNavSection(titre: 'Pilotage', items: [
        const SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        const SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
      if (_utilisateur?.role == 'directeur')
        const SSMNavSection(titre: 'Administration', items: [
          SSMNavItem(icone: Icons.people_alt_outlined, label: 'Utilisateurs', route: '/directeur/utilisateurs'),
          SSMNavItem(icone: Icons.class_outlined, label: 'Classes', route: '/directeur/classes'),
          SSMNavItem(icone: Icons.menu_book_outlined, label: 'Matières', route: '/directeur/matieres'),
          SSMNavItem(icone: Icons.calendar_month_outlined, label: 'Années & Périodes', route: '/directeur/annees'),
        ]),
    ];
  }

  // ── Sélecteur d'onglet (remplace la TabBar de l'ancien AppBar) ──
  Widget _segments() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
      child: Row(
        children: [
          Expanded(child: _segment('📊 Tableau de bord', _OngletEleves.tableauDeBord)),
          Expanded(child: _segment('👥 Liste des élèves', _OngletEleves.liste)),
        ],
      ),
    );
  }

  Widget _segment(String label, _OngletEleves valeur) {
    final actif = _onglet == valeur;
    return GestureDetector(
      onTap: () => setState(() => _onglet = valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.blanc : Colors.transparent,
          borderRadius: BorderRadius.circular(SSMRayons.petit),
          boxShadow: actif ? SSMOmbres.legere : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
            color: actif ? SSMPalette.indigo : SSMPalette.texte2,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — TABLEAU DE BORD
  // ══════════════════════════════════════════════════════

  Widget _ongletTableauDeBord() {
    if (_chargementDashboard) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }

    final total = _dashboard['total'] ?? 0;
    final garcons = _dashboard['garcons'] ?? 0;
    final filles = _dashboard['filles'] ?? 0;
    final parStatut = (_dashboard['par_statut'] as Map?) ?? {};

    final cartes = <_CarteFiltre>[
      _CarteFiltre('En règle', '${_dashboard['en_regle'] ?? 0}', Icons.check_circle, SSMPalette.teal, 'en_regle', 'En règle'),
      _CarteFiltre('En retard', '${_dashboard['en_retard_paiement'] ?? 0}', Icons.money_off, SSMPalette.rouge, 'en_retard_paiement', 'En retard de paiement'),
      _CarteFiltre("Absents aujourd'hui", '${_dashboard['absents_aujourd_hui'] ?? 0}', Icons.event_busy, SSMPalette.ambre, 'absents_aujourd_hui', "Absents aujourd'hui"),
      _CarteFiltre('Suspendus', '${parStatut['suspendu'] ?? 0}', Icons.block, SSMPalette.rouge, 'suspendus', 'Suspendus'),
      _CarteFiltre('Redoublants', '${_dashboard['redoublants'] ?? 0}', Icons.replay, SSMPalette.ambre, 'redoublants', 'Redoublants'),
      _CarteFiltre('Diplômés', '${parStatut['diplome'] ?? 0}', Icons.school, SSMPalette.indigo, 'diplomes', 'Diplômés'),
      _CarteFiltre('Transférés', '${parStatut['transfere'] ?? 0}', Icons.transfer_within_a_station, SSMPalette.teal, 'transferes', 'Transférés'),
      _CarteFiltre('Abandons', '${parStatut['abandon'] ?? 0}', Icons.exit_to_app, SSMPalette.texte3, 'abandons', 'Abandons'),
      _CarteFiltre('Moyenne > 15', '${_dashboard['moyenne_sup_15'] ?? 0}', Icons.star, SSMPalette.teal, 'moyenne_sup_15', 'Moyenne > 15'),
      _CarteFiltre('En difficulté', '${_dashboard['en_difficulte'] ?? 0}', Icons.trending_down, SSMPalette.rouge, 'en_difficulte', 'En difficulté'),
      _CarteFiltre('Sans photo', '${_dashboard['sans_photo'] ?? 0}', Icons.no_photography, SSMPalette.texte3, 'sans_photo', 'Sans photo'),
      _CarteFiltre('Sans téléphone parent', '${_dashboard['sans_telephone_parent'] ?? 0}', Icons.phone_disabled, SSMPalette.ambre, 'sans_telephone', 'Sans téléphone parent'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$total élèves inscrits · $garcons garçons · $filles filles'
          '${(_anneeActive != null && _anneeActive!.isNotEmpty) ? ' · Année ${_anneeActive!['libelle']}' : ''}',
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
        ),
        const SizedBox(height: 16),
        Text(
          'Statistiques — cliquez pour voir les listes',
          style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, contraintes) {
          final colonnes = contraintes.maxWidth >= 760 ? 4 : (contraintes.maxWidth >= 520 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colonnes,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 168,
            ),
            itemBuilder: (context, i) {
              final c = cartes[i];
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(SSMRayons.grand),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SSMRayons.grand),
                  onTap: () => _ouvrirListeIntelligente(c.type, c.titre),
                  child: SSMStatCard(
                    icone: c.icone,
                    couleur: c.couleur,
                    valeur: c.valeur,
                    label: c.label,
                    sousTexte: 'Voir la liste →',
                    tendance: SSMTendance.neutre,
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SSMQuickActionButton(
              icone: Icons.picture_as_pdf,
              label: 'Exporter PDF',
              variante: SSMActionVariante.gris,
              onTap: () => _exporter(pdf: true),
            ),
            SSMQuickActionButton(
              icone: Icons.table_chart,
              label: 'Exporter Excel',
              variante: SSMActionVariante.teal,
              onTap: () => _exporter(pdf: false),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — LISTE DES ÉLÈVES
  // ══════════════════════════════════════════════════════

  Widget _ongletListe() {
    final data = (_elevesPage['data'] as List?) ?? [];
    final currentPage = _elevesPage['current_page'] as int? ?? 1;
    final lastPage = _elevesPage['last_page'] as int? ?? 1;

    final groupes = <String, List<dynamic>>{};
    for (final e in data) {
      final classe = e['classe_actuelle'] as Map<String, dynamic>?;
      final nom = classe?['nom'] as String? ?? 'Non affecté';
      groupes.putIfAbsent(nom, () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barreRecherche(),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _dropdownFiltre<int>(
                label: 'Classe',
                valeur: _filtreClasseId,
                items: _classes
                    .cast<Map<String, dynamic>>()
                    .map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'] as String)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _filtreClasseId = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
              const SizedBox(width: 8),
              _dropdownFiltre<String>(
                label: 'Sexe',
                valeur: _filtreSexe,
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculin')),
                  DropdownMenuItem(value: 'F', child: Text('Féminin')),
                ],
                onChanged: (v) {
                  setState(() => _filtreSexe = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
              const SizedBox(width: 8),
              _dropdownFiltre<String>(
                label: 'Statut',
                valeur: _filtreStatut,
                items: _statutsEleve
                    .map((s) => DropdownMenuItem(value: s['valeur'], child: Text(s['label']!)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _filtreStatut = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
              const SizedBox(width: 8),
              _dropdownFiltre<bool>(
                label: 'Paiement',
                valeur: _filtreEnRegle,
                items: const [
                  DropdownMenuItem(value: true, child: Text('En règle')),
                  DropdownMenuItem(value: false, child: Text('En retard')),
                ],
                onChanged: (v) {
                  setState(() => _filtreEnRegle = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SSMQuickActionButton(
              icone: Icons.person_add_alt_1,
              label: 'Ajouter un élève',
              variante: SSMActionVariante.primaire,
              onTap: _dialogCreerEleve,
            ),
            SSMQuickActionButton(
              icone: Icons.picture_as_pdf,
              label: 'PDF',
              variante: SSMActionVariante.gris,
              onTap: () => _exporter(pdf: true),
            ),
            SSMQuickActionButton(
              icone: Icons.table_chart,
              label: 'Excel',
              variante: SSMActionVariante.teal,
              onTap: () => _exporter(pdf: false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_chargementListe)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
          )
        else if (groupes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Aucun élève trouvé', style: GoogleFonts.inter(color: SSMPalette.texte3))),
          )
        else
          LayoutBuilder(builder: (context, contraintes) {
            return contraintes.maxWidth >= 760 ? _tableEleves(data) : _listeGroupee(groupes);
          }),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: currentPage > 1 ? () { _page = currentPage - 1; _chargerListe(); } : null,
              child: const Text('< Précédent'),
            ),
            const SizedBox(width: 8),
            Text('Page $currentPage sur $lastPage', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: currentPage < lastPage ? () { _page = currentPage + 1; _chargerListe(); } : null,
              child: const Text('Suivant >'),
            ),
          ],
        ),
      ],
    );
  }

  // Style aligné sur le composant .search de la topbar.
  Widget _barreRecherche() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: TextField(
        controller: _rechercheController,
        onSubmitted: (_) {
          _page = 1;
          _chargerListe();
        },
        style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
        decoration: InputDecoration(
          hintText: 'Rechercher (nom, matricule, téléphone parent)...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
          prefixIcon: const Icon(Icons.search, size: 18, color: SSMPalette.texte3),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, size: 18, color: SSMPalette.texte2),
            onPressed: () {
              _page = 1;
              _chargerListe();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdownFiltre<T>({
    required String label,
    required T? valeur,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valeur,
          hint: Text(label, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
          items: [
            DropdownMenuItem<T>(value: null, child: Text('Tous · $label')),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Vue mobile/étroite : cartes groupées par classe ──
  Widget _listeGroupee(Map<String, List<dynamic>> groupes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupes.entries.map((entry) => _sectionClasse(entry.key, entry.value)).toList(),
    );
  }

  Widget _sectionClasse(String classeNom, List eleves) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$classeNom (${eleves.length} élèves)',
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
              InkWell(
                onTap: () {
                  final classeId = (eleves.first as Map)['classe_actuelle']?['id'];
                  if (classeId != null) {
                    Navigator.pushNamed(context, '/directeur/classe/fiche', arguments: {'classeId': classeId as int});
                  }
                },
                child: Text('Voir classe →', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.teal)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...eleves.map((e) => _carteEleve(e as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _carteEleve(Map<String, dynamic> eleve) {
    final statut = eleve['statut'] as String? ?? 'actif';
    final couleur = _couleurStatutEleve(statut);
    final dette = (eleve['dette'] as num?)?.toDouble() ?? 0;
    final sexe = eleve['sexe'] as String? ?? 'M';

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': eleve['id'] as int}),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 3),
            ),
          ),
          child: Row(
            children: [
              SSMAvatar(nom: eleve['nom'] as String? ?? '?', photoUrl: eleve['photo_url'] as String?, sexe: sexe, rayon: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${eleve['nom']} ${eleve['prenom']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    Text('Matricule : ${eleve['matricule']}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte3)),
                    if (eleve['numero_appel'] != null)
                      Text('N° appel : ${eleve['numero_appel']}', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SSMPill.couleur(label: statut, couleur: couleur),
                        if (dette > 0) const SSMPill.retard(label: '💰 Dette'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vue desktop large : tableau ──
  Widget _tableEleves(List data) {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn(''),
        SSMDataColumn('Élève'),
        SSMDataColumn('Classe'),
        SSMDataColumn('Statut financier'),
        SSMDataColumn('Actions'),
      ],
      onLigneTap: (i) => Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': data[i]['id'] as int}),
      lignes: [
        for (final e in data) _ligneEleve(e as Map<String, dynamic>),
      ],
    );
  }

  List<Widget> _ligneEleve(Map<String, dynamic> eleve) {
    final statut = eleve['statut'] as String? ?? 'actif';
    final couleur = _couleurStatutEleve(statut);
    final dette = (eleve['dette'] as num?)?.toDouble() ?? 0;
    final sexe = eleve['sexe'] as String? ?? 'M';
    final classe = eleve['classe_actuelle'] as Map<String, dynamic>?;

    return [
      SSMAvatar(nom: eleve['nom'] as String? ?? '?', photoUrl: eleve['photo_url'] as String?, sexe: sexe, rayon: 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${eleve['nom']} ${eleve['prenom']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${eleve['matricule']}', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: SSMPalette.texte3)),
              const SizedBox(width: 6),
              SSMPill.couleur(label: statut, couleur: couleur),
            ],
          ),
        ],
      ),
      Text('${classe?['nom'] ?? 'Non affecté'}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      dette > 0 ? const SSMPill.retard(label: '💰 Dette') : const SSMPill.paye(label: 'En règle'),
      Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
    ];
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CRÉER UN ÉLÈVE (stepper 3 étapes)
  // ══════════════════════════════════════════════════════

  InputDecoration _decorationChamp(String label, {bool dense = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      isDense: dense,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
      ),
    );
  }

  void _dialogCreerEleve() {
    int etape = 0;
    File? photo;
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    String sexe = 'M';
    DateTime? dateNaissance;
    final lieuNaissanceController = TextEditingController();
    final nationaliteController = TextEditingController(text: 'Togolaise');

    int? classeId;
    int? anneeId = _anneeActive != null && _anneeActive!.isNotEmpty ? _anneeActive!['id'] as int : null;
    final numeroAppelController = TextEditingController();
    DateTime dateInscription = DateTime.now();
    String statut = 'actif';

    final parents = <Map<String, dynamic>>[
      {
        'lien_parente': 'pere',
        'nom': TextEditingController(),
        'prenom': TextEditingController(),
        'telephone_principal': TextEditingController(),
        'telephone_secondaire': TextEditingController(),
        'profession': TextEditingController(),
      },
    ];

    bool enCours = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> choisirPhoto() async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
            if (image != null) {
              setStateDialog(() => photo = File(image.path));
            }
          }

          Widget etape1() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: choisirPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: SSMPalette.texte3.withValues(alpha: 0.15),
                          backgroundImage: photo != null ? FileImage(photo!) : null,
                          child: photo == null ? Icon(Icons.person, size: 40, color: SSMPalette.texte3) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: SSMPalette.indigo, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Ajouter une photo', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: nomController, decoration: _decorationChamp('Nom *'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: prenomController, decoration: _decorationChamp('Prénom *'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sexe,
                        decoration: _decorationChamp('Sexe *'),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text('Masculin')),
                          DropdownMenuItem(value: 'F', child: Text('Féminin')),
                        ],
                        onChanged: (v) => setStateDialog(() => sexe = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SSMPalette.texte1,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime(2015), firstDate: DateTime(1995), lastDate: DateTime.now());
                          if (d != null) setStateDialog(() => dateNaissance = d);
                        },
                        child: Text(dateNaissance != null ? '${dateNaissance!.day}/${dateNaissance!.month}/${dateNaissance!.year}' : 'Naissance *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: lieuNaissanceController, decoration: _decorationChamp('Lieu de naissance')),
                const SizedBox(height: 12),
                TextField(controller: nationaliteController, decoration: _decorationChamp('Nationalité')),
              ],
            );
          }

          Widget etape2() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: classeId,
                  decoration: _decorationChamp('Classe *'),
                  items: _classes.cast<Map<String, dynamic>>().map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
                  onChanged: (v) => setStateDialog(() => classeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: anneeId,
                  decoration: _decorationChamp('Année académique *'),
                  items: _annees.cast<Map<String, dynamic>>().map((a) => DropdownMenuItem(value: a['id'] as int, child: Text(a['libelle'] as String))).toList(),
                  onChanged: (v) => setStateDialog(() => anneeId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: numeroAppelController,
                        keyboardType: TextInputType.number,
                        decoration: _decorationChamp("N° d'appel"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SSMPalette.texte1,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(context: context, initialDate: dateInscription, firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (d != null) setStateDialog(() => dateInscription = d);
                        },
                        child: Text('${dateInscription.day}/${dateInscription.month}/${dateInscription.year}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: statut,
                  decoration: _decorationChamp('Statut'),
                  items: _statutsEleve.map((s) => DropdownMenuItem(value: s['valeur'], child: Text(s['label']!))).toList(),
                  onChanged: (v) => setStateDialog(() => statut = v!),
                ),
              ],
            );
          }

          Widget carteParent(int index) {
            final p = parents[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(SSMRayons.grand),
                border: Border.all(color: SSMPalette.bordure),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: p['lien_parente'] as String,
                    decoration: _decorationChamp('Lien', dense: true),
                    items: const [
                      DropdownMenuItem(value: 'pere', child: Text('Père')),
                      DropdownMenuItem(value: 'mere', child: Text('Mère')),
                      DropdownMenuItem(value: 'tuteur', child: Text('Tuteur')),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (v) => setStateDialog(() => p['lien_parente'] = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: p['nom'] as TextEditingController, decoration: _decorationChamp('Nom *', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['prenom'] as TextEditingController, decoration: _decorationChamp('Prénom', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['telephone_principal'] as TextEditingController, decoration: _decorationChamp('Téléphone principal *', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['telephone_secondaire'] as TextEditingController, decoration: _decorationChamp('Téléphone secondaire', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['profession'] as TextEditingController, decoration: _decorationChamp('Profession', dense: true)),
                ],
              ),
            );
          }

          Widget etape3() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Parent / Tuteur', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                const SizedBox(height: 4),
                Text('Ces informations serviront aux notifications WhatsApp', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
                const SizedBox(height: 12),
                ...List.generate(parents.length, carteParent),
                if (parents.length < 2)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SSMPalette.indigo,
                      side: const BorderSide(color: SSMPalette.indigo),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                    ),
                    onPressed: () => setStateDialog(() => parents.add({
                          'lien_parente': 'mere',
                          'nom': TextEditingController(),
                          'prenom': TextEditingController(),
                          'telephone_principal': TextEditingController(),
                          'telephone_secondaire': TextEditingController(),
                          'profession': TextEditingController(),
                        })),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un 2ème parent'),
                  ),
              ],
            );
          }

          Future<void> inscrire() async {
            if (nomController.text.trim().isEmpty || prenomController.text.trim().isEmpty || dateNaissance == null || classeId == null || anneeId == null) {
              _afficherErreur('Veuillez compléter les champs obligatoires');
              return;
            }
            setStateDialog(() => enCours = true);
            try {
              final resultat = await EleveService.creer(
                nom: nomController.text.trim(),
                prenom: prenomController.text.trim(),
                sexe: sexe,
                dateNaissance: '${dateNaissance!.year.toString().padLeft(4, '0')}-${dateNaissance!.month.toString().padLeft(2, '0')}-${dateNaissance!.day.toString().padLeft(2, '0')}',
                lieuNaissance: lieuNaissanceController.text.trim().isEmpty ? null : lieuNaissanceController.text.trim(),
                nationalite: nationaliteController.text.trim().isEmpty ? null : nationaliteController.text.trim(),
                classeId: classeId!,
                anneeAcademiqueId: anneeId!,
                numeroAppel: int.tryParse(numeroAppelController.text.trim()),
                dateInscription: '${dateInscription.year.toString().padLeft(4, '0')}-${dateInscription.month.toString().padLeft(2, '0')}-${dateInscription.day.toString().padLeft(2, '0')}',
                photo: photo,
              );

              final eleveId = resultat['eleve']['id'] as int;
              final matricule = resultat['eleve']['matricule'] as String;

              final parentsAEnvoyer = parents
                  .where((p) => (p['nom'] as TextEditingController).text.trim().isNotEmpty)
                  .map((p) => {
                        'lien_parente': p['lien_parente'],
                        'nom': (p['nom'] as TextEditingController).text.trim(),
                        'prenom': (p['prenom'] as TextEditingController).text.trim(),
                        'telephone_principal': (p['telephone_principal'] as TextEditingController).text.trim(),
                        'telephone_secondaire': (p['telephone_secondaire'] as TextEditingController).text.trim(),
                        'profession': (p['profession'] as TextEditingController).text.trim(),
                      })
                  .toList();

              if (parentsAEnvoyer.isNotEmpty) {
                await EleveService.gererParents(eleveId, parentsAEnvoyer);
              }

              if (!context.mounted) return;
              Navigator.pop(context);
              _dialogSucces(eleveId, matricule, '${nomController.text.trim()} ${prenomController.text.trim()}', classeId!);
              _chargerTout();
            } catch (e) {
              setStateDialog(() => enCours = false);
              _afficherErreur(e.toString().replaceAll('Exception: ', ''));
            }
          }

          final contenu = [etape1(), etape2(), etape3()][etape];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inscrire un élève', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenu)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (etape > 0)
                          Expanded(
                            child: TextButton(
                              onPressed: enCours ? null : () => setStateDialog(() => etape--),
                              child: Text('← Retour', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                            ),
                          )
                        else
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SSMPalette.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: enCours
                                ? null
                                : etape < 2
                                    ? () => setStateDialog(() => etape++)
                                    : inscrire,
                            child: enCours
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(etape < 2 ? 'Suivant →' : "Inscrire l'élève"),
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

  void _dialogSucces(int eleveId, String matricule, String nomComplet, int classeId) {
    final classe = _classes.cast<Map<String, dynamic>>().firstWhere((c) => c['id'] == classeId, orElse: () => {});

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: SSMPalette.teal, size: 56),
              const SizedBox(height: 12),
              Text('Élève inscrit avec succès !', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
              const SizedBox(height: 8),
              Text('Matricule : $matricule', style: GoogleFonts.jetBrainsMono(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  border: Border.all(color: SSMPalette.bordure),
                ),
                child: Column(
                  children: [
                    Text(nomComplet, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    Text(classe['nom']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SSMPalette.indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': eleveId});
                  },
                  child: const Text('Voir la fiche'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _dialogCreerEleve();
                  },
                  child: Text('Inscrire un autre', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteFiltre {
  final String label;
  final String valeur;
  final IconData icone;
  final Color couleur;
  final String type;
  final String titre;

  const _CarteFiltre(this.label, this.valeur, this.icone, this.couleur, this.type, this.titre);
}
