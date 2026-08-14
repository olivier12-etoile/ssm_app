import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

const Map<String, String> _typesEtablissement = {
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'complexe': 'Complexe scolaire',
};

// ══════════════════════════════════════════════════════════
// Section Établissement > Informations générales.
// GET/PUT /parametres/etablissement (InformationsEtablissementController).
// ══════════════════════════════════════════════════════════
class InformationsEtablissementScreen extends StatefulWidget {
  const InformationsEtablissementScreen({super.key});

  @override
  State<InformationsEtablissementScreen> createState() => _InformationsEtablissementScreenState();
}

class _InformationsEtablissementScreenState extends State<InformationsEtablissementScreen> {
  final _nomController = TextEditingController();
  final _nomCourtController = TextEditingController();
  final _sigleController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();
  final _regionController = TextEditingController();
  final _paysController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _siteWebController = TextEditingController();
  final _deviseController = TextEditingController();
  final _anneeCreationController = TextEditingController();

  String? _type;
  String? _codeEcole;

  Utilisateur? _utilisateur;
  bool _chargement = true;
  bool _enregistrementEnCours = false;
  String? _erreur;

  bool get _lectureSeule => _utilisateur?.estDirecteur != true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _nomCourtController.dispose();
    _sigleController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _regionController.dispose();
    _paysController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _siteWebController.dispose();
    _deviseController.dispose();
    _anneeCreationController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final infos = await ParametreEcoleService.getInformationsEtablissement();
      if (!mounted) return;
      _remplirDepuis(infos);
      setState(() {
        _utilisateur = utilisateur;
        _codeEcole = infos.codeEcole;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _remplirDepuis(InformationsEtablissement infos) {
    _nomController.text = infos.nomOfficiel ?? '';
    _nomCourtController.text = infos.nomCourt ?? '';
    _sigleController.text = infos.sigle ?? '';
    _adresseController.text = infos.adresse ?? '';
    _villeController.text = infos.ville ?? '';
    _regionController.text = infos.region ?? '';
    _paysController.text = infos.pays ?? '';
    _telephoneController.text = infos.telephone ?? '';
    _emailController.text = infos.email ?? '';
    _siteWebController.text = infos.siteWeb ?? '';
    _deviseController.text = infos.devise ?? 'FCFA';
    _anneeCreationController.text = infos.anneeCreation?.toString() ?? '';
    _type = infos.type;
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);

    if (_nomController.text.trim().isEmpty) {
      setState(() => _erreur = "Le nom officiel de l'établissement est obligatoire.");
      return;
    }

    setState(() => _enregistrementEnCours = true);

    final infos = InformationsEtablissement(
      nomOfficiel: _nomController.text.trim(),
      nomCourt: _texteOuNull(_nomCourtController),
      sigle: _texteOuNull(_sigleController),
      type: _type,
      adresse: _texteOuNull(_adresseController),
      ville: _texteOuNull(_villeController),
      region: _texteOuNull(_regionController),
      pays: _texteOuNull(_paysController),
      telephone: _texteOuNull(_telephoneController),
      email: _texteOuNull(_emailController),
      siteWeb: _texteOuNull(_siteWebController),
      devise: _texteOuNull(_deviseController),
      anneeCreation: int.tryParse(_anneeCreationController.text.trim()),
    );

    try {
      final misAJour = await ParametreEcoleService.updateInformationsEtablissement(infos);
      if (!mounted) return;
      _remplirDepuis(misAJour);
      setState(() => _enregistrementEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations de l\'établissement enregistrées avec succès'), backgroundColor: _vert),
      );
    } catch (e) {
      setState(() {
        _enregistrementEnCours = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String? _texteOuNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Établissement', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _carteApercu(),
                const SizedBox(height: 20),
                if (_lectureSeule) _bandeauLectureSeule(),
                if (_lectureSeule) const SizedBox(height: 16),
                if (_erreur != null) _bandeauErreur(_erreur!),
                _titreSection('Identité'),
                _champTexte(controller: _nomController, label: 'Nom officiel *', icone: Icons.school),
                const SizedBox(height: 12),
                _champTexte(controller: _nomCourtController, label: 'Nom court', icone: Icons.short_text),
                const SizedBox(height: 12),
                _champTexte(controller: _sigleController, label: 'Sigle', icone: Icons.text_fields),
                const SizedBox(height: 12),
                _champDropdown(),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2, color: _gris),
                  title: const Text('Code école'),
                  subtitle: Text(_codeEcole ?? '—', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: _texteFonce)),
                  trailing: const SSMBadgeNonModifiable(),
                ),
                const SizedBox(height: 16),
                _titreSection('Localisation'),
                _champTexte(controller: _adresseController, label: 'Adresse', icone: Icons.place_outlined),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _champTexte(controller: _villeController, label: 'Ville', icone: Icons.location_city_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _champTexte(controller: _regionController, label: 'Région', icone: Icons.map_outlined)),
                  ],
                ),
                const SizedBox(height: 12),
                _champTexte(controller: _paysController, label: 'Pays', icone: Icons.public_outlined),
                const SizedBox(height: 16),
                _titreSection('Contacts'),
                _champTexte(controller: _telephoneController, label: 'Téléphone', icone: Icons.phone_outlined),
                const SizedBox(height: 12),
                _champTexte(controller: _emailController, label: 'Email', icone: Icons.email_outlined),
                const SizedBox(height: 12),
                _champTexte(controller: _siteWebController, label: 'Site web', icone: Icons.language_outlined),
                const SizedBox(height: 16),
                _titreSection('Autres informations'),
                Row(
                  children: [
                    Expanded(child: _champTexte(controller: _deviseController, label: 'Devise', icone: Icons.attach_money)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _champTexte(
                        controller: _anneeCreationController,
                        label: 'Année de création',
                        icone: Icons.event_outlined,
                        clavierNumerique: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_lectureSeule)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _enregistrementEnCours ? null : _enregistrer,
                      child: _enregistrementEnCours
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Enregistrer'),
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Aperçu "carte de visite" ──────────────────────────────

  Widget _carteApercu() {
    return AnimatedBuilder(
      animation: Listenable.merge([_nomController, _sigleController, _villeController, _paysController, _telephoneController, _emailController]),
      builder: (context, _) {
        final nom = _nomController.text.trim().isEmpty ? "Nom de l'établissement" : _nomController.text.trim();
        final localisation = [
          _villeController.text.trim(),
          _paysController.text.trim(),
        ].where((s) => s.isNotEmpty).join(', ');

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_indigo.withValues(alpha: 0.90), _teal.withValues(alpha: 0.85)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: _indigo.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: const Icon(Icons.apartment, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom,
                          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_sigleController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(_sigleController.text.trim(), style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                        ],
                        if (localisation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.place, size: 13, color: Colors.white70),
                              const SizedBox(width: 4),
                              Expanded(child: Text(localisation, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                        if (_telephoneController.text.trim().isNotEmpty || _emailController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [_telephoneController.text.trim(), _emailController.text.trim()].where((s) => s.isNotEmpty).join(' · '),
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bandeauLectureSeule() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ambre.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ambre.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: _ambre, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Lecture seule — seul le directeur peut modifier ces informations.', style: GoogleFonts.inter(fontSize: 12, color: _texte))),
        ],
      ),
    );
  }

  Widget _bandeauErreur(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _rouge.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: _rouge, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 13, color: _rouge))),
        ],
      ),
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
    );
  }

  Widget _champDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _type,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Type d'établissement",
        prefixIcon: Icon(Icons.category_outlined),
        border: OutlineInputBorder(),
      ),
      items: _typesEtablissement.entries
          .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: _lectureSeule ? null : (v) => setState(() => _type = v),
    );
  }

  Widget _champTexte({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    bool clavierNumerique = false,
  }) {
    return TextField(
      controller: controller,
      enabled: !_lectureSeule,
      keyboardType: clavierNumerique ? TextInputType.number : TextInputType.text,
      style: clavierNumerique ? GoogleFonts.jetBrainsMono(fontSize: 14) : GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone, size: 22),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class SSMBadgeNonModifiable extends StatelessWidget {
  const SSMBadgeNonModifiable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _gris.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text('Non modifiable', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _gris)),
    );
  }
}
