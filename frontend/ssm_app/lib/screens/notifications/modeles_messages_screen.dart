import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

// Couleurs de catégorie alignées sur la palette générale du thème (indigo /
// teal / ambre / rouge uniquement — voir SSMPalette).
const Map<CategorieNotification, Color> _couleursCategorie = {
  CategorieNotification.scolarite: SSMPalette.indigo,
  CategorieNotification.finances: SSMPalette.teal,
  CategorieNotification.presence: SSMPalette.ambre,
  CategorieNotification.administration: SSMPalette.indigo,
  CategorieNotification.discipline: SSMPalette.rouge,
  CategorieNotification.vieScolaire: SSMPalette.teal,
};

InputDecoration _decorationChamp(String label, {IconData? icone}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    prefixIcon: icone != null ? Icon(icone, size: 20, color: SSMPalette.texte3) : null,
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

// Variables couramment proposées à l'insertion rapide dans un modèle
// (union des variables utilisées par les modèles système du seeder).
const List<String> _variablesCourantes = [
  'parent', 'eleve', 'classe', 'periode', 'moyenne', 'mention',
  'montant', 'tranche', 'montant_restant', 'date_echeance', 'date', 'heure', 'ecole',
];

// Met en surbrillance les {variables} détectées dans le contenu du modèle.
class _ControleurVariables extends TextEditingController {
  static final RegExp _motif = RegExp(r'\{[a-zA-Z0-9_]+\}');

  _ControleurVariables({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final spans = <TextSpan>[];
    text.splitMapJoin(
      _motif,
      onMatch: (m) {
        spans.add(TextSpan(
          text: m[0],
          style: (style ?? const TextStyle()).copyWith(
            color: SSMPalette.ambre,
            fontWeight: FontWeight.w700,
            backgroundColor: SSMPalette.ambre.withValues(alpha: 0.14),
          ),
        ));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(text: n, style: style));
        return '';
      },
    );
    return TextSpan(style: style, children: spans);
  }
}

// ══════════════════════════════════════════════════════════
// Liste des modèles de messages, groupés par catégorie.
// ══════════════════════════════════════════════════════════
class ModelesMessagesScreen extends StatefulWidget {
  const ModelesMessagesScreen({super.key});

  @override
  State<ModelesMessagesScreen> createState() => _ModelesMessagesScreenState();
}

class _ModelesMessagesScreenState extends State<ModelesMessagesScreen> {
  List<ModeleMessage> _modeles = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final modeles = await NotificationService.getModeles();
      if (!mounted) return;
      setState(() {
        _modeles = modeles;
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

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge));
  }

  Future<void> _ouvrirFormulaire({ModeleMessage? modele}) async {
    final resultat = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _FormulaireModeleScreen(modele: modele)),
    );
    if (resultat == true) _charger();
  }

  void _ouvrirLectureSeule(ModeleMessage m) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(m.nom, style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(SSMRayons.petit)),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: SSMPalette.texte3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modèle système, non modifiable',
                        style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
              Text(m.contenu, style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: SSMPalette.texte1)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _supprimer(ModeleMessage m) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce modèle ?'),
        content: Text('« ${m.nom} » sera définitivement supprimé. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await NotificationService.supprimerModele(m.id!);
      _charger();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Map<CategorieNotification, List<ModeleMessage>> get _modelesParCategorie {
    final regroupes = <CategorieNotification, List<ModeleMessage>>{};
    for (final m in _modeles) {
      regroupes.putIfAbsent(m.categorie, () => []).add(m);
    }
    return regroupes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Modèles de messages', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? Center(child: Text(_erreur!, style: GoogleFonts.inter(color: SSMPalette.rouge)))
                      : _modeles.isEmpty
                          ? Center(
                              child: Text('Aucun modèle enregistré pour le moment.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                            )
                          : RefreshIndicator(
                              onRefresh: _charger,
                              color: SSMPalette.indigo,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  for (final categorie in CategorieNotification.values)
                                    if (_modelesParCategorie[categorie]?.isNotEmpty ?? false) ...[
                                      _sectionCategorie(categorie, _modelesParCategorie[categorie]!),
                                      const SizedBox(height: 16),
                                    ],
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4, right: 4),
        child: SSMQuickActionButton(
          icone: Icons.add,
          label: 'Nouveau modèle',
          variante: SSMActionVariante.primaire,
          onTap: () => _ouvrirFormulaire(),
        ),
      ),
    );
  }

  Widget _sectionCategorie(CategorieNotification categorie, List<ModeleMessage> modeles) {
    final couleur = _couleursCategorie[categorie] ?? SSMPalette.indigo;
    return SSMPanel(
      titre: categorie.libelle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(SSMRayons.petit)),
                child: Icon(categorie.icone, size: 14, color: couleur),
              ),
              const SizedBox(width: 8),
              Text('${modeles.length} modèle(s)', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
            ],
          ),
          const SizedBox(height: 10),
          ...modeles.map(_carteModele),
        ],
      ),
    );
  }

  Widget _carteModele(ModeleMessage m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        child: InkWell(
          borderRadius: BorderRadius.circular(SSMRayons.moyen),
          onTap: () => m.modifiable ? _ouvrirFormulaire(modele: m) : _ouvrirLectureSeule(m),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(m.nom, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    ),
                    if (!m.modifiable) SSMPill.couleur(label: 'Système', couleur: SSMPalette.texte2),
                    if (!m.actif) ...[
                      const SizedBox(width: 6),
                      SSMPill.couleur(label: 'Inactif', couleur: SSMPalette.rouge),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  m.contenu,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2, height: 1.4),
                ),
                if (m.modifiable) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _ouvrirFormulaire(modele: m),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifier'),
                        style: TextButton.styleFrom(foregroundColor: SSMPalette.indigo),
                      ),
                      TextButton.icon(
                        onPressed: () => _supprimer(m),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Supprimer'),
                        style: TextButton.styleFrom(foregroundColor: SSMPalette.rouge),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Formulaire de création/édition d'un modèle.
// ══════════════════════════════════════════════════════════
class _FormulaireModeleScreen extends StatefulWidget {
  final ModeleMessage? modele;
  const _FormulaireModeleScreen({this.modele});

  @override
  State<_FormulaireModeleScreen> createState() => _FormulaireModeleScreenState();
}

class _FormulaireModeleScreenState extends State<_FormulaireModeleScreen> {
  late final TextEditingController _nomController;
  late final _ControleurVariables _contenuController;
  final _contenuFocusNode = FocusNode();
  late CategorieNotification _categorie;
  late bool _actif;
  bool _enregistrement = false;
  String? _erreur;

  bool get _modification => widget.modele != null;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.modele?.nom ?? '');
    _contenuController = _ControleurVariables(text: widget.modele?.contenu ?? '');
    _categorie = widget.modele?.categorie ?? CategorieNotification.vieScolaire;
    _actif = widget.modele?.actif ?? true;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _contenuController.dispose();
    _contenuFocusNode.dispose();
    super.dispose();
  }

  void _insererVariable(String variable) {
    final texte = _contenuController.text;
    final selection = _contenuController.selection;
    final insertion = '{$variable}';

    final debut = selection.start >= 0 ? selection.start : texte.length;
    final fin = selection.end >= 0 ? selection.end : texte.length;

    final nouveauTexte = texte.replaceRange(debut, fin, insertion);
    _contenuController.text = nouveauTexte;
    _contenuController.selection = TextSelection.collapsed(offset: debut + insertion.length);
    _contenuFocusNode.requestFocus();
  }

  Future<void> _enregistrer() async {
    if (_nomController.text.trim().isEmpty || _contenuController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nom et le contenu sont obligatoires.');
      return;
    }

    setState(() {
      _enregistrement = true;
      _erreur = null;
    });

    final variables = RegExp(r'\{([a-zA-Z0-9_]+)\}')
        .allMatches(_contenuController.text)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();

    final modele = ModeleMessage(
      nom: _nomController.text.trim(),
      categorie: _categorie,
      contenu: _contenuController.text.trim(),
      variablesDisponibles: variables,
      actif: _actif,
    );

    try {
      if (_modification) {
        await NotificationService.modifierModele(widget.modele!.id!, modele);
      } else {
        await NotificationService.creerModele(modele);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _enregistrement = false;
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
            SSMSousEnTete(
              titre: _modification ? 'Modifier le modèle' : 'Nouveau modèle',
              onRetour: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nomController,
                    style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
                    decoration: _decorationChamp('Nom *', icone: Icons.label_outline),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CategorieNotification>(
                    initialValue: _categorie,
                    decoration: _decorationChamp('Catégorie *', icone: Icons.category_outlined),
                    items: CategorieNotification.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.libelle)))
                        .toList(),
                    onChanged: (v) => setState(() => _categorie = v ?? _categorie),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'VARIABLES DISPONIBLES — TOUCHEZ POUR INSÉRER',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _variablesCourantes.map((v) {
                      return ActionChip(
                        label: Text('{$v}', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: SSMPalette.ambreClair,
                        labelStyle: const TextStyle(color: SSMPalette.ambre),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                        onPressed: () => _insererVariable(v),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contenuController,
                    focusNode: _contenuFocusNode,
                    maxLines: 10,
                    minLines: 6,
                    style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: SSMPalette.texte1),
                    decoration: _decorationChamp('Contenu *').copyWith(alignLabelWithHint: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _actif,
                    onChanged: (v) => setState(() => _actif = v),
                    activeThumbColor: SSMPalette.teal,
                    title: const Text('Actif'),
                    subtitle: const Text('Un modèle inactif ne peut plus être sélectionné pour un envoi.'),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: SSMPalette.rougeClair, borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: SSMPalette.rouge, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_erreur!, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.rouge))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                      onPressed: _enregistrement ? null : _enregistrer,
                      child: _enregistrement
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
}
