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

// ══════════════════════════════════════════════════════════
// Section Direction : informations du directeur (nom, fonction, contacts).
// GET/PUT /parametres/direction (DirectionController).
// ══════════════════════════════════════════════════════════
class DirectionScreen extends StatefulWidget {
  const DirectionScreen({super.key});

  @override
  State<DirectionScreen> createState() => _DirectionScreenState();
}

class _DirectionScreenState extends State<DirectionScreen> {
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _fonctionController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();

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
    _prenomController.dispose();
    _fonctionController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final infos = await ParametreEcoleService.getDirection();
      if (!mounted) return;
      _remplirDepuis(infos);
      setState(() {
        _utilisateur = utilisateur;
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

  void _remplirDepuis(InfosDirecteur infos) {
    _nomController.text = infos.nom ?? '';
    _prenomController.text = infos.prenom ?? '';
    _fonctionController.text = infos.fonction ?? 'Directeur';
    _telephoneController.text = infos.telephone ?? '';
    _emailController.text = infos.email ?? '';
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);
    setState(() => _enregistrementEnCours = true);

    final infos = InfosDirecteur(
      nom: _texteOuNull(_nomController),
      prenom: _texteOuNull(_prenomController),
      fonction: _texteOuNull(_fonctionController),
      telephone: _texteOuNull(_telephoneController),
      email: _texteOuNull(_emailController),
    );

    try {
      final misAJour = await ParametreEcoleService.updateDirection(infos);
      if (!mounted) return;
      _remplirDepuis(misAJour);
      setState(() => _enregistrementEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations de la direction enregistrées avec succès'), backgroundColor: SSMPalette.teal),
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
            SSMSousEnTete(titre: 'Direction', sousTitre: 'Informations du directeur', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _carteAvatar(),
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
                        _champTexte(controller: _nomController, label: 'Nom', icone: Icons.badge_outlined),
                        const SizedBox(height: 12),
                        _champTexte(controller: _prenomController, label: 'Prénom', icone: Icons.person_outline),
                        const SizedBox(height: 12),
                        _champTexte(controller: _fonctionController, label: 'Fonction', icone: Icons.work_outline),
                        const SizedBox(height: 12),
                        _champTexte(controller: _telephoneController, label: 'Téléphone', icone: Icons.phone_outlined),
                        const SizedBox(height: 12),
                        _champTexte(controller: _emailController, label: 'Email', icone: Icons.email_outlined),
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

  Widget _carteAvatar() {
    return AnimatedBuilder(
      animation: Listenable.merge([_nomController, _prenomController, _fonctionController]),
      builder: (context, _) {
        final nomComplet = [_prenomController.text.trim(), _nomController.text.trim()].where((s) => s.isNotEmpty).join(' ');
        return SSMPanel(
          titre: 'Aperçu',
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: SSMPalette.indigoClair, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: SSMPalette.indigo, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomComplet.isEmpty ? 'Nom du directeur' : nomComplet,
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fonctionController.text.trim().isEmpty ? 'Directeur' : _fonctionController.text.trim(),
                      style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _champTexte({required TextEditingController controller, required String label, required IconData icone}) {
    return TextField(
      controller: controller,
      enabled: !_lectureSeule,
      style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
      decoration: _decorationChamp(label, icone: icone),
    );
  }
}
