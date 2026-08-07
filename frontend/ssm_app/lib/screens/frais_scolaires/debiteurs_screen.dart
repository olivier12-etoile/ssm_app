import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/dashboard_frais_model.dart';
import '../../services/dashboard_frais_service.dart';
import '../../services/classe_service.dart';
import '../../widgets/whatsapp_rappel_helper.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

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
      SnackBar(content: Text(message), backgroundColor: _rouge),
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            _barreActions(),
            _barreFiltres(),
            _compteur(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          child: _debiteurs.isEmpty
                              ? ListView(
                                  padding: const EdgeInsets.all(40),
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 56, color: _vert),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Text(
                                        'Aucun élève débiteur pour ce filtre',
                                        style: GoogleFonts.inter(color: _texte),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _debiteurs.length,
                                  itemBuilder: (context, index) => _carteDebiteur(_debiteurs[index]),
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
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_rouge, Color(0xFFEA580C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Élèves débiteurs',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BARRE D'ACTIONS
  // ══════════════════════════════════════════════════════

  Widget _barreActions() {
    return Container(
      color: const Color(0xFFFFF1F2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _exportEnCours
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _rouge)),
            )
          : Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('excel'),
                    icon: const Icon(Icons.table_chart, size: 18, color: _vert),
                    label: Text('Exporter Excel', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('pdf'),
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: _rouge),
                    label: Text('Exporter PDF', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('pdf'),
                    icon: const Icon(Icons.print_outlined, size: 18, color: _indigo),
                    label: Text('Imprimer', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  ),
                ),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FILTRES
  // ══════════════════════════════════════════════════════

  Widget _barreFiltres() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdownGlass<int?>(
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
                  Text('Uniquement sans paiement', style: GoogleFonts.inter(fontSize: 10, color: _texte)),
                  Switch(
                    value: _aucunPaiementUniquement,
                    activeThumbColor: _rouge,
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
              Text('Retard min. : ${_joursRetardMin.round()} j', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
              Expanded(
                child: Slider(
                  value: _joursRetardMin,
                  min: 0,
                  max: 90,
                  divisions: 18,
                  activeColor: _rouge,
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
          color: actif ? _indigo : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: actif ? Colors.white : _texte),
        ),
      ),
    );
  }

  Widget _dropdownGlass<T>({
    required T valeur,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(50),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valeur,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16),
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
          style: GoogleFonts.inter(fontSize: 12, color: _texte),
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
      color: _rouge.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Text(
        '${_debiteurs.length} élève(s) débiteur(s) — ${_formatMontant(_totalRestant)} restant',
        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _rouge),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTE DÉBITEUR
  // ══════════════════════════════════════════════════════

  Widget _carteDebiteur(EleveDebiteur debiteur) {
    final couleurRetard = debiteur.joursRetard > 30 ? _rouge : (debiteur.joursRetard > 0 ? _ambre : _gris);
    final aTelephone = debiteur.telephoneParent != null && debiteur.telephoneParent!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: _rouge, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
            ],
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
                        Text(
                          debiteur.nomComplet,
                          style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.class_outlined, size: 12, color: _gris),
                            const SizedBox(width: 4),
                            Text(debiteur.classe, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
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
                        style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: _rouge),
                      ),
                      const SizedBox(height: 4),
                      _badge('${debiteur.joursRetard} j de retard', couleurRetard),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 13, color: _gris),
                  const SizedBox(width: 4),
                  Text(
                    aTelephone ? debiteur.telephoneParent! : 'Aucun numéro enregistré',
                    style: GoogleFonts.inter(fontSize: 12, color: _texte),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: aTelephone ? () => _envoyerRappel(debiteur) : null,
                      style: OutlinedButton.styleFrom(foregroundColor: _vert),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text('Rappel WhatsApp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _voirFicheEleve(debiteur),
                      style: OutlinedButton.styleFrom(foregroundColor: _indigo),
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: Text('Fiche élève', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
    );
  }
}
