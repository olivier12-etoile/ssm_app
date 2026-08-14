import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

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
        const SnackBar(content: Text('Informations de la direction enregistrées avec succès'), backgroundColor: _vert),
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
        title: Text('Direction', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _carteAvatar(),
                const SizedBox(height: 20),
                if (_lectureSeule) ...[_bandeauLectureSeule(), const SizedBox(height: 16)],
                if (_erreur != null) _bandeauErreur(_erreur!),
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

  Widget _carteAvatar() {
    return AnimatedBuilder(
      animation: Listenable.merge([_nomController, _prenomController, _fonctionController]),
      builder: (context, _) {
        final nomComplet = [_prenomController.text.trim(), _nomController.text.trim()].where((s) => s.isNotEmpty).join(' ');
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: _indigo, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomComplet.isEmpty ? 'Nom du directeur' : nomComplet,
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fonctionController.text.trim().isEmpty ? 'Directeur' : _fonctionController.text.trim(),
                      style: GoogleFonts.inter(fontSize: 13, color: _texte),
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

  Widget _bandeauLectureSeule() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _ambre.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _ambre.withValues(alpha: 0.3))),
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

  Widget _champTexte({required TextEditingController controller, required String label, required IconData icone}) {
    return TextField(
      controller: controller,
      enabled: !_lectureSeule,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone, size: 22),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
