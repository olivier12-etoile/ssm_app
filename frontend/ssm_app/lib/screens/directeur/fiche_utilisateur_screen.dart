import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/utilisateur_service.dart';
import '../../services/affectation_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import 'affectation_enseignant_screen.dart';

Color _couleurRole(String role) {
  switch (role) {
    case 'enseignant':
      return SSMPalette.indigo;
    case 'censeur':
      return SSMPalette.ambre;
    case 'secretaire':
      return SSMPalette.teal;
    case 'directeur':
      return SSMPalette.rouge;
    default:
      return SSMPalette.texte3;
  }
}

String _labelRole(String role) {
  switch (role) {
    case 'enseignant':
      return 'Enseignant';
    case 'censeur':
      return 'Censeur';
    case 'secretaire':
      return 'Secrétaire';
    case 'directeur':
      return 'Directeur';
    default:
      return role;
  }
}

// Champ de saisie flat commun aux dialogs de cet écran.
InputDecoration _decorationChamp(String label, {IconData? icone}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    prefixIcon: icone != null ? Icon(icone, size: 19, color: SSMPalette.texte3) : null,
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

ButtonStyle _stylePrimaire(Color couleur) => ElevatedButton.styleFrom(
      backgroundColor: couleur,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
    );

class FicheUtilisateurScreen extends StatefulWidget {
  final int userId;

  const FicheUtilisateurScreen({super.key, required this.userId});

  @override
  State<FicheUtilisateurScreen> createState() => _FicheUtilisateurScreenState();
}

class _FicheUtilisateurScreenState extends State<FicheUtilisateurScreen> {
  Map<String, dynamic>? _utilisateur;
  List<dynamic> _affectations = [];
  int _totalClasses = 0;
  double _totalHeures = 0;
  int _totalEleves = 0;
  bool _chargement = true;
  bool _chargementStats = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    try {
      final utilisateur = await UtilisateurService.obtenir(widget.userId);
      setState(() {
        _utilisateur = utilisateur;
        _chargement = false;
      });

      if (utilisateur['role'] == 'enseignant') {
        await _chargerStatsEnseignant();
      }
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerStatsEnseignant() async {
    setState(() => _chargementStats = true);
    try {
      final donneesAffectations = await AffectationService.listerAffectations(
        widget.userId,
      );
      final affectations = (donneesAffectations['affectations'] as List?) ?? [];

      final classesUniques = <int>{};
      for (final a in affectations) {
        classesUniques.add(a['classe_id'] as int);
      }

      double totalHeures = 0;
      int totalEleves = 0;

      try {
        final annees = await AnneeService.listerAnnees();
        final anneeEnCours = annees.firstWhere(
          (a) => a['statut'] == 'en_cours',
          orElse: () => annees.isNotEmpty ? annees.first : null,
        );
        final anneeId = anneeEnCours?['id'] as int?;

        // Le volume horaire hebdomadaire de l'enseignant est désormais
        // calculable via le module Emploi du Temps (statistiques par
        // enseignant) plutôt que via cette ancienne API par année.
        if (anneeId != null) {
          final listes = await Future.wait(
            classesUniques.map(
              (classeId) => EleveService.elevesParClasse(classeId, anneeId),
            ),
          );
          totalEleves = listes.fold<int>(0, (total, l) => total + l.length);
        }
      } catch (_) {
        // Statistiques additionnelles non bloquantes si indisponibles.
      }

      setState(() {
        _affectations = affectations;
        _totalClasses = classesUniques.length;
        _totalHeures = totalHeures;
        _totalEleves = totalEleves;
        _chargementStats = false;
      });
    } catch (e) {
      setState(() => _chargementStats = false);
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.teal),
    );
  }

  String _tempsRelatif(String? iso) {
    if (iso == null) return 'Jamais connecté';
    final date = DateTime.tryParse(iso);
    if (date == null) return '—';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    return 'Il y a ${difference.inDays} j';
  }

  String _formaterDate(String? iso) {
    if (iso == null) return '—';
    final date = DateTime.tryParse(iso);
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _reinitialiserMotDePasse() async {
    try {
      final resultat = await UtilisateurService.reinitialiserMotDePasse(
        widget.userId,
      );
      if (!mounted) return;
      _afficherDialogMotDePasse(resultat['mot_de_passe'] as String);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherDialogMotDePasse(String motDePasse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nouveau mot de passe temporaire :',
              style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(SSMRayons.moyen),
                border: Border.all(color: SSMPalette.bordure),
              ),
              alignment: Alignment.center,
              child: Text(
                motDePasse,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: SSMPalette.indigo,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: motDePasse));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mot de passe copié')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: SSMPalette.indigo,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerDesactivation() async {
    final nom = '${_utilisateur!['name']} ${_utilisateur!['prenom'] ?? ''}'
        .trim();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: SSMPalette.ambre),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Désactiver $nom ?',
                style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
            ),
          ],
        ),
        content: Text(
          'Cet utilisateur ne pourra plus se connecter.',
          style: GoogleFonts.inter(color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SSMPalette.rouge,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirme == true) {
      try {
        await UtilisateurService.desactiver(widget.userId);
        _afficherSucces('Utilisateur désactivé');
        _chargerDonnees();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _reactiver() async {
    try {
      await UtilisateurService.reactiver(widget.userId);
      _afficherSucces('Utilisateur réactivé');
      _chargerDonnees();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogModifier() async {
    final u = _utilisateur!;
    final nomController = TextEditingController(text: u['name'] as String? ?? '');
    final prenomController = TextEditingController(text: u['prenom'] as String? ?? '');
    final emailController = TextEditingController(text: u['email'] as String? ?? '');
    final telephoneController = TextEditingController(text: u['telephone'] as String? ?? '');
    final adresseController = TextEditingController(text: u['adresse'] as String? ?? '');
    final fonctionController = TextEditingController(text: u['fonction'] as String? ?? '');
    String role = u['role'] as String;
    File? photo;
    final photoUrlExistante = u['photo_url'] as String?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Modifier l'utilisateur",
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                    imageQuality: 80,
                                  );
                                  if (image != null) {
                                    setStateDialog(() => photo = File(image.path));
                                  }
                                },
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundColor: SSMPalette.indigo.withValues(alpha: 0.15),
                                      backgroundImage: photo != null
                                          ? FileImage(photo!)
                                          : (photoUrlExistante != null
                                              ? NetworkImage(photoUrlExistante) as ImageProvider
                                              : null),
                                      child: (photo == null && photoUrlExistante == null)
                                          ? Icon(Icons.person, size: 40, color: SSMPalette.indigo)
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: SSMPalette.ambre, shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(controller: nomController, decoration: _decorationChamp('Nom *', icone: Icons.person)),
                            const SizedBox(height: 12),
                            TextField(controller: prenomController, decoration: _decorationChamp('Prénom', icone: Icons.person_outline)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decorationChamp('Email *', icone: Icons.email_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: telephoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _decorationChamp('Téléphone', icone: Icons.phone_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: adresseController, decoration: _decorationChamp('Adresse', icone: Icons.location_on_outlined)),
                            const SizedBox(height: 12),
                            TextField(controller: fonctionController, decoration: _decorationChamp('Fonction', icone: Icons.work_outline)),
                            const SizedBox(height: 12),
                            if (role != 'directeur')
                              DropdownButtonFormField<String>(
                                initialValue: role,
                                decoration: _decorationChamp('Rôle *', icone: Icons.badge_outlined),
                                items: const [
                                  DropdownMenuItem(value: 'enseignant', child: Text('Enseignant')),
                                  DropdownMenuItem(value: 'censeur', child: Text('Censeur')),
                                  DropdownMenuItem(value: 'secretaire', child: Text('Secrétaire')),
                                ],
                                onChanged: (v) => setStateDialog(() => role = v ?? role),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: _stylePrimaire(SSMPalette.indigo),
                            onPressed: () async {
                              if (nomController.text.isEmpty || emailController.text.isEmpty) {
                                _afficherErreur('Veuillez remplir les champs obligatoires');
                                return;
                              }
                              try {
                                await UtilisateurService.modifier(
                                  widget.userId,
                                  nom: nomController.text,
                                  prenom: prenomController.text.isEmpty ? null : prenomController.text,
                                  email: emailController.text,
                                  telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                                  adresse: adresseController.text.isEmpty ? null : adresseController.text,
                                  fonction: fonctionController.text.isEmpty ? null : fonctionController.text,
                                  role: role == 'directeur' ? null : role,
                                  photo: photo,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Utilisateur modifié avec succès');
                                _chargerDonnees();
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: const Text('Enregistrer'),
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

    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    adresseController.dispose();
    fonctionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement || _utilisateur == null) {
      return const Scaffold(backgroundColor: SSMPalette.fond, body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)));
    }

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: RefreshIndicator(
        onRefresh: _chargerDonnees,
        color: SSMPalette.indigo,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _enTeteBarre()),
            SliverToBoxAdapter(child: _breadcrumb()),
          ],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionIdentite(),
              const SizedBox(height: 16),
              _sectionActionsRapides(),
              if (_utilisateur!['role'] == 'enseignant') ...[
                const SizedBox(height: 20),
                _sectionAffectations(),
              ],
              const SizedBox(height: 20),
              _sectionHistorique(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE — barre plate (remplace l'AppBar bleu)
  // ══════════════════════════════════════════════════════

  Widget _enTeteBarre() {
    return Container(
      color: SSMPalette.blanc,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: SSMPalette.texte2),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                'Fiche utilisateur',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: SSMPalette.texte2),
              onPressed: _afficherDialogModifier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _breadcrumb() {
    final u = _utilisateur!;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();
    return Container(
      width: double.infinity,
      color: SSMPalette.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Text('Utilisateurs', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.teal)),
          ),
          const Icon(Icons.chevron_right, size: 14, color: SSMPalette.texte3),
          Text(
            nomComplet,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 1 — Identité
  // ══════════════════════════════════════════════════════

  Widget _sectionIdentite() {
    final u = _utilisateur!;
    final role = u['role'] as String;
    final couleur = _couleurRole(role);
    final actif = u['actif'] == true;
    final photoUrl = u['photo_url'] as String?;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        children: [
          SSMAvatar(nom: nomComplet, photoUrl: photoUrl, couleur: couleur, rayon: 44),
          const SizedBox(height: 12),
          Text(
            nomComplet,
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
            textAlign: TextAlign.center,
          ),
          if (u['fonction'] != null) ...[
            const SizedBox(height: 2),
            Text(u['fonction'] as String, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              SSMPill.couleur(label: _labelRole(role), couleur: couleur),
              SSMPill.couleur(label: actif ? 'Actif' : 'Inactif', couleur: actif ? SSMPalette.teal : SSMPalette.rouge),
            ],
          ),
          const SizedBox(height: 16),
          _ligneInfo(Icons.email_outlined, u['email'] as String),
          if (u['telephone'] != null) _ligneInfo(Icons.phone_outlined, u['telephone'] as String),
          if (u['adresse'] != null) _ligneInfo(Icons.location_on_outlined, u['adresse'] as String),
          const SizedBox(height: 8),
          Text(
            'Dernière connexion : ${_tempsRelatif(u['derniere_connexion'] as String?)}',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
          ),
          if (role == 'enseignant') ...[
            const SizedBox(height: 16),
            _chargementStats
                ? const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)),
                  )
                : Row(
                    children: [
                      Expanded(child: _statMini('$_totalClasses', 'Classes', Icons.class_outlined)),
                      Expanded(child: _statMini(_totalHeures.toStringAsFixed(1), 'H/semaine', Icons.schedule)),
                      Expanded(child: _statMini('$_totalEleves', 'Élèves', Icons.people_outline)),
                    ],
                  ),
          ],
        ],
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: SSMPalette.texte3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(valeur, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
          ),
        ],
      ),
    );
  }

  Widget _statMini(String valeur, String label, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icone, size: 17, color: SSMPalette.indigo),
          const SizedBox(height: 4),
          Text(valeur, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 2 — Actions rapides
  // ══════════════════════════════════════════════════════

  Widget _sectionActionsRapides() {
    final actif = _utilisateur!['actif'] == true;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SSMQuickActionButton(
          icone: Icons.edit_outlined,
          label: 'Modifier',
          variante: SSMActionVariante.primaire,
          onTap: _afficherDialogModifier,
        ),
        SSMQuickActionButton(
          icone: Icons.lock_reset,
          label: 'Réinit. mot de passe',
          variante: SSMActionVariante.ambre,
          onTap: _reinitialiserMotDePasse,
        ),
        SSMQuickActionButton(
          icone: actif ? Icons.block : Icons.check_circle,
          label: actif ? 'Désactiver' : 'Réactiver',
          variante: actif ? SSMActionVariante.rouge : SSMActionVariante.teal,
          onTap: actif ? _confirmerDesactivation : _reactiver,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 3 — Affectations
  // ══════════════════════════════════════════════════════

  Widget _sectionAffectations() {
    final parClasse = <int, Map<String, dynamic>>{};
    for (final a in _affectations) {
      final classeId = a['classe_id'] as int;
      parClasse.putIfAbsent(
        classeId,
        () => {'nom': a['classe_nom'], 'matieres': <dynamic>[]},
      );
      (parClasse[classeId]!['matieres'] as List).add(a);
    }

    return SSMPanel(
      titre: 'Classes & matières',
      lienAction: 'Modifier',
      onLienAction: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AffectationEnseignantScreen(
            userId: widget.userId,
            userName: '${_utilisateur!['name']} ${_utilisateur!['prenom'] ?? ''}'.trim(),
          ),
        ),
      ).then((_) => _chargerDonnees()),
      child: parClasse.isEmpty
          ? Column(
              children: [
                SSMAlertItem(
                  type: SSMAlerteType.avertissement,
                  icone: Icons.warning_amber_rounded,
                  titre: 'Aucune affectation enregistrée',
                  sousTitre: "Cet enseignant n'est encore rattaché à aucune classe.",
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: _stylePrimaire(SSMPalette.ambre),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AffectationEnseignantScreen(
                          userId: widget.userId,
                          userName: '${_utilisateur!['name']} ${_utilisateur!['prenom'] ?? ''}'.trim(),
                        ),
                      ),
                    ).then((_) => _chargerDonnees()),
                    child: const Text('Affecter maintenant'),
                  ),
                ),
              ],
            )
          : Column(
              children: parClasse.values.map((c) {
                final matieres = c['matieres'] as List;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(SSMRayons.grand),
                    border: Border(left: BorderSide(color: SSMPalette.indigo, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['nom'] as String,
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: matieres.map((m) {
                          final coef = m['coefficient'];
                          final label = coef != null ? '${m['matiere_nom']} (coef $coef)' : '${m['matiere_nom']}';
                          return SSMPill.couleur(label: label, couleur: SSMPalette.teal);
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 4 — Historique
  // ══════════════════════════════════════════════════════

  Widget _sectionHistorique() {
    final u = _utilisateur!;
    return SSMPanel(
      titre: 'Historique',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ligneHistorique(Icons.login, 'Dernière connexion', _tempsRelatif(u['derniere_connexion'] as String?)),
          _ligneHistorique(Icons.calendar_today_outlined, 'Compte créé le', _formaterDate(u['created_at'] as String?)),
          _ligneHistorique(Icons.lock_outline, 'Mot de passe changé', u['mot_de_passe_change'] == true ? 'Oui' : 'Non', dernier: true),
        ],
      ),
    );
  }

  Widget _ligneHistorique(IconData icone, String titre, String valeur, {bool dernier = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: dernier ? null : const Border(bottom: BorderSide(color: SSMPalette.bordure)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: SSMPalette.indigo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icone, size: 16, color: SSMPalette.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                Text(valeur, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: SSMPalette.texte1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
