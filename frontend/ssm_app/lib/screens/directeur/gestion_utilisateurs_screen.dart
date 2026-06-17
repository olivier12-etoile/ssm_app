import 'package:flutter/material.dart';
import '../../services/utilisateur_service.dart';
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Color _couleurRole(String role) {
    switch (role) {
      case 'directeur':  return Colors.blue;
      case 'censeur':    return Colors.purple;
      case 'secretaire': return Colors.teal;
      case 'enseignant': return Colors.orange;
      default:           return Colors.grey;
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
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
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
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: Colors.blue,
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
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _utilisateurs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucun utilisateur pour l\'instant',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _utilisateurs.length,
                  itemBuilder: (context, index) {
                    final u    = _utilisateurs[index];
                    final role = u['role'] as String;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: _couleurRole(role),
                          child: Icon(
                            _iconeRole(role),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          u['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['email'] as String),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _couleurRole(role).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _couleurRole(role).withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _couleurRole(role),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ← MODIFIÉ : boutons selon le rôle
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bouton affectation uniquement pour les enseignants
                            if (role == 'enseignant')
                              IconButton(
                                icon: const Icon(
                                  Icons.assignment_ind,
                                  color: Colors.indigo,
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

                            // Bouton modifier rôle — tout le monde sauf directeur
                            if (role != 'directeur')
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                tooltip: 'Modifier le rôle',
                                onPressed: () =>
                                    _modifierRole(u['id'] as int, role),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}