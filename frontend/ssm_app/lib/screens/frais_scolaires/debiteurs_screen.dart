import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/dashboard_frais_model.dart';
import '../../services/dashboard_frais_service.dart';
import '../../services/classe_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/whatsapp_rappel_helper.dart';

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$buffer FCFA';
}

Color _couleurRetard(int jours) {
  if (jours > 30) return SSMPalette.rouge;
  if (jours > 0) return SSMPalette.ambre;
  return SSMPalette.texte3;
}

class DebiteursScreen extends StatefulWidget {
  const DebiteursScreen({super.key});

  @override
  State<DebiteursScreen> createState() => _DebiteursScreenState();
}

class _DebiteursScreenState extends State<DebiteursScreen> {
  List<dynamic> _classes = [];
  List<EleveDebiteur> _debiteurs = [];
  bool _chargement = true;
  bool _exportEnCours = false;
  String? _erreur;

  int? _filtreClasseId;
  double _joursRetardMin = 0;
  bool _aucunPaiementUniquement = false;
  String _tri = 'par_montant'; // par_classe | par_montant | par_anciennete

  @override
  void initState() {
    super.initState();
    _chargerClasses();
    _charger();
  }

  Future<void> _chargerClasses() async {
    try {
      final classes = await ClasseService.listerClasses();
      setState(() => _classes = classes);
    } catch (_) {
      // Liste de référence non bloquante pour l'affichage.
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final debiteurs = await DashboardFraisService.getDebiteurs(
        classeId: _filtreClasseId,
        joursRetardMin: _joursRetardMin > 0 ? _joursRetardMin.round() : null,
        aucunPaiement: _aucunPaiementUniquement ? true : null,
        tri: _tri,
      );
      setState(() {
        _debiteurs = debiteurs;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  double get _totalRestant => _debiteurs.fold(0.0, (s, d) => s + d.montantRestant);

  Future<void> _envoyerRappel(EleveDebiteur debiteur) async {
    final ouvert = await ouvrirRappelWhatsApp(debiteur);
    if (!ouvert && mounted) {
      _afficherErreur('Aucun numéro de téléphone parent enregistré pour cet élève.');
    }
  }

  void _voirFicheEleve(EleveDebiteur debiteur) {
    Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': debiteur.eleveId});
  }

  Future<void> _exporter(String type) async {
    setState(() => _exportEnCours = true);
    try {
      final octets = type == 'excel'
          ? await DashboardFraisService.exportDebiteursExcel(classeId: _filtreClasseId)
          : await DashboardFraisService.exportDebiteursPdf(classeId: _filtreClasseId);
      final dossier = await getTemporaryDirectory();
      final extension = type == 'excel' ? 'xlsx' : 'pdf';
      final fichier = File('${dossier.path}/debiteurs.$extension');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Élèves débiteurs', onRetour: () => Navigator.pop(context)),
            _barreActions(),
            _barreFiltres(),
            _compteur(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: _debiteurs.isEmpty
                              ? ListView(
                                  padding: const EdgeInsets.all(40),
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 56, color: SSMPalette.teal),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Text(
                                        'Aucun élève débiteur pour ce filtre',
                                        style: GoogleFonts.inter(color: SSMPalette.texte2),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  child: LayoutBuilder(builder: (context, contraintes) {
                                    return contraintes.maxWidth >= 760 ? _tableDebiteurs() : _listeCartes();
                                  }),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BARRE D'ACTIONS
  // ══════════════════════════════════════════════════════

  Widget _barreActions() {
    return Container(
      color: SSMPalette.blanc,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _exportEnCours
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.rouge)),
            )
          : Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('excel'),
                    icon: const Icon(Icons.table_chart, size: 18, color: SSMPalette.teal),
                    label: Text('Exporter Excel', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('pdf'),
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: SSMPalette.rouge),
                    label: Text('Exporter PDF', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('pdf'),
                    icon: const Icon(Icons.print_outlined, size: 18, color: SSMPalette.indigo),
                    label: Text('Imprimer', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  ),
                ),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FILTRES — style aligné sur le composant .search de la topbar
  // ══════════════════════════════════════════════════════

  Widget _barreFiltres() {
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown<int?>(
                  valeur: _filtreClasseId,
                  hint: 'Toutes les classes',
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Toutes les classes')),
                    ..._classes.map(
                      (c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['nom'] as String)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _filtreClasseId = v);
                    _charger();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Uniquement sans paiement', style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte2)),
                  Switch(
                    value: _aucunPaiementUniquement,
                    activeThumbColor: SSMPalette.rouge,
                    onChanged: (v) {
                      setState(() => _aucunPaiementUniquement = v);
                      _charger();
                    },
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text('Retard min. : ${_joursRetardMin.round()} j', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
              Expanded(
                child: Slider(
                  value: _joursRetardMin,
                  min: 0,
                  max: 90,
                  divisions: 18,
                  activeColor: SSMPalette.rouge,
                  label: '${_joursRetardMin.round()} jours',
                  onChanged: (v) => setState(() => _joursRetardMin = v),
                  onChangeEnd: (_) => _charger(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: _boutonTri('Par classe', 'par_classe')),
              const SizedBox(width: 6),
              Expanded(child: _boutonTri('Par montant', 'par_montant')),
              const SizedBox(width: 6),
              Expanded(child: _boutonTri('Par ancienneté', 'par_anciennete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boutonTri(String label, String valeur) {
    final actif = _tri == valeur;
    return GestureDetector(
      onTap: () {
        setState(() => _tri = valeur);
        _charger();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.indigo : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(SSMRayons.pilule),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: actif ? Colors.white : SSMPalette.texte2),
        ),
      ),
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
  // COMPTEUR
  // ══════════════════════════════════════════════════════

  Widget _compteur() {
    return Container(
      width: double.infinity,
      color: SSMPalette.rougeClair,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Text(
        '${_debiteurs.length} élève(s) débiteur(s) — ${_formatMontant(_totalRestant)} restant',
        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.rouge),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLEAU (desktop large)
  // ══════════════════════════════════════════════════════

  Widget _tableDebiteurs() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Élève'),
        SSMDataColumn('Classe'),
        SSMDataColumn('Montant restant'),
        SSMDataColumn('Retard'),
        SSMDataColumn('Téléphone'),
        SSMDataColumn('Actions'),
      ],
      lignes: [for (final d in _debiteurs) _ligneDebiteur(d)],
    );
  }

  List<Widget> _ligneDebiteur(EleveDebiteur debiteur) {
    final aTelephone = debiteur.telephoneParent != null && debiteur.telephoneParent!.isNotEmpty;
    return [
      Text(debiteur.nomComplet, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
      Text(debiteur.classe, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      Text(_formatMontant(debiteur.montantRestant), style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
      SSMPill.couleur(label: '${debiteur.joursRetard} j', couleur: _couleurRetard(debiteur.joursRetard)),
      Text(aTelephone ? debiteur.telephoneParent! : '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 18, color: SSMPalette.teal),
            tooltip: 'Rappel WhatsApp',
            onPressed: aTelephone ? () => _envoyerRappel(debiteur) : null,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 18, color: SSMPalette.indigo),
            tooltip: 'Fiche élève',
            onPressed: () => _voirFicheEleve(debiteur),
          ),
        ],
      ),
    ];
  }

  // ══════════════════════════════════════════════════════
  // CARTES (mobile / tablette étroite)
  // ══════════════════════════════════════════════════════

  Widget _listeCartes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final d in _debiteurs) _carteDebiteur(d)],
    );
  }

  Widget _carteDebiteur(EleveDebiteur debiteur) {
    final aTelephone = debiteur.telephoneParent != null && debiteur.telephoneParent!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border(
          top: BorderSide(color: SSMPalette.bordure),
          right: BorderSide(color: SSMPalette.bordure),
          bottom: BorderSide(color: SSMPalette.bordure),
          left: const BorderSide(color: SSMPalette.rouge, width: 3),
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
                    Text(debiteur.nomComplet, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.class_outlined, size: 12, color: SSMPalette.texte3),
                        const SizedBox(width: 4),
                        Text(debiteur.classe, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMontant(debiteur.montantRestant),
                    style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.rouge),
                  ),
                  const SizedBox(height: 4),
                  SSMPill.couleur(label: '${debiteur.joursRetard} j de retard', couleur: _couleurRetard(debiteur.joursRetard)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 13, color: SSMPalette.texte3),
              const SizedBox(width: 4),
              Text(
                aTelephone ? debiteur.telephoneParent! : 'Aucun numéro enregistré',
                style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: aTelephone ? () => _envoyerRappel(debiteur) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SSMPalette.teal,
                    side: const BorderSide(color: SSMPalette.teal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text('Rappel WhatsApp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _voirFicheEleve(debiteur),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SSMPalette.indigo,
                    side: const BorderSide(color: SSMPalette.indigo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: Text('Fiche élève', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
