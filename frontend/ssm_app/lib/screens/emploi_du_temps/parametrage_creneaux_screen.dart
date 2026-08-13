import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/emploi_du_temps_model.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// ══════════════════════════════════════════════════════════
// ParametrageCreneauxScreen — configuration initiale (une fois par
// école) de la grille horaire commune : créneaux (cours/récréation/
// pause) et jours travaillés.
// ══════════════════════════════════════════════════════════
class ParametrageCreneauxScreen extends StatefulWidget {
  const ParametrageCreneauxScreen({super.key});

  @override
  State<ParametrageCreneauxScreen> createState() => _ParametrageCreneauxScreenState();
}

class _ParametrageCreneauxScreenState extends State<ParametrageCreneauxScreen> {
  int? _anneeScolaireId;
  String? _anneeLibelle;
  List<CreneauHoraire> _creneaux = [];
  List<JourTravaille> _joursTravailles = [];
  final Set<JourSemaine> _joursEnCours = {};

  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  Future<void> _chargerTout() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final anneeData = await AnneeService.anneeActive();
      final annee = anneeData['annee'] as Map<String, dynamic>?;

      if (annee == null) {
        setState(() {
          _chargement = false;
          _erreur = "Aucune année scolaire active. Activez une année avant de configurer les créneaux horaires.";
        });
        return;
      }

      final anneeId = annee['id'] as int;
      final resultats = await Future.wait([
        EmploiDuTempsService.getCreneauxHoraires(anneeScolaireId: anneeId),
        EmploiDuTempsService.getJoursTravailles(anneeScolaireId: anneeId),
      ]);

      final creneaux = (resultats[0] as List<CreneauHoraire>)..sort((a, b) => a.ordre.compareTo(b.ordre));

