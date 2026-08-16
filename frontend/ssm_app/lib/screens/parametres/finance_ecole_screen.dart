import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

// ══════════════════════════════════════════════════════════
// Section Finance : devise, tranches par défaut, pénalités de retard,
// paiement partiel, seuil de jours avant "non en règle".
// GET/PUT /parametres/frais (ParametreFraisController).
// ══════════════════════════════════════════════════════════
class FinanceEcoleScreen extends StatefulWidget {
  const FinanceEcoleScreen({super.key});

  @override
  State<FinanceEcoleScreen> createState() => _FinanceEcoleScreenState();
}

class _FinanceEcoleScreenState extends State<FinanceEcoleScreen> {
  final _deviseController = TextEditingController();
  final _tranchesController = TextEditingController();
  final _montantPenaliteController = TextEditingController();
  final _seuilJoursController = TextEditingController();

  Utilisateur? _utilisateur;
  bool _penalitesActives = false;
  bool _paiementPartielAutorise = true;

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
    _deviseController.dispose();
    _tranchesController.dispose();
    _montantPenaliteController.dispose();
    _seuilJoursController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final parametre = await ParametreEcoleService.getParametreFrais();
      if (!mounted) return;
      _remplirDepuis(parametre);
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

  void _remplirDepuis(ParametreFrais p) {
    _deviseController.text = p.devise;
    _tranchesController.text = p.nombreTranchesDefaut.toString();
    _montantPenaliteController.text = p.montantPenaliteRetard != null
        ? (p.montantPenaliteRetard! == p.montantPenaliteRetard!.roundToDouble()
            ? p.montantPenaliteRetard!.toInt().toString()
            : p.montantPenaliteRetard!.toString())
        : '';
    _seuilJoursController.text = p.seuilJoursRetard.toString();
    _penalitesActives = p.penalitesActives;
    _paiementPartielAutorise = p.paiementPartielAutorise;
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);

    final tranches = int.tryParse(_tranchesController.text.trim());
    if (tranches == null || tranches < 1 || tranches > 12) {
      setState(() => _erreur = 'Le nombre de tranches doit être un nombre entre 1 et 12.');
      return;
    }

    final seuilJours = int.tryParse(_seuilJoursController.text.trim());
    if (seuilJours == null || seuilJours < 0) {
      setState(() => _erreur = 'Le seuil de jours doit être un nombre positif ou nul.');
      return;
    }

    double? montantPenalite;
    if (_penalitesActives) {
      montantPenalite = double.tryParse(_montantPenaliteController.text.trim().replaceAll(',', '.'));
      if (montantPenalite == null || montantPenalite <= 0) {
        setState(() => _erreur = 'Le montant de la pénalité est requis pour activer les pénalités.');
        return;
      }
    } else {
      montantPenalite = double.tryParse(_montantPenaliteController.text.trim().replaceAll(',', '.'));
    }

    setState(() => _enregistrementEnCours = true);

    final parametre = ParametreFrais(
      devise: _deviseController.text.trim().isEmpty ? 'FCFA' : _deviseController.text.trim(),
      nombreTranchesDefaut: tranches,
      penalitesActives: _penalitesActives,
      montantPenaliteRetard: montantPenalite,
      paiementPartielAutorise: _paiementPartielAutorise,
      seuilJoursRetard: seuilJours,
    );

    try {
      final misAJour = await ParametreEcoleService.updateParametreFrais(parametre);
      if (!mounted) return;
      _remplirDepuis(misAJour);
      setState(() => _enregistrementEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres financiers enregistrés avec succès'), backgroundColor: SSMPalette.teal),
      );
    } catch (e) {
      setState(() {
        _enregistrementEnCours = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Finance', sousTitre: 'Frais scolaires et pénalités', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        if (_lectureSeule) ...[
                          const SSMAlertItem(
                            type: SSMAlerteType.avertissement,
                            icone: Icons.lock_outline,
                            titre: 'Lecture seule',
                            sousTitre: 'Seul le directeur peut modifier les paramètres financiers.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_erreur != null) ...[
                          SSMAlertItem(type: SSMAlerteType.danger, icone: Icons.warning_amber, titre: 'Erreur', sousTitre: _erreur!),
                          const SizedBox(height: 16),
                        ],
                        _titreSection('Général'),
                        Row(
                          children: [
                            Expanded(child: _champTexte(controller: _deviseController, label: 'Devise', icone: Icons.attach_money)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _champTexte(
                                controller: _tranchesController,
                                label: 'Tranches par défaut',
                                icone: Icons.splitscreen_outlined,
                                clavierNumerique: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _titreSection('Pénalités de retard'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: SSMPalette.indigo,
                          value: _penalitesActives,
                          title: Text('Activer les pénalités de retard', style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1)),
                          onChanged: _lectureSeule ? null : (v) => setState(() => _penalitesActives = v),
                        ),
                        if (_penalitesActives) ...[
                          const SizedBox(height: 8),
                          _champTexte(
                            controller: _montantPenaliteController,
                            label: 'Montant de la pénalité *',
                            icone: Icons.money_off_outlined,
                            clavierNumerique: true,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _titreSection('Paiement'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: SSMPalette.indigo,
                          value: _paiementPartielAutorise,
                          title: Text('Autoriser le paiement partiel', style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1)),
                          subtitle: Text(
                            _paiementPartielAutorise
                                ? 'Un élève peut régler moins que le montant dû en une fois.'
                                : 'Le montant total doit être réglé en une seule fois.',
                            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                          ),
                          onChanged: _lectureSeule ? null : (v) => setState(() => _paiementPartielAutorise = v),
                        ),
                        const SizedBox(height: 16),
                        _titreSection('Élèves non en règle'),
                        _champTexte(
                          controller: _seuilJoursController,
                          label: 'Seuil de jours de retard toléré',
                          icone: Icons.event_busy_outlined,
                          clavierNumerique: true,
                        ),
                        const SizedBox(height: 8),
                        const SSMAlertItem(
                          type: SSMAlerteType.succes,
                          icone: Icons.info_outline,
                          titre: 'Comment ce seuil est utilisé',
                          sousTitre:
                              "Un élève est considéré non en règle si son reste à payer est supérieur à 0 après ce délai "
                              "passé la date limite du frais (0 = non en règle dès le premier jour de retard).",
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

  Widget _champTexte({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    bool clavierNumerique = false,
  }) {
    return TextField(
      controller: controller,
      enabled: !_lectureSeule,
      keyboardType: clavierNumerique ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: clavierNumerique
          ? GoogleFonts.jetBrainsMono(fontSize: 14, color: SSMPalette.texte1)
          : GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
      decoration: _decorationChamp(label, icone: icone),
    );
  }
}
