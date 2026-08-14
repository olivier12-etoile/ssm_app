import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

const String _clePrefModeSombre = 'apparence_mode_sombre';
const String _clePrefTailleTexte = 'apparence_taille_texte'; // 0=petit, 1=normal, 2=grand

const List<String> _libellesTailles = ['Petit', 'Normal', 'Grand'];
const List<double> _echellesTailles = [0.85, 1.0, 1.15];

/// ══════════════════════════════════════════════════════════
/// Section Apparence : préférences d'affichage PERSONNELLES de
/// l'utilisateur connecté (mode sombre, langue, taille du texte).
///
/// IMPORTANT — distinct de l'Identité visuelle (module Établissement,
/// Phase 5) : ces réglages ne concernent QUE l'appareil/le compte de
/// l'utilisateur qui les modifie, jamais l'école entière ni les autres
/// utilisateurs. Ils sont donc stockés localement via SharedPreferences
/// (aucun appel API — aucun endpoint backend n'existe pour ça, à dessein).
///
/// État actuel : le mode sombre et la taille du texte sont PERSISTÉS ici,
/// mais leur application effective à toute l'application nécessite un
/// contrôleur de thème global (ThemeMode/TextScaler) qui n'existe pas
/// encore dans main.dart (SSMTheme.themeClaire y est câblé en dur) — c'est
/// un chantier séparé. La taille du texte bénéficie néanmoins d'un aperçu
/// local immédiat sur cet écran.
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
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Apparence', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: _indigo, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ces réglages sont personnels : ils ne concernent que votre compte, pas l\'école.',
                          style: GoogleFonts.inter(fontSize: 12, color: _texte),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _titreSection('Thème'),
                _carteBlanche(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _indigo,
                    value: _modeSombre,
                    secondary: Icon(_modeSombre ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: _indigo),
                    title: const Text('Mode sombre'),
                    subtitle: Text(_modeSombre ? 'Activé' : 'Désactivé', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                    onChanged: _changerModeSombre,
                  ),
                ),
                const SizedBox(height: 20),
                _titreSection('Langue'),
                _carteBlanche(
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: _gris),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Français', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
                            Text('D\'autres langues seront proposées prochainement.', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle, color: _teal, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _titreSection('Taille du texte'),
                _carteBlanche(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          _libellesTailles.length,
                          (i) => Text(_libellesTailles[i], style: GoogleFonts.inter(fontSize: 11, color: i == _indexTaille ? _indigo : _gris, fontWeight: i == _indexTaille ? FontWeight.w700 : FontWeight.w400)),
                        ),
                      ),
                      Slider(
                        value: _indexTaille.toDouble(),
                        min: 0,
                        max: 2,
                        divisions: 2,
                        activeColor: _indigo,
                        label: _libellesTailles[_indexTaille],
                        onChanged: (v) => _changerTailleTexte(v.round()),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          'Aperçu — Paramètres de l\'École SSM',
                          style: GoogleFonts.inter(fontSize: 14 * _echellesTailles[_indexTaille], fontWeight: FontWeight.w600, color: _texteFonce),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
    );
  }

  Widget _carteBlanche({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}
