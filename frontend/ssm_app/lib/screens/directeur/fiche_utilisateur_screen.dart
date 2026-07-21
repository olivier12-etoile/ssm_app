import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/utilisateur_service.dart';
import '../../services/affectation_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'affectation_enseignant_screen.dart';

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
        _chargement  = false;
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
      final donneesAffectations =
          await AffectationService.listerAffectations(widget.userId);
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

        if (anneeId != null) {
          final emploi = await EmploiDuTempsService.parEnseignant(
            enseignantId: widget.userId,
            anneeId: anneeId,
          );
          for (final creneaux in emploi.values) {
            for (final c in (creneaux as List)) {
              totalHeures += _dureeEnHeures(
                c['heure_debut'] as String,
                c['heure_fin'] as String,
              );
            }
          }

          final listes = await Future.wait(classesUniques.map(
            (classeId) => EleveService.elevesParClasse(classeId, anneeId),
          ));
          totalEleves = listes.fold<int>(0, (total, l) => total + l.length);
        }
      } catch (_) {
        // Statistiques additionnelles non bloquantes si indisponibles.
      }

      setState(() {
        _affectations   = affectations;
        _totalClasses   = classesUniques.length;
        _totalHeures    = totalHeures;
        _totalEleves    = totalEleves;
        _chargementStats = false;
      });
    } catch (e) {
      setState(() => _chargementStats = false);
    }
  }

  double _dureeEnHeures(String debut, String fin) {
    final d = debut.split(':').map(int.parse).toList();
    final f = fin.split(':').map(int.parse).toList();
    return ((f[0] * 60 + f[1]) - (d[0] * 60 + d[1])) / 60;
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  Color _couleurRole(String role) {
    switch (role) {
      case 'enseignant':  return const Color(0xFF1E3A8A);
      case 'censeur':     return const Color(0xFFD97706);
      case 'secretaire':  return const Color(0xFF0D9488);
      case 'directeur':   return const Color(0xFF7C3AED);
      default:            return const Color(0xFF94A3B8);
    }
  }

  String _labelRole(String role) {
    switch (role) {
      case 'enseignant':  return 'Enseignant';
      case 'censeur':     return 'Censeur';
      case 'secretaire':  return 'Secrétaire';
      case 'directeur':   return 'Directeur';
      default:            return role;
    }
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
      final resultat = await UtilisateurService.reinitialiserMotDePasse(widget.userId);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nouveau mot de passe temporaire :',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(
                motDePasse,
                style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: motDePasse));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe copié')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerDesactivation() async {
    final nom = '${_utilisateur!['name']} ${_utilisateur!['prenom'] ?? ''}'.trim();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(child: Text('Désactiver $nom ?', style: GoogleFonts.sora(fontWeight: FontWeight.w700))),
          ],
        ),
        content: Text('Cet utilisateur ne pourra plus se connecter.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
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
    final nomController       = TextEditingController(text: u['name'] as String? ?? '');
    final prenomController    = TextEditingController(text: u['prenom'] as String? ?? '');
    final emailController     = TextEditingController(text: u['email'] as String? ?? '');
    final telephoneController = TextEditingController(text: u['telephone'] as String? ?? '');
    final adresseController   = TextEditingController(text: u['adresse'] as String? ?? '');
    final fonctionController  = TextEditingController(text: u['fonction'] as String? ?? '');
    String role = u['role'] as String;
    File? photo;
    final photoUrlExistante = u['photo_url'] as String?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Modifier l'utilisateur",
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 16),
                    Expanded(
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
                                  if (image != null) setStateDialog(() => photo = File(image.path));
                                },
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                                      backgroundImage: photo != null
                                          ? FileImage(photo!)
                                          : (photoUrlExistante != null
                                              ? NetworkImage(photoUrlExistante) as ImageProvider
                                              : null),
                                      child: (photo == null && photoUrlExistante == null)
                                          ? const Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A))
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: nomController,
                              decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.person)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: prenomController,
                              decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person_outline)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: telephoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: adresseController,
                              decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.location_on)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: fonctionController,
                              decoration: const InputDecoration(labelText: 'Fonction', prefixIcon: Icon(Icons.work)),
                            ),
                            const SizedBox(height: 12),
                            if (role != 'directeur')
                              DropdownButtonFormField<String>(
                                value: role,
                                decoration: const InputDecoration(labelText: 'Rôle *', prefixIcon: Icon(Icons.badge)),
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
                          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              if (nomController.text.isEmpty || emailController.text.isEmpty) {
                                _afficherErreur('Veuillez remplir les champs obligatoires');
                                return;
                              }
                              try {
                                await UtilisateurService.modifier(
                                  widget.userId,
                                  nom:       nomController.text,
                                  prenom:    prenomController.text.isEmpty ? null : prenomController.text,
                                  email:     emailController.text,
                                  telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                                  adresse:   adresseController.text.isEmpty ? null : adresseController.text,
                                  fonction:  fonctionController.text.isEmpty ? null : fonctionController.text,
                                  role:      role == 'directeur' ? null : role,
                                  photo:     photo,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Fiche utilisateur',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _chargerDonnees),
        ],
      ),
      body: _chargement || _utilisateur == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionIdentite(),
                  const SizedBox(height: 20),
                  _sectionActionsRapides(),
                  if (_utilisateur!['role'] == 'enseignant') ...[
                    const SizedBox(height: 24),
                    _sectionAffectations(),
                  ],
                  const SizedBox(height: 24),
                  _sectionHistorique(),
                ],
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 1 — Identité
  // ══════════════════════════════════════════════════════

  Widget _sectionIdentite() {
    final u        = _utilisateur!;
    final role     = u['role'] as String;
    final couleur  = _couleurRole(role);
    final actif    = u['actif'] == true;
    final photoUrl = u['photo_url'] as String?;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [couleur, couleur.withValues(alpha: 0.7)]),
                  image: photoUrl != null
                      ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: photoUrl == null
                    ? Text(
                        (u['name'] as String).isNotEmpty ? (u['name'] as String).substring(0, 1).toUpperCase() : '?',
                        style: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                nomComplet,
                style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              if (u['fonction'] != null) ...[
                const SizedBox(height: 2),
                Text(u['fonction'] as String, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  SSMBadge(label: _labelRole(role), couleur: couleur),
                  SSMBadge(
                    label: actif ? 'ACTIF' : 'INACTIF',
                    couleur: actif ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ligneInfo(Icons.email, u['email'] as String),
              if (u['telephone'] != null) _ligneInfo(Icons.phone, u['telephone'] as String),
              if (u['adresse'] != null) _ligneInfo(Icons.location_on, u['adresse'] as String),
              const SizedBox(height: 8),
              Text(
                'Dernière connexion : ${_tempsRelatif(u['derniere_connexion'] as String?)}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              if (role == 'enseignant') ...[
                const SizedBox(height: 16),
                _chargementStats
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        children: [
                          Expanded(child: _statMini('$_totalClasses', 'Classes', Icons.class_)),
                          Expanded(child: _statMini(_totalHeures.toStringAsFixed(1), 'H/semaine', Icons.schedule)),
                          Expanded(child: _statMini('$_totalEleves', 'Élèves', Icons.people)),
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(valeur, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  Widget _statMini(String valeur, String label, IconData icone) {
    return Column(
      children: [
        Icon(icone, size: 18, color: const Color(0xFF1E3A8A)),
        const SizedBox(height: 4),
        Text(valeur, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 2 — Actions rapides
  // ══════════════════════════════════════════════════════

  Widget _sectionActionsRapides() {
    final actif = _utilisateur!['actif'] == true;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _afficherDialogModifier,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              side: const BorderSide(color: Color(0xFF1E3A8A)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Modifier'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _reinitialiserMotDePasse,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.lock_reset, size: 16),
            label: const Text('Réinit. MDP'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: actif ? _confirmerDesactivation : _reactiver,
            style: ElevatedButton.styleFrom(
              backgroundColor: actif ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: Icon(actif ? Icons.block : Icons.check_circle, size: 16),
            label: Text(actif ? 'Désactiver' : 'Réactiver'),
          ),
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
      parClasse.putIfAbsent(classeId, () => {
            'nom': a['classe_nom'],
            'matieres': <dynamic>[],
          });
      (parClasse[classeId]!['matieres'] as List).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SSMSectionTitre(titre: 'Classes & matières'),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AffectationEnseignantScreen(
                    userId:   widget.userId,
                    userName: '${_utilisateur!['name']} ${_utilisateur!['prenom'] ?? ''}'.trim(),
                  ),
                ),
              ).then((_) => _chargerDonnees()),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1E3A8A)),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Modifier les affectations'),
            ),
          ],
        ),
        if (parClasse.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFD97706), size: 32),
                const SizedBox(height: 8),
                Text('Aucune affectation enregistrée',
                    style: GoogleFonts.inter(color: const Color(0xFF92400E))),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AffectationEnseignantScreen(
                        userId:   widget.userId,
                        userName: '${_utilisateur!['name']} ${_utilisateur!['prenom'] ?? ''}'.trim(),
                      ),
                    ),
                  ).then((_) => _chargerDonnees()),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                  child: const Text('Affecter maintenant'),
                ),
              ],
            ),
          )
        else
          ...parClasse.values.map((c) {
            final matieres = c['matieres'] as List;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: Color(0xFF1E3A8A), width: 4)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['nom'] as String,
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matieres.map((m) {
                      final coef = m['coefficient'];
                      final label = coef != null
                          ? '${m['matiere_nom']} (coef $coef)'
                          : '${m['matiere_nom']}';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(label,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 4 — Historique
  // ══════════════════════════════════════════════════════

  Widget _sectionHistorique() {
    final u = _utilisateur!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SSMSectionTitre(titre: 'Historique'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              SSMListeTile(
                titre: 'Dernière connexion',
                sousTitre: _tempsRelatif(u['derniere_connexion'] as String?),
                icone: Icons.login,
                couleurIcone: const Color(0xFF1E3A8A),
              ),
              SSMListeTile(
                titre: 'Compte créé le',
                sousTitre: _formaterDate(u['created_at'] as String?),
                icone: Icons.calendar_today,
                couleurIcone: const Color(0xFF1E3A8A),
              ),
              SSMListeTile(
                titre: 'Mot de passe changé',
                sousTitre: u['mot_de_passe_change'] == true ? 'Oui' : 'Non',
                icone: Icons.lock,
                couleurIcone: const Color(0xFF1E3A8A),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
