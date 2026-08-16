import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_pill.dart';

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
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.teal),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Envoi de la photo...')));

      await EleveService.uploaderPhoto(eleveId, File(image.path));
      _afficherSucces('Photo mise à jour');
      _chargerEleves();
    } catch (e) {
      _afficherErreur('Erreur upload photo: $e');
    }
  }

  InputDecoration _decorationChamp(String label, IconData icone) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      prefixIcon: Icon(icone, size: 19, color: SSMPalette.texte3),
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

  Future<void> _afficherDialogCreation() async {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final telParentController = TextEditingController();
    String sexeSelectionne = 'M';
    DateTime? dateNaissance;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: SSMPalette.blanc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            title: Text(
              'Inscrire un élève — ${_nomClasse ?? "classe"}',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nomController, decoration: _decorationChamp('Nom', Icons.person_outline)),
                    const SizedBox(height: 12),
                    TextField(controller: prenomController, decoration: _decorationChamp('Prénom', Icons.person_outline)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: sexeSelectionne,
                      decoration: _decorationChamp('Sexe', Icons.wc),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Masculin')),
                        DropdownMenuItem(value: 'F', child: Text('Féminin')),
                      ],
                      onChanged: (v) => setStateDialog(() => sexeSelectionne = v!),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(SSMRayons.moyen),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(SSMRayons.moyen),
                        onTap: () async {
                          final choisie = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2015),
                            firstDate: DateTime(1995),
                            lastDate: DateTime.now(),
                          );
                          if (choisie != null) {
                            setStateDialog(() => dateNaissance = choisie);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(SSMRayons.moyen),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake_outlined, size: 19, color: SSMPalette.texte3),
                              const SizedBox(width: 10),
                              Text(
                                dateNaissance != null
                                    ? '${dateNaissance!.day}/${dateNaissance!.month}/${dateNaissance!.year}'
                                    : 'Date de naissance',
                                style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telParentController,
                      keyboardType: TextInputType.phone,
                      decoration: _decorationChamp('Téléphone parent (optionnel)', Icons.phone_outlined),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SSMPalette.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                ),
                onPressed: nomController.text.isEmpty || prenomController.text.isEmpty || dateNaissance == null
                    ? null
                    : () async {
                        try {
                          final resultat = await EleveService.creer(
                            nom: nomController.text,
                            prenom: prenomController.text,
                            sexe: sexeSelectionne,
                            dateNaissance:
                                '${dateNaissance!.year.toString().padLeft(4, '0')}-'
                                '${dateNaissance!.month.toString().padLeft(2, '0')}-'
                                '${dateNaissance!.day.toString().padLeft(2, '0')}',
                            classeId: widget.classeId,
                            anneeAcademiqueId: widget.anneeId,
                          );
                          if (telParentController.text.isNotEmpty) {
                            final eleveId = resultat['eleve']['id'] as int;
                            await EleveService.modifier(eleveId, {
                              'nom': nomController.text,
                              'prenom': prenomController.text,
                              'sexe': sexeSelectionne,
                              'telephone_parent': telParentController.text,
                            });
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _afficherSucces('Élève inscrit avec succès');
                          _chargerEleves();
                        } catch (e) {
                          _afficherErreur(e.toString().replaceAll('Exception: ', ''));
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
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        backgroundColor: SSMPalette.blanc,
        foregroundColor: SSMPalette.texte1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _nomClasse ?? 'Élèves de la classe',
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: SSMPalette.texte2, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: SSMPalette.texte2),
            onPressed: _chargerEleves,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: SSMPalette.bordure),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: SSMPalette.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Inscrire un élève'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : _eleves.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 56, color: SSMPalette.texte3),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun élève inscrit dans cette classe',
                        style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, contraintes) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: contraintes.maxWidth >= 760 ? _tableEleves() : _listeEleves(),
                    );
                  },
                ),
    );
  }

  Widget _listeEleves() {
    return Column(
      children: [
        for (final e in _eleves) ...[
          _carteEleve(e as Map<String, dynamic>),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _carteEleve(Map<String, dynamic> e) {
    final sexe = e['sexe'] as String;
    final eleveId = e['id'] as int;
    final photoUrl = e['photo_url'] as String?;
    final couleurSexe = sexe == 'M' ? SSMPalette.indigo : SSMPalette.teal;

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => Navigator.pushNamed(
          context,
          '/eleve/fiche',
          arguments: {'eleveId': eleveId},
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: Row(
            children: [
              SSMAvatar(
                nom: e['prenom'].toString(),
                photoUrl: photoUrl,
                sexe: sexe,
                rayon: 24,
                afficherBoutonCamera: true,
                onTap: () => _changerPhoto(eleveId),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e['nom']} ${e['prenom']}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Matricule : ${e['matricule']}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte2),
                    ),
                    const SizedBox(height: 4),
                    SSMPill.couleur(label: sexe == 'M' ? 'Masculin' : 'Féminin', couleur: couleurSexe),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableEleves() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn(''),
        SSMDataColumn('Élève'),
        SSMDataColumn('Matricule'),
        SSMDataColumn('Sexe'),
        SSMDataColumn(''),
      ],
      onLigneTap: (i) => Navigator.pushNamed(
        context,
        '/eleve/fiche',
        arguments: {'eleveId': _eleves[i]['id'] as int},
      ),
      lignes: [
        for (final e in _eleves) _ligneEleve(e as Map<String, dynamic>),
      ],
    );
  }

  List<Widget> _ligneEleve(Map<String, dynamic> e) {
    final sexe = e['sexe'] as String;
    final photoUrl = e['photo_url'] as String?;
    final couleurSexe = sexe == 'M' ? SSMPalette.indigo : SSMPalette.teal;

    return [
      SSMAvatar(nom: e['prenom'].toString(), photoUrl: photoUrl, sexe: sexe, rayon: 16),
      Text(
        '${e['nom']} ${e['prenom']}',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
      ),
      Text('${e['matricule']}', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: SSMPalette.texte3)),
      SSMPill.couleur(label: sexe == 'M' ? 'Masculin' : 'Féminin', couleur: couleurSexe),
      Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
    ];
  }
}
