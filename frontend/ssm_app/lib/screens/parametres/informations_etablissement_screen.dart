import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

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
        const SnackBar(content: Text('Informations de l\'établissement enregistrées avec succès'), backgroundColor: SSMPalette.teal),
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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Établissement', sousTitre: 'Informations générales', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _carteApercu(),
                        const SizedBox(height: 16),
                        if (_lectureSeule) ...[
                          const SSMAlertItem(
                            type: SSMAlerteType.avertissement,
                            icone: Icons.lock_outline,
                            titre: 'Lecture seule',
                            sousTitre: 'Seul le directeur peut modifier ces informations.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_erreur != null) ...[
                          SSMAlertItem(type: SSMAlerteType.danger, icone: Icons.warning_amber, titre: 'Erreur', sousTitre: _erreur!),
                          const SizedBox(height: 16),
                        ],
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
                          leading: const Icon(Icons.qr_code_2, color: SSMPalette.texte3),
                          title: Text('Code école', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
                          subtitle: Text(_codeEcole ?? '—', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
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
                                backgroundColor: SSMPalette.indigo,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                              ),
                              onPressed: _enregistrementEnCours ? null : _enregistrer,
                              child: _enregistrementEnCours
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Enregistrer'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
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

        return SSMPanel(
          titre: 'Aperçu',
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: SSMPalette.indigoClair, shape: BoxShape.circle),
                child: const Icon(Icons.apartment, color: SSMPalette.indigo, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_sigleController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_sigleController.text.trim(), style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.texte2)),
                    ],
                    if (localisation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 13, color: SSMPalette.texte3),
                          const SizedBox(width: 4),
                          Expanded(child: Text(localisation, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                    if (_telephoneController.text.trim().isNotEmpty || _emailController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [_telephoneController.text.trim(), _emailController.text.trim()].where((s) => s.isNotEmpty).join(' · '),
                        style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4)),
    );
  }

  InputDecoration _decorationChamp(String label, {IconData? icone}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      prefixIcon: icone != null ? Icon(icone, size: 20, color: SSMPalette.texte3) : null,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5)),
    );
  }

  Widget _champDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _type,
      isExpanded: true,
      decoration: _decorationChamp("Type d'établissement", icone: Icons.category_outlined),
      items: _typesEtablissement.entries
          .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1))))
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
      style: clavierNumerique
          ? GoogleFonts.jetBrainsMono(fontSize: 14, color: SSMPalette.texte1)
          : GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
      decoration: _decorationChamp(label, icone: icone),
    );
  }
}

class SSMBadgeNonModifiable extends StatelessWidget {
  const SSMBadgeNonModifiable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: SSMPalette.texte3.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(SSMRayons.pilule)),
      child: Text('Non modifiable', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: SSMPalette.texte2)),
    );
  }
}
