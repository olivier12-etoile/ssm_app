import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/classe_service.dart';
import '../../services/eleve_service.dart';
import '../../services/notification_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'notifications_attente_screen.dart';

InputDecoration _decorationChamp(String label, {IconData? icone, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
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

// Met en surbrillance les {variables} détectées dans le texte du message,
// sans dépendance externe (surcharge de buildTextSpan).
class _ControleurVariables extends TextEditingController {
  static final RegExp _motif = RegExp(r'\{[a-zA-Z0-9_]+\}');

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

// Catégories autorisées pour un rôle non-directeur (null = directeur/super_admin,
// aucune restriction, message libre autorisé). Reflète exactement la règle
// appliquée côté API par NotificationController::verifierPermission().
List<CategorieNotification>? _categoriesAutorisees(Utilisateur u) {
  if (u.estDirecteur || u.estSuperAdmin) return null;
  if (u.estCenseur) return [CategorieNotification.scolarite];
  if (u.estSecretaire) return [CategorieNotification.administration, CategorieNotification.presence];
  if (u.estComptable) return [CategorieNotification.finances];
  return [];
}

class NouvelleNotificationScreen extends StatefulWidget {
  const NouvelleNotificationScreen({super.key});

  @override
  State<NouvelleNotificationScreen> createState() => _NouvelleNotificationScreenState();
}

class _NouvelleNotificationScreenState extends State<NouvelleNotificationScreen> {
  Utilisateur? _utilisateur;
  bool _chargementInitial = true;
  int _etape = 0;

  // ── Étape 1 : contenu ──
  bool _utiliserModele = true;
  List<ModeleMessage> _modeles = [];
  ModeleMessage? _modeleSelectionne;
  final _titreController = TextEditingController();
  final _messageController = _ControleurVariables();

  // ── Étape 2 : ciblage ──
  TypeCible? _typeCible;
  List<dynamic> _classes = [];
  int? _classeSelectionneeId;
  final Set<int> _classesSelectionneesIds = {};
  final _rechercheEleveController = TextEditingController();
  Timer? _debounceRecherche;
  List<dynamic> _resultatsRechercheEleve = [];
  bool _rechercheEnCours = false;
  Map<String, dynamic>? _eleveSelectionne;
  int? _nombreDestinataires;
  bool _chargementApercu = false;

  // ── Étape 3 : envoi ──
  CanalNotification _canal = CanalNotification.whatsapp;
  bool _urgent = false;
  bool _programmee = false;
  DateTime? _dateEnvoiProgrammee;

  bool _envoiEnCours = false;
  String? _erreur;

  bool get _estAutorise => !(_utilisateur?.estEnseignant ?? true);
  List<CategorieNotification>? get _categoriesAutoriseesRole =>
      _utilisateur != null ? _categoriesAutorisees(_utilisateur!) : [];
  bool get _messageLibreAutorise => _categoriesAutoriseesRole == null;

  List<ModeleMessage> get _modelesDisponibles {
    final categories = _categoriesAutoriseesRole;
    final actifs = _modeles.where((m) => m.actif);
    if (categories == null) return actifs.toList();
    return actifs.where((m) => categories.contains(m.categorie)).toList();
  }

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _messageController.dispose();
    _rechercheEleveController.dispose();
    _debounceRecherche?.cancel();
    super.dispose();
  }

  Future<void> _initialiser() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (!mounted) return;
    // _utiliserModele démarre à true (valeur par défaut) : pour les rôles
    // restreints, le "Message libre" reste simplement inatteignable (le
    // sélecteur est masqué, voir _messageLibreAutorise).
    setState(() => _utilisateur = utilisateur);

    if (utilisateur == null || utilisateur.estEnseignant) {
      setState(() => _chargementInitial = false);
      return;
    }

    try {
      final resultats = await Future.wait([
        NotificationService.getModeles(),
        ClasseService.listerClasses(),
      ]);
      if (!mounted) return;
      setState(() {
        _modeles = resultats[0] as List<ModeleMessage>;
        _classes = resultats[1];
        _chargementInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementInitial = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
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

  // ── Sélection d'un modèle ──
  void _selectionnerModele(ModeleMessage? modele) {
    setState(() {
      _modeleSelectionne = modele;
      if (modele != null) {
        _titreController.text = modele.nom;
        _messageController.text = modele.contenu;
      }
    });
  }

  // ── Ciblage : cibles JSON envoyées à l'API ──
  Map<String, dynamic> _ciblesActuelles() {
    switch (_typeCible) {
      case TypeCible.classe:
        return _classeSelectionneeId != null ? {'classe_id': _classeSelectionneeId} : {};
      case TypeCible.plusieursClasses:
        return _classesSelectionneesIds.isNotEmpty ? {'classe_ids': _classesSelectionneesIds.toList()} : {};
      case TypeCible.eleve:
        return _eleveSelectionne != null ? {'eleve_id': _eleveSelectionne!['id']} : {};
      default:
        return {};
    }
  }

  bool get _ciblageComplet {
    switch (_typeCible) {
      case null:
        return false;
      case TypeCible.classe:
        return _classeSelectionneeId != null;
      case TypeCible.plusieursClasses:
        return _classesSelectionneesIds.isNotEmpty;
      case TypeCible.eleve:
        return _eleveSelectionne != null;
      default:
        return true;
    }
  }

  Future<void> _rafraichirApercuDestinataires() async {
    if (_typeCible == null || !_ciblageComplet) {
      setState(() => _nombreDestinataires = null);
      return;
    }
    setState(() => _chargementApercu = true);
    try {
      final nombre = await NotificationService.apercuDestinataires(
        typeCible: _typeCible!,
        cibles: _ciblesActuelles(),
      );
      if (!mounted) return;
      setState(() {
        _nombreDestinataires = nombre;
        _chargementApercu = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementApercu = false);
    }
  }

  void _choisirTypeCible(TypeCible type) {
    setState(() {
      _typeCible = type;
      _classeSelectionneeId = null;
      _classesSelectionneesIds.clear();
      _eleveSelectionne = null;
      _resultatsRechercheEleve = [];
      _nombreDestinataires = null;
    });
    _rafraichirApercuDestinataires();
  }

  void _rechercherEleves(String texte) {
    _debounceRecherche?.cancel();
    if (texte.trim().length < 2) {
      setState(() => _resultatsRechercheEleve = []);
      return;
    }
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _rechercheEnCours = true);
      try {
        final resultat = await EleveService.lister(recherche: texte.trim());
        if (!mounted) return;
        setState(() {
          _resultatsRechercheEleve = (resultat['data'] as List?) ?? [];
          _rechercheEnCours = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _rechercheEnCours = false);
      }
    });
  }

  // ── Aperçu du message rendu ──
  bool get _messageContientVariables => RegExp(r'\{[a-zA-Z0-9_]+\}').hasMatch(_messageController.text);

  Future<void> _ouvrirApercuMessage() async {
    int? eleveId = _eleveSelectionne?['id'] as int?;
    eleveId ??= await _choisirEleveExemple();
    if (eleveId == null) return;

    try {
      final resultat = await NotificationService.apercuMessage(
        contenu: _messageController.text,
        eleveIdExemple: eleveId,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SSMPanel(
              titre: 'Aperçu — ${resultat['eleve']}',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      resultat['apercu'] as String? ?? '',
                      style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: SSMPalette.texte1),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<int?> _choisirEleveExemple() async {
    final controleur = TextEditingController();
    List<dynamic> resultats = [];
    bool recherche = false;
    Timer? debounce;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> chercher(String texte) async {
            debounce?.cancel();
            if (texte.trim().length < 2) {
              setDialogState(() => resultats = []);
              return;
            }
            debounce = Timer(const Duration(milliseconds: 400), () async {
              setDialogState(() => recherche = true);
              try {
                final r = await EleveService.lister(recherche: texte.trim());
                setDialogState(() {
                  resultats = (r['data'] as List?) ?? [];
                  recherche = false;
                });
              } catch (_) {
                setDialogState(() => recherche = false);
              }
            });
          }

          return AlertDialog(
            title: Text('Choisir un élève exemple', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
            content: SizedBox(
              width: 360,
              height: 320,
              child: Column(
                children: [
                  TextField(
                    controller: controleur,
                    autofocus: true,
                    decoration: _decorationChamp('Nom, prénom ou matricule', icone: Icons.search),
                    onChanged: chercher,
                  ),
                  const SizedBox(height: 8),
                  if (recherche) const LinearProgressIndicator(color: SSMPalette.indigo),
                  Expanded(
                    child: ListView.builder(
                      itemCount: resultats.length,
                      itemBuilder: (context, i) {
                        final e = resultats[i] as Map<String, dynamic>;
                        final classe = (e['classe_actuelle'] as Map<String, dynamic>?)?['nom'];
                        return ListTile(
                          title: Text('${e['nom']} ${e['prenom']}'),
                          subtitle: Text(classe != null ? '$classe · ${e['matricule'] ?? ''}' : '${e['matricule'] ?? ''}'),
                          onTap: () => Navigator.pop(context, e['id'] as int),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ],
          );
        },
      ),
    );
  }

  // ── Validation par étape ──
  bool get _etape1Valide => _titreController.text.trim().isNotEmpty && _messageController.text.trim().isNotEmpty;
  bool get _etape2Valide => _typeCible != null && _ciblageComplet;
  bool get _etape3Valide => !_programmee || _dateEnvoiProgrammee != null;

  void _suivant() {
    if (_etape == 0 && !_etape1Valide) {
      _afficherErreur('Renseignez un titre et un message.');
      return;
    }
    if (_etape == 1 && !_etape2Valide) {
      _afficherErreur('Choisissez une cible complète.');
      return;
    }
    setState(() => _etape++);
  }

  void _precedent() => setState(() => _etape--);

  Future<void> _choisirDateProgrammation() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final heure = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (heure == null) return;
    setState(() {
      _dateEnvoiProgrammee = DateTime(date.year, date.month, date.day, heure.hour, heure.minute);
    });
  }

  Future<void> _confirmerEtEnvoyer() async {
    if (!_etape3Valide) {
      _afficherErreur('Choisissez une date de programmation.');
      return;
    }

    if (_nombreDestinataires != null && _nombreDestinataires! > 10) {
      final n = _nombreDestinataires!;
      final grandVolume = n > 50;
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmation', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          content: SizedBox(
            width: 380,
            child: SSMAlertItem(
              type: grandVolume ? SSMAlerteType.danger : SSMAlerteType.avertissement,
              icone: grandVolume ? Icons.error_outline : Icons.warning_amber_rounded,
              titre: 'Envoi à $n destinataires',
              sousTitre: "Cette notification sera envoyée à $n destinataires. Cette action ne peut pas être annulée.",
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirme != true) return;
    }

    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });

    final notification = NotificationSSM(
      titre: _titreController.text.trim(),
      message: _messageController.text.trim(),
      modeleMessageId: _modeleSelectionne?.id,
      typeCible: _typeCible!,
      cibles: _ciblesActuelles(),
      canal: _canal,
      urgent: _urgent,
      programmee: _programmee,
      dateEnvoiPrevue: _programmee ? _dateEnvoiProgrammee : null,
    );

    try {
      await NotificationService.creerNotification(notification);
      if (!mounted) return;
      setState(() => _envoiEnCours = false);

      if (_programmee) {
        _afficherSucces('Notification programmée avec succès.');
        Navigator.pop(context, true);
        return;
      }

      if (_canal == CanalNotification.whatsapp) {
        _afficherSucces('Notification créée — envoi WhatsApp à finaliser via la chaîne.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsAttenteScreen()),
        );
        return;
      }

      _afficherSucces('Notification envoyée avec succès.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
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
            SSMSousEnTete(titre: 'Nouvelle notification', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargementInitial
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : !_estAutorise
                      ? _vueNonAutorise()
                      : Column(
                          children: [
                            _indicateurEtapes(),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: switch (_etape) {
                                  0 => _etapeContenu(),
                                  1 => _etapeCiblage(),
                                  _ => _etapeEnvoi(),
                                },
                              ),
                            ),
                            _barreNavigation(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueNonAutorise() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, color: SSMPalette.texte3, size: 40),
            const SizedBox(height: 12),
            Text(
              "Vous n'êtes pas autorisé à envoyer de notification libre.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: SSMPalette.texte2),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Indicateur d'étapes
  // ══════════════════════════════════════════════════════
  Widget _indicateurEtapes() {
    const labels = ['Contenu', 'Ciblage', 'Envoi'];
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        children: List.generate(labels.length, (i) {
          final actif = i == _etape;
          final complet = i < _etape;
          final couleur = actif || complet ? SSMPalette.indigo : SSMPalette.texte3;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: couleur,
                  child: complet
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${i + 1}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labels[i],
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: couleur),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < labels.length - 1) Container(width: 16, height: 2, color: complet ? SSMPalette.indigo : SSMPalette.bordure),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _barreNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: SSMPalette.blanc,
        border: Border(top: BorderSide(color: SSMPalette.bordure)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_etape > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _envoiEnCours ? null : _precedent,
                  child: const Text('Précédent'),
                ),
              ),
            if (_etape > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SSMPalette.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                ),
                onPressed: _envoiEnCours
                    ? null
                    : (_etape < 2 ? _suivant : _confirmerEtEnvoyer),
                child: _envoiEnCours
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_etape < 2 ? 'Suivant' : (_programmee ? 'Programmer' : 'Envoyer')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Étape 1 — Contenu
  // ══════════════════════════════════════════════════════
  Widget _etapeContenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titreSection('Source du message'),
        if (_messageLibreAutorise)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  selected: _utiliserModele,
                  onSelected: (_) => setState(() => _utiliserModele = true),
                  label: const Text('Utiliser un modèle'),
                  selectedColor: SSMPalette.indigo,
                  backgroundColor: const Color(0xFFF3F4F6),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                  labelStyle: GoogleFonts.inter(color: _utiliserModele ? Colors.white : SSMPalette.texte2, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  selected: !_utiliserModele,
                  onSelected: (_) => setState(() {
                    _utiliserModele = false;
                    _modeleSelectionne = null;
                  }),
                  label: const Text('Message libre'),
                  selectedColor: SSMPalette.indigo,
                  backgroundColor: const Color(0xFFF3F4F6),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                  labelStyle: GoogleFonts.inter(color: !_utiliserModele ? Colors.white : SSMPalette.texte2, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SSMPalette.tealClair, borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            child: Text(
              'Votre rôle vous limite à des modèles prédéfinis pour cette catégorie.',
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.teal),
            ),
          ),
        if (_utiliserModele) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<ModeleMessage>(
            initialValue: _modeleSelectionne,
            isExpanded: true,
            decoration: _decorationChamp('Modèle de message', icone: Icons.article_outlined),
            hint: const Text('Choisir un modèle'),
            items: _modelesDisponibles.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text('${m.categorie.libelle} — ${m.nom}', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _selectionnerModele,
          ),
        ],
        const SizedBox(height: 20),
        _titreSection('Titre'),
        TextField(
          controller: _titreController,
          style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
          decoration: _decorationChamp('Titre de la notification *', icone: Icons.title),
        ),
        const SizedBox(height: 20),
        _titreSection('Message'),
        TextField(
          controller: _messageController,
          maxLines: 8,
          minLines: 4,
          style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: SSMPalette.texte1),
          decoration: _decorationChamp(
            'Message *',
            hint: 'Utilisez {parent}, {eleve}, {classe}... pour personnaliser automatiquement.',
          ).copyWith(alignLabelWithHint: true),
        ),
        if (_messageContientVariables) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _ouvrirApercuMessage,
            style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.teal, side: const BorderSide(color: SSMPalette.teal)),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Aperçu avec un élève exemple'),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // Étape 2 — Ciblage
  // ══════════════════════════════════════════════════════
  Widget _etapeCiblage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titreSection('Type de cible'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TypeCible.values.map((type) {
            final selectionne = _typeCible == type;
            return ChoiceChip(
              selected: selectionne,
              onSelected: (_) => _choisirTypeCible(type),
              avatar: Icon(type.icone, size: 16, color: selectionne ? Colors.white : SSMPalette.indigo),
              label: Text(type.libelle),
              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: selectionne ? Colors.white : SSMPalette.texte2),
              selectedColor: SSMPalette.indigo,
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (_typeCible == TypeCible.classe) ...[
          _titreSection('Classe'),
          DropdownButtonFormField<int>(
            initialValue: _classeSelectionneeId,
            isExpanded: true,
            decoration: _decorationChamp('Choisir une classe', icone: Icons.class_outlined),
            items: _classes.map((c) {
              return DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String));
            }).toList(),
            onChanged: (v) {
              setState(() => _classeSelectionneeId = v);
              _rafraichirApercuDestinataires();
            },
          ),
        ],
        if (_typeCible == TypeCible.plusieursClasses) ...[
          _titreSection('Classes (${_classesSelectionneesIds.length} sélectionnée(s))'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _classes.map((c) {
              final id = c['id'] as int;
              final selectionne = _classesSelectionneesIds.contains(id);
              return FilterChip(
                selected: selectionne,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _classesSelectionneesIds.add(id);
                    } else {
                      _classesSelectionneesIds.remove(id);
                    }
                  });
                  _rafraichirApercuDestinataires();
                },
                label: Text(c['nom'] as String),
                selectedColor: SSMPalette.indigo.withValues(alpha: 0.15),
                checkmarkColor: SSMPalette.indigo,
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                labelStyle: GoogleFonts.inter(fontSize: 12, color: selectionne ? SSMPalette.indigo : SSMPalette.texte2, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ],
        if (_typeCible == TypeCible.eleve) ...[
          _titreSection('Élève'),
          if (_eleveSelectionne != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: SSMPalette.indigoClair, borderRadius: BorderRadius.circular(SSMRayons.moyen)),
              child: Row(
                children: [
                  const Icon(Icons.person, color: SSMPalette.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_eleveSelectionne!['nom']} ${_eleveSelectionne!['prenom']}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SSMPalette.rouge),
                    onPressed: () {
                      setState(() {
                        _eleveSelectionne = null;
                        _nombreDestinataires = null;
                      });
                    },
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _rechercheEleveController,
              decoration: _decorationChamp('Rechercher par nom ou matricule', icone: Icons.search).copyWith(
                suffixIcon: _rechercheEnCours
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)),
                      )
                    : null,
              ),
              onChanged: _rechercherEleves,
            ),
            if (_resultatsRechercheEleve.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: SSMPalette.blanc,
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  border: Border.all(color: SSMPalette.bordure),
                  boxShadow: SSMOmbres.legere,
                ),
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resultatsRechercheEleve.length,
                  itemBuilder: (context, i) {
                    final e = _resultatsRechercheEleve[i] as Map<String, dynamic>;
                    final classe = (e['classe_actuelle'] as Map<String, dynamic>?)?['nom'];
                    return ListTile(
                      leading: const Icon(Icons.person_outline, color: SSMPalette.indigo),
                      title: Text('${e['nom']} ${e['prenom']}'),
                      subtitle: Text([?classe, ?e['matricule']].join(' · ')),
                      onTap: () {
                        setState(() {
                          _eleveSelectionne = e;
                          _resultatsRechercheEleve = [];
                          _rechercheEleveController.clear();
                        });
                        _rafraichirApercuDestinataires();
                      },
                    );
                  },
                ),
              ),
          ],
        ],
        const SizedBox(height: 20),
        if (_typeCible != null) _carteApercuDestinataires(),
      ],
    );
  }

  Widget _carteApercuDestinataires() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SSMPalette.indigoClair, borderRadius: BorderRadius.circular(SSMRayons.grand)),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: SSMPalette.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: _chargementApercu
                ? Text('Calcul en cours…', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2))
                : Text(
                    _nombreDestinataires != null
                        ? '$_nombreDestinataires destinataire(s) concerné(s)'
                        : 'Complétez le ciblage pour voir le nombre de destinataires.',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Étape 3 — Envoi
  // ══════════════════════════════════════════════════════
  Widget _etapeEnvoi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titreSection('Canal'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CanalNotification.values.map((canal) {
            final disponible = canal == CanalNotification.whatsapp || canal == CanalNotification.interne;
            final selectionne = _canal == canal;
            return Opacity(
              opacity: disponible ? 1 : 0.4,
              child: Tooltip(
                message: disponible ? '' : 'Non disponible pour le moment',
                child: ChoiceChip(
                  selected: selectionne,
                  onSelected: disponible ? (_) => setState(() => _canal = canal) : null,
                  avatar: Icon(canal.icone, size: 16, color: selectionne ? Colors.white : canal.couleur),
                  label: Text(canal.libelle),
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: selectionne ? Colors.white : SSMPalette.texte2),
                  selectedColor: canal.couleur,
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _urgent,
          onChanged: (v) => setState(() => _urgent = v),
          activeThumbColor: SSMPalette.rouge,
          title: const Text('Urgent'),
          subtitle: const Text('Signale la notification comme prioritaire'),
        ),
        if (_urgent)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: SSMPalette.rougeClair, borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            child: Row(
              children: [
                const Icon(Icons.priority_high, color: SSMPalette.rouge),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cette notification sera marquée URGENTE.',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.rouge),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 28, color: SSMPalette.bordure),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _programmee,
          onChanged: (v) => setState(() {
            _programmee = v;
            if (!v) _dateEnvoiProgrammee = null;
          }),
          activeThumbColor: SSMPalette.indigo,
          title: const Text("Programmer l'envoi"),
          subtitle: const Text("Envoyer à une date/heure ultérieure"),
        ),
        if (_programmee)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: SSMPalette.indigo),
            title: Text(_dateEnvoiProgrammee != null
                ? '${_dateEnvoiProgrammee!.day}/${_dateEnvoiProgrammee!.month}/${_dateEnvoiProgrammee!.year} à '
                    '${_dateEnvoiProgrammee!.hour.toString().padLeft(2, '0')}:${_dateEnvoiProgrammee!.minute.toString().padLeft(2, '0')}'
                : 'Choisir une date et une heure'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _choisirDateProgrammation,
          ),
        const SizedBox(height: 20),
        if (_typeCible != null) _carteApercuDestinataires(),
        if (_erreur != null) ...[
          const SizedBox(height: 16),
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
      ],
    );
  }
}