      setState(() {
        _anneeScolaireId = anneeId;
        _anneeLibelle = annee['libelle'] as String?;
        _creneaux = creneaux;
        _joursTravailles = resultats[1] as List<JourTravaille>;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  bool _jourActif(JourSemaine jour) {
    return _joursTravailles.firstWhere(
      (j) => j.jour == jour,
      orElse: () => JourTravaille(jour: jour, actif: false),
    ).actif;
  }

  Future<void> _basculerJour(JourSemaine jour, bool actif) async {
    if (_anneeScolaireId == null || _joursEnCours.contains(jour)) return;

    setState(() {
      _joursEnCours.add(jour);
      _joursTravailles.removeWhere((j) => j.jour == jour);
      _joursTravailles.add(JourTravaille(jour: jour, actif: actif));
    });

    try {
      final maj = await EmploiDuTempsService.definirJourTravaille(jour, actif, anneeScolaireId: _anneeScolaireId!);
      setState(() {
        _joursTravailles.removeWhere((j) => j.jour == jour);
        _joursTravailles.add(maj);
      });
    } catch (e) {
      setState(() {
        _joursTravailles.removeWhere((j) => j.jour == jour);
        _joursTravailles.add(JourTravaille(jour: jour, actif: !actif));
      });
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _joursEnCours.remove(jour));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _vert),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: (_anneeScolaireId == null)
          ? null
          : FloatingActionButton.extended(
              onPressed: _ouvrirFormulaireCreneau,
              backgroundColor: _indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Ajouter un créneau',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _chargerTout,
                child: _chargement
                    ? const Center(child: CircularProgressIndicator(color: _indigo))
                    : _erreur != null
                        ? _vueErreur()
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              SSMSectionTitre(titre: 'Créneaux horaires'),
                              if (_creneaux.isEmpty) _etatVideCreneaux() else ..._creneaux.map(_carteCreneau),
                              const SizedBox(height: 28),
                              SSMSectionTitre(titre: 'Jours travaillés'),
                              _carteJoursTravailles(),
                              const SizedBox(height: 90),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.canPop(context)
                    ? Navigator.pop(context)
                    : Navigator.pushReplacementNamed(context, '/tableau-de-bord'),
              ),
              const SizedBox(width: 4),
              Text('Retour', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Grille horaire', style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            _anneeLibelle != null
                ? "Configuration des créneaux et jours travaillés — $_anneeLibelle"
                : 'Configuration des créneaux et jours travaillés',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _vueErreur() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _rouge, size: 36),
          const SizedBox(height: 10),
          Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _chargerTout,
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _etatVideCreneaux() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.schedule_outlined, size: 56, color: _gris),
            const SizedBox(height: 12),
            Text('Aucun créneau horaire configuré', style: GoogleFonts.inter(fontSize: 14, color: _texte)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CRÉNEAUX
  // ══════════════════════════════════════════════════════

  Widget _carteCreneau(CreneauHoraire creneau) {
    final estCours = creneau.type == TypeCreneau.cours;
    final couleur = estCours ? _indigo : (creneau.type == TypeCreneau.recreation ? _ambre : _gris);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: couleur, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(estCours ? Icons.menu_book_outlined : Icons.free_breakfast_outlined, color: couleur, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${creneau.heureDebut} - ${creneau.heureFin}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
                    const SizedBox(height: 2),
                    Text(creneau.libelle, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  ],
                ),
              ),
              SSMBadge(
                label: creneau.type.libelle,
                couleur: estCours ? SSMBadge.info : (creneau.type == TypeCreneau.recreation ? SSMBadge.ambre : _gris),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // JOURS TRAVAILLÉS
  // ══════════════════════════════════════════════════════

  Widget _carteJoursTravailles() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: JourSemaine.values.map((jour) {
          final actif = _jourActif(jour);
          final enCours = _joursEnCours.contains(jour);
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(jour.libelle, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
            value: actif,
            activeThumbColor: _indigo,
            onChanged: enCours ? null : (valeur) => _basculerJour(jour, valeur),
            secondary: enCours
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FORMULAIRE AJOUT CRÉNEAU
  // ══════════════════════════════════════════════════════

  Future<void> _ouvrirFormulaireCreneau() async {
    final libelleController = TextEditingController();
    TimeOfDay? heureDebut;
    TimeOfDay? heureFin;
    TypeCreneau type = TypeCreneau.cours;
    bool enregistrement = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          String formatHeure(TimeOfDay? t) =>
              t == null ? '--:--' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          CreneauHoraire? apercu;
          if (heureDebut != null && heureFin != null) {
            apercu = CreneauHoraire(
              libelle: libelleController.text,
              heureDebut: formatHeure(heureDebut),
              heureFin: formatHeure(heureFin),
              ordre: _creneaux.length + 1,
              type: type,
            );
          }
          final chevauche = apercu != null && _creneaux.any((c) => c.chevaucheAvec(apercu!));
          final heuresValides = heureDebut != null &&
              heureFin != null &&
              formatHeure(heureFin).compareTo(formatHeure(heureDebut)) > 0;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouveau créneau',
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: libelleController,
                      decoration: InputDecoration(
                        labelText: 'Libellé *',
                        hintText: 'ex: 1ère heure, Récréation matin...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: heureDebut ?? const TimeOfDay(hour: 8, minute: 0),
                              );
                              if (t != null) setStateDialog(() => heureDebut = t);
                            },
                            child: Text('Début : ${formatHeure(heureDebut)}', style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: heureFin ?? const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (t != null) setStateDialog(() => heureFin = t);
                            },
                            child: Text('Fin : ${formatHeure(heureFin)}', style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                    if (heureDebut != null && heureFin != null && !heuresValides) ...[
                      const SizedBox(height: 8),
                      Text("L'heure de fin doit être après l'heure de début.",
                          style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<TypeCreneau>(
                      value: type,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: TypeCreneau.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.libelle)))
                          .toList(),
                      onChanged: (t) => setStateDialog(() => type = t ?? TypeCreneau.cours),
                    ),
                    if (chevauche) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _ambre.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _ambre.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: _ambre, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Ce créneau chevauche un créneau déjà configuré.',
                                  style: GoogleFonts.inter(fontSize: 12, color: _ambre)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: (enregistrement || !heuresValides || chevauche || libelleController.text.trim().isEmpty)
                                ? null
                                : () async {
                                    setStateDialog(() => enregistrement = true);
                                    try {
                                      await EmploiDuTempsService.creerCreneauHoraire(
                                        CreneauHoraire(
                                          libelle: libelleController.text.trim(),
                                          heureDebut: formatHeure(heureDebut),
                                          heureFin: formatHeure(heureFin),
                                          ordre: _creneaux.length + 1,
                                          type: type,
                                        ),
                                        anneeScolaireId: _anneeScolaireId!,
                                      );
                                      if (context.mounted) Navigator.pop(context);
                                      _afficherSucces('Créneau créé avec succès');
                                      _chargerTout();
                                    } catch (e) {
                                      setStateDialog(() => enregistrement = false);
                                      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                    }
                                  },
                            child: enregistrement
                                ? const SizedBox(
                                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Créer'),
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

    libelleController.dispose();
  }
}
