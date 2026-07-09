import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';

class ElevesParClasseScreen extends StatefulWidget {
  final int classeId;
  final int anneeId;
  final String? nomClasse;

  const ElevesParClasseScreen({
    super.key,
    required this.classeId,
    required this.anneeId,
    this.nomClasse,
  });

  @override
  State<ElevesParClasseScreen> createState() => _ElevesParClasseScreenState();
}

class _ElevesParClasseScreenState extends State<ElevesParClasseScreen> {
  List<dynamic> _eleves = [];
  String? _nomClasse;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _nomClasse = widget.nomClasse;
    _chargerEleves();
    if (_nomClasse == null) _chargerNomClasse();
  }

  Future<void> _chargerNomClasse() async {
    try {
      final classes = await ClasseService.listerClasses();
      final classe = classes.firstWhere(
        (c) => c['id'] == widget.classeId,
        orElse: () => null,
      );
      if (classe != null && mounted) {
        setState(() => _nomClasse = classe['nom'] as String);
      }
    } catch (_) {
      // Le titre reste sur la valeur par défaut si la classe n'est pas trouvée.
    }
  }

  Future<void> _chargerEleves() async {
    try {
      final liste = await EleveService.elevesParClasse(
        widget.classeId,
        widget.anneeId,
      );
      setState(() {
        _eleves = liste;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> _changerPhoto(int eleveId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envoi de la photo...')),
      );

      await EleveService.uploaderPhoto(eleveId, File(image.path));
      _afficherSucces('Photo mise à jour');
      _chargerEleves();
    } catch (e) {
      _afficherErreur('Erreur upload photo: $e');
    }
  }

  Future<void> _afficherDialogCreation() async {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final telParentController = TextEditingController();
    String sexeSelectionne = 'M';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Inscrire un élève — ${_nomClasse ?? "classe"}'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: prenomController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: sexeSelectionne,
                      decoration: const InputDecoration(
                        labelText: 'Sexe',
                        prefixIcon: Icon(Icons.wc),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Masculin')),
                        DropdownMenuItem(value: 'F', child: Text('Féminin')),
                      ],
                      onChanged: (v) =>
                          setStateDialog(() => sexeSelectionne = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telParentController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone parent (optionnel)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    nomController.text.isEmpty || prenomController.text.isEmpty
                        ? null
                        : () async {
                            try {
                              await EleveService.creerEleve(
                                nom: nomController.text,
                                prenom: prenomController.text,
                                sexe: sexeSelectionne,
                                classeId: widget.classeId,
                                anneeAcademiqueId: widget.anneeId,
                                telephoneParent: telParentController.text.isEmpty
                                    ? null
                                    : telParentController.text,
                              );
                              Navigator.pop(context);
                              _afficherSucces('Élève inscrit avec succès');
                              _chargerEleves();
                            } catch (e) {
                              _afficherErreur(
                                  e.toString().replaceAll('Exception: ', ''));
                            }
                          },
                child: const Text('Inscrire'),
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
        title: Text(_nomClasse ?? 'Élèves de la classe'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerEleves,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add),
        label: const Text('Inscrire un élève'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _eleves.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucun élève inscrit dans cette classe',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _eleves.length,
                  itemBuilder: (context, index) {
                    final e = _eleves[index];
                    final sexe = e['sexe'] as String;
                    final eleveId = e['id'] as int;
                    final photoUrl = e['photo_url'] as String?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/eleve/fiche',
                          arguments: {'eleveId': eleveId},
                        ),
                        leading: GestureDetector(
                          onTap: () => _changerPhoto(eleveId),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    sexe == 'M' ? Colors.blue : Colors.pink,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? Text(
                                        e['prenom'].toString().substring(0, 1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          '${e['nom']} ${e['prenom']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Matricule : ${e['matricule']}'),
                        trailing: Icon(
                          sexe == 'M' ? Icons.boy : Icons.girl,
                          color: sexe == 'M' ? Colors.blue : Colors.pink,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
