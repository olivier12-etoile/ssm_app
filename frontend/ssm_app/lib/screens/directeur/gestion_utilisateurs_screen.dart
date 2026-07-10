import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/utilisateur_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'affectation_enseignant_screen.dart';

class GestionUtilisateursScreen extends StatefulWidget {
  const GestionUtilisateursScreen({super.key});

  @override
  State<GestionUtilisateursScreen> createState() =>
      _GestionUtilisateursScreenState();
}

class _GestionUtilisateursScreenState
    extends State<GestionUtilisateursScreen> {
  List<dynamic> _utilisateurs = [];
  bool _chargement = true;
  String? _filtreRole;

  static const _roles = ['directeur', 'censeur', 'secretaire', 'enseignant'];

  @override
  void initState() {
    super.initState();
    _chargerUtilisateurs();
  }

  Future<void> _chargerUtilisateurs() async {
    try {
      final liste = await UtilisateurService.listerUtilisateurs();
      setState(() {
        _utilisateurs = liste;
        _chargement   = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
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
      case 'directeur':  return const Color(0xFF1E3A8A);
      case 'censeur':    return const Color(0xFF0284C7);
      case 'secretaire': return const Color(0xFF0D9488);
      case 'enseignant': return const Color(0xFFD97706);
      default:           return const Color(0xFF94A3B8);
    }
  }

  IconData _iconeRole(String role) {
    switch (role) {
      case 'directeur':  return Icons.admin_panel_settings;
      case 'censeur':    return Icons.supervisor_account;
      case 'secretaire': return Icons.work;
      case 'enseignant': return Icons.school;
      default:           return Icons.person;
    }
  }

  List<dynamic> get _utilisateursFiltres {
    if (_filtreRole == null) return _utilisateurs;
    return _utilisateurs.where((u) => u['role'] == _filtreRole).toList();
  }

  Future<void> _modifierRole(int id, String roleActuel) async {
    String roleSelectionne = roleActuel;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le rôle'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: ['censeur', 'secretaire', 'enseignant'].map((role) {
                return RadioListTile<String>(
                  title: Text(role),
                  value: role,
                  groupValue: roleSelectionne,
                  onChanged: (v) => setStateDialog(() => roleSelectionne = v!),
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await UtilisateurService.modifierRole(id, roleSelectionne);
                Navigator.pop(context);
                _afficherSucces('Rôle mis à jour');
                _chargerUtilisateurs();
              } catch (e) {
                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherDialogCreation() async {
    final nomController    = TextEditingController();
    final emailController  = TextEditingController();
    String roleSelectionne = 'enseignant';
    String? motDePasseGenere;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Ajouter un utilisateur'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (motDePasseGenere != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF16A34A)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                          const SizedBox(height: 8),
                          const Text(
                            'Compte créé avec succès !',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text('Mot de passe temporaire :'),
                          SelectableText(
                            motDePasseGenere!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            'Notez ce mot de passe et transmettez-le à l\'utilisateur.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: roleSelectionne,
                      decoration: const InputDecoration(
                        labelText: 'Rôle',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: ['censeur', 'secretaire', 'enseignant']
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => roleSelectionne = v!),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(motDePasseGenere != null ? 'Fermer' : 'Annuler'),
              ),
              if (motDePasseGenere == null)
                ElevatedButton(
                  onPressed: () async {
                    if (nomController.text.isEmpty ||
                        emailController.text.isEmpty) {
                      return;
                    }
                    try {
                      final result = await UtilisateurService.creerUtilisateur(
                        nom:   nomController.text,
                        email: emailController.text,
                        role:  roleSelectionne,
                      );
                      setStateDialog(() {
                        motDePasseGenere = result['mot_de_passe'];
                      });
                      _chargerUtilisateurs();
                    } catch (e) {
                      _afficherErreur(
                          e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  child: const Text('Créer'),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Gestion des utilisateurs',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerUtilisateurs,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Chips filtre rôles ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipRole(null, 'Tous'),
                        ..._roles.map((r) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _chipRole(r, _labelRole(r)),
                            )),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _utilisateursFiltres.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline,
                                  size: 64, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun utilisateur pour l\'instant',
                                style: GoogleFonts.inter(color: const Color(0xFF334155)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _utilisateursFiltres.length,
                          itemBuilder: (context, index) {
                            final u    = _utilisateursFiltres[index];
                            final role = u['role'] as String;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: SSMListeTile(
                                titre: u['name'] as String,
                                sousTitre: u['email'] as String,
                                icone: _iconeRole(role),
                                couleurIcone: _couleurRole(role),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (role == 'enseignant')
                                      IconButton(
                                        icon: const Icon(
                                          Icons.assignment_ind,
                                          color: Color(0xFF1E3A8A),
                                          size: 20,
                                        ),
                                        tooltip: 'Gérer les affectations',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AffectationEnseignantScreen(
                                              enseignantId:  u['id'] as int,
                                              enseignantNom: u['name'] as String,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (role != 'directeur')
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Color(0xFF1E3A8A),
                                          size: 20,
                                        ),
                                        tooltip: 'Modifier le rôle',
                                        onPressed: () =>
                                            _modifierRole(u['id'] as int, role),
                                      ),
                                    SSMBadge(
                                      label: role.toUpperCase(),
                                      couleur: _couleurRole(role),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _labelRole(String role) {
    switch (role) {
      case 'directeur':  return 'Directeur';
      case 'censeur':    return 'Censeur';
      case 'secretaire': return 'Secrétaire';
      case 'enseignant': return 'Enseignant';
      default:           return role;
    }
  }

  Widget _chipRole(String? role, String label) {
    final selectionne = _filtreRole == role;
    final couleur = role == null ? const Color(0xFF1E3A8A) : _couleurRole(role);
    return GestureDetector(
      onTap: () => setState(() => _filtreRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? couleur : couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: couleur.withValues(alpha: selectionne ? 1 : 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selectionne ? Colors.white : couleur,
          ),
        ),
      ),
    );
  }
}
