import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

const String _clePrefModeSombre = 'apparence_mode_sombre';
const String _clePrefTailleTexte = 'apparence_taille_texte'; // 0=petit, 1=normal, 2=grand

const List<String> _libellesTailles = ['Petit', 'Normal', 'Grand'];
const List<double> _echellesTailles = [0.85, 1.0, 1.15];

/// ══════════════════════════════════════════════════════════
/// Section Apparence : préférences d'affichage PERSONNELLES de
/// l'utilisateur connecté (mode sombre, langue, taille du texte).
///
/// IMPORTANT — distinct de l'Identité visuelle (module Établissement) :
/// ces réglages ne concernent QUE l'appareil/le compte de l'utilisateur
/// qui les modifie, jamais l'école entière ni les autres utilisateurs. Ils
/// sont donc stockés localement via SharedPreferences (aucun appel API —
/// aucun endpoint backend n'existe pour ça, à dessein).
///
/// État actuel : le mode sombre et la taille du texte sont PERSISTÉS ici,
/// mais leur application effective à toute l'application nécessite un
/// contrôleur de thème global qui n'existe pas encore dans main.dart —
/// c'est un chantier séparé. La taille du texte bénéficie néanmoins d'un
/// aperçu local immédiat sur cet écran.
/// ══════════════════════════════════════════════════════════
class ApparenceScreen extends StatefulWidget {
  const ApparenceScreen({super.key});

  @override
  State<ApparenceScreen> createState() => _ApparenceScreenState();
}

class _ApparenceScreenState extends State<ApparenceScreen> {
  bool _modeSombre = false;
  int _indexTaille = 1;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _modeSombre = prefs.getBool(_clePrefModeSombre) ?? false;
      _indexTaille = prefs.getInt(_clePrefTailleTexte) ?? 1;
      _chargement = false;
    });
  }

  Future<void> _changerModeSombre(bool valeur) async {
    setState(() => _modeSombre = valeur);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clePrefModeSombre, valeur);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(valeur ? 'Mode sombre activé — redémarrez l\'application pour l\'appliquer partout.' : 'Mode clair activé.')),
    );
  }

  Future<void> _changerTailleTexte(int index) async {
    setState(() => _indexTaille = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clePrefTailleTexte, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Apparence', sousTitre: 'Préférences personnelles', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        const SSMAlertItem(
                          type: SSMAlerteType.succes,
                          icone: Icons.person_outline,
                          titre: 'Réglages personnels',
                          sousTitre: 'Ces réglages sont personnels : ils ne concernent que votre compte, pas l\'école.',
                        ),
                        const SizedBox(height: 20),
                        SSMPanel(
                          titre: 'Thème',
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: SSMPalette.indigo,
                            value: _modeSombre,
                            secondary: Icon(_modeSombre ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: SSMPalette.indigo),
                            title: Text('Mode sombre', style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1)),
                            subtitle: Text(_modeSombre ? 'Activé' : 'Désactivé', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                            onChanged: _changerModeSombre,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SSMPanel(
                          titre: 'Langue',
                          child: Row(
                            children: [
                              const Icon(Icons.language, color: SSMPalette.texte3),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Français', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                                    Text('D\'autres langues seront proposées prochainement.', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle, color: SSMPalette.teal, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SSMPanel(
                          titre: 'Taille du texte',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  _libellesTailles.length,
                                  (i) => Text(
                                    _libellesTailles[i],
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: i == _indexTaille ? SSMPalette.indigo : SSMPalette.texte3,
                                      fontWeight: i == _indexTaille ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                              Slider(
                                value: _indexTaille.toDouble(),
                                min: 0,
                                max: 2,
                                divisions: 2,
                                activeColor: SSMPalette.indigo,
                                label: _libellesTailles[_indexTaille],
                                onChanged: (v) => _changerTailleTexte(v.round()),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(SSMRayons.petit)),
                                child: Text(
                                  'Aperçu — Paramètres de l\'École SSM',
                                  style: GoogleFonts.inter(fontSize: 14 * _echellesTailles[_indexTaille], fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                                ),
                              ),
                            ],
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
}
