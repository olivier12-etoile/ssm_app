import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/emploi_du_temps_model.dart';
import '../../models/dashboard_emploi_du_temps_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/affectation_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/dashboard_emploi_du_temps_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatDateAffichage(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════
// RemplacementScreen — liste + création des remplacements ponctuels
// d'enseignant sur une séance.
// ══════════════════════════════════════════════════════════
class RemplacementScreen extends StatefulWidget {
  const RemplacementScreen({super.key});

  @override
  State<RemplacementScreen> createState() => _RemplacementScreenState();
}

class _RemplacementScreenState extends State<RemplacementScreen> {
  List<Map<String, dynamic>> _remplacements = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _enseignants = [];

  DateTime? _filtreDate;
  int? _filtreEnseignantId;
  int? _filtreClasseId;

  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerFiltres();
    _charger();
  }

  Future<void> _chargerFiltres() async {
    try {
      final resultats = await Future.wait([ClasseService.lister(), AffectationService.listerEnseignants()]);
      final classesParCycle = resultats[0] as Map<String, dynamic>;
      setState(() {
        _classes = classesParCycle.values.expand((l) => (l as List).map((c) => c as Map<String, dynamic>)).toList();
        _enseignants = (resultats[1] as List).map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (_) {
      // Les filtres restent simplement vides si non chargés.
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final remplacements = await DashboardEmploiDuTempsService.getRemplacements(
        date: _filtreDate != null ? EvenementCalendrier.formatDate(_filtreDate!) : null,
        enseignantId: _filtreEnseignantId,
        classeId: _filtreClasseId,
      );
      setState(() {
        _remplacements = remplacements;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _ouvrirNouveauRemplacement() async {
    final cree = await showDialog<bool>(context: context, builder: (_) => const _NouveauRemplacementDialog());
    if (cree == true) {
      _afficherSucces('Remplacement enregistré avec succès');
      _charger();
    }
  }

  Future<void> _annuler(Map<String, dynamic> remplacement) async {
    final confirme = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Annuler ce remplacement ?'),
            content: const Text('Cette action est définitive.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Annuler le remplacement'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirme) return;

    try {
      await DashboardEmploiDuTempsService.annulerRemplacement(remplacement['id'] as int);
      _afficherSucces('Remplacement annulé');
      _charger();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _vert));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Remplacements', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirNouveauRemplacement,
        backgroundColor: _indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nouveau remplacement', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _barreFiltres(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _charger,
                child: _chargement
                    ? const Center(child: CircularProgressIndicator(color: _indigo))
                    : _erreur != null
                        ? _vueErreur()
                        : _remplacements.isEmpty
                            ? _etatVide()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _remplacements.length,
                                itemBuilder: (context, index) => _carteRemplacement(_remplacements[index]),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreFiltres() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _filtreDate ?? DateTime.now(),
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 2),
                );
                if (date != null) {
                  setState(() => _filtreDate = date);
                  _charger();
                }
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 15),
              label: Text(_filtreDate == null ? 'Date' : _formatDateAffichage(_filtreDate), style: GoogleFonts.inter(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _filtreEnseignantId,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                hintText: 'Enseignant',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: _enseignants
                  .map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'] as String, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (id) {
                setState(() => _filtreEnseignantId = id);
                _charger();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _filtreClasseId,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                hintText: 'Classe',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: _classes
                  .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (id) {
                setState(() => _filtreClasseId = id);
                _charger();
              },
            ),
          ),
          if (_filtreDate != null || _filtreEnseignantId != null || _filtreClasseId != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18, color: _gris),
              tooltip: 'Réinitialiser les filtres',
              onPressed: () {
                setState(() {
                  _filtreDate = null;
                  _filtreEnseignantId = null;
                  _filtreClasseId = null;
                });
                _charger();
              },
            ),
        ],
      ),
    );
  }

  Widget _etatVide() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.swap_horiz_outlined, size: 56, color: _gris),
            const SizedBox(height: 12),
            Text('Aucun remplacement enregistré', style: GoogleFonts.inter(fontSize: 14, color: _texte)),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _rouge, size: 36),
          const SizedBox(height: 10),
          Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _charger,
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _carteRemplacement(Map<String, dynamic> r) {
    final seance = r['seance'] as Map<String, dynamic>?;
    final creneau = seance?['creneau_horaire'] as Map<String, dynamic>?;
    final matiere = seance?['matiere'] as Map<String, dynamic>?;
    final titulaire = seance?['enseignant'] as Map<String, dynamic>?;
    final classe = (seance?['emploi_du_temps'] as Map<String, dynamic>?)?['classe'] as Map<String, dynamic>?;
    final remplacant = r['enseignant_remplacant'] as Map<String, dynamic>?;
    final date = DateTime.tryParse(r['date_remplacement'] as String? ?? '');
    final motif = r['motif'] as String?;
    final jour = JourSemaine.depuisApi(seance?['jour'] as String?).libelle;
    final heureDebut = (creneau?['heure_debut'] as String?);
    final heureFin = (creneau?['heure_fin'] as String?);
    final passe = date != null && date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: passe ? _gris : _teal, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${classe?['nom'] ?? '—'} — ${matiere?['nom'] ?? '—'}',
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce),
                ),
              ),
              Text(_formatDateAffichage(date), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texte)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$jour · ${heureDebut ?? ''} - ${heureFin ?? ''}',
            style: GoogleFonts.inter(fontSize: 12, color: _gris),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: _gris),
              const SizedBox(width: 4),
              Text('Titulaire : ${titulaire?['name'] ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.swap_horiz, size: 14, color: _teal),
              const SizedBox(width: 4),
              Text('Remplaçant : ${remplacant?['name'] ?? '—'}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _teal)),
            ],
          ),
          if (motif != null && motif.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Motif : $motif', style: GoogleFonts.inter(fontSize: 12, color: _texte, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _annuler(r),
              icon: const Icon(Icons.close, size: 16, color: _rouge),
              label: Text('Annuler', style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _SeanceChoix — une entrée sélectionnable dans le dropdown "Séance à
// remplacer" (jour + créneau + séance déjà programmée).
// ══════════════════════════════════════════════════════════
class _SeanceChoix {
  final JourSemaine jour;
  final CreneauHoraire creneau;
  final Seance seance;

  _SeanceChoix({required this.jour, required this.creneau, required this.seance});

  String get libelle =>
      '${jour.libelle} ${creneau.heureDebut}-${creneau.heureFin} — ${seance.nomMatiere ?? ''} (${seance.nomEnseignant ?? ''})';
}

// ══════════════════════════════════════════════════════════
// _NouveauRemplacementDialog — sélection de la séance, de la date, et de
// l'enseignant remplaçant parmi ceux disponibles à ce créneau.
// ══════════════════════════════════════════════════════════
class _NouveauRemplacementDialog extends StatefulWidget {
  const _NouveauRemplacementDialog();

  @override
  State<_NouveauRemplacementDialog> createState() => _NouveauRemplacementDialogState();
}

class _NouveauRemplacementDialogState extends State<_NouveauRemplacementDialog> {
  List<Map<String, dynamic>> _classes = [];
  List<CreneauHoraire> _creneaux = [];
  int? _periodeId;
  bool _chargementInitial = true;

  int? _classeId;
  EmploiDuTemps? _emploi;
  bool _chargementEmploi = false;

  _SeanceChoix? _seanceSelectionnee;
  DateTime? _dateRemplacement;

  List<DisponibiliteEnseignant> _enseignantsDisponibilite = [];
  bool _chargementEnseignants = false;
  int? _enseignantRemplacantId;

  final _motifController = TextEditingController();
  bool _enregistrement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerInitial();
  }

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _chargerInitial() async {
    try {
      final resultats = await Future.wait([ClasseService.lister(), AnneeService.anneeActive(), EmploiDuTempsService.getCreneauxHoraires()]);
      final classesParCycle = resultats[0] as Map<String, dynamic>;
      final anneeData = resultats[1] as Map<String, dynamic>;
      final periodeActive = (anneeData['periode_active'] as Map<String, dynamic>?);
      final creneaux = (resultats[2] as List<CreneauHoraire>)..sort((a, b) => a.ordre.compareTo(b.ordre));

      setState(() {
        _classes = classesParCycle.values.expand((l) => (l as List).map((c) => c as Map<String, dynamic>)).toList();
        _periodeId = periodeActive?['id'] as int?;
        _creneaux = creneaux;
        _chargementInitial = false;
      });
    } catch (e) {
      setState(() {
        _chargementInitial = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<_SeanceChoix> get _seancesDisponibles {
    final emploi = _emploi;
    if (emploi == null) return [];
    final resultat = <_SeanceChoix>[];
    for (final jour in JourSemaine.values) {
      final map = emploi.grille[jour];
      if (map == null) continue;
      for (final creneau in _creneaux) {
        final seance = map[creneau.id];
        if (seance != null) resultat.add(_SeanceChoix(jour: jour, creneau: creneau, seance: seance));
      }
    }
    return resultat;
  }

  Future<void> _onClasseChangee(int? classeId) async {
    setState(() {
      _classeId = classeId;
      _emploi = null;
      _seanceSelectionnee = null;
      _enseignantsDisponibilite = [];
      _enseignantRemplacantId = null;
    });
    if (classeId == null || _periodeId == null) return;

    setState(() => _chargementEmploi = true);
    try {
      final emploi = await DashboardEmploiDuTempsService.getEmploiDuTempsClasse(classeId, _periodeId!);
      setState(() {
        _emploi = emploi;
        _chargementEmploi = false;
      });
    } catch (e) {
      setState(() => _chargementEmploi = false);
      setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _onSeanceChangee(_SeanceChoix? choix) async {
    setState(() {
      _seanceSelectionnee = choix;
      _enseignantsDisponibilite = [];
      _enseignantRemplacantId = null;
    });
    if (choix == null || choix.creneau.id == null || _periodeId == null) return;

    setState(() => _chargementEnseignants = true);
    try {
      final enseignants = await DashboardEmploiDuTempsService.getDisponibiliteCreneau(
        jour: choix.jour.valeurApi,
        creneauId: choix.creneau.id!,
        periodeId: _periodeId!,
      );
      setState(() {
        // Le titulaire de la séance n'est pas un remplaçant valide.
        _enseignantsDisponibilite = enseignants.where((e) => e.enseignantId != choix.seance.enseignantId).toList();
        _chargementEnseignants = false;
      });
    } catch (e) {
      setState(() => _chargementEnseignants = false);
    }
  }

  Future<void> _enregistrer() async {
    final choix = _seanceSelectionnee;
    if (choix == null || choix.seance.id == null || _enseignantRemplacantId == null || _dateRemplacement == null) {
      setState(() => _erreur = 'Sélectionnez la séance, la date et l\'enseignant remplaçant.');
      return;
    }

    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await DashboardEmploiDuTempsService.creerRemplacement(
        seanceId: choix.seance.id!,
        dateRemplacement: _dateRemplacement!,
        enseignantRemplacantId: _enseignantRemplacantId!,
        motif: _motifController.text.trim().isEmpty ? null : _motifController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _enregistrement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouveau remplacement', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _chargementInitial
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator(color: _indigo)),
                        )
                      : _corps(),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _rouge.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_erreur!, style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
                ),
              ],
              const SizedBox(height: 16),
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
                      onPressed: _enregistrement ? null : _enregistrer,
                      child: _enregistrement
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          value: _classeId,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Classe *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
          onChanged: _onClasseChangee,
        ),
        const SizedBox(height: 14),
        if (_chargementEmploi)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_classeId != null && _emploi == null)
          Text("Aucun emploi du temps pour cette classe.", style: GoogleFonts.inter(fontSize: 12, color: _gris))
        else if (_emploi != null) ...[
          DropdownButtonFormField<_SeanceChoix>(
            value: _seanceSelectionnee,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Séance à remplacer *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: _seancesDisponibles
                .map((s) => DropdownMenuItem<_SeanceChoix>(
                    value: s, child: Text(s.libelle, style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _onSeanceChangee,
          ),
        ],
        if (_seanceSelectionnee != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateRemplacement ?? DateTime.now(),
                firstDate: DateTime(DateTime.now().year - 1),
                lastDate: DateTime(DateTime.now().year + 2),
              );
              if (date != null) setState(() => _dateRemplacement = date);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(_dateRemplacement == null ? 'Date du remplacement *' : _formatDateAffichage(_dateRemplacement)),
          ),
          const SizedBox(height: 16),
          Text('Enseignants disponibles à ce créneau', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 8),
          if (_chargementEnseignants)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_enseignantsDisponibilite.isEmpty)
            Text('Aucun autre enseignant trouvé.', style: GoogleFonts.inter(fontSize: 12, color: _gris))
          else
            ..._enseignantsDisponibilite.map((e) {
              final selectionne = _enseignantRemplacantId == e.enseignantId;
              return Material(
                color: selectionne ? _indigo.withValues(alpha: 0.08) : (e.estLibre ? Colors.white : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: e.estLibre ? () => setState(() => _enseignantRemplacantId = e.enseignantId) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selectionne ? _indigo : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(selectionne ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18, color: selectionne ? _indigo : _gris),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.enseignantNom ?? '—',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: e.estLibre ? _texteFonce : _gris,
                                  fontWeight: selectionne ? FontWeight.w600 : FontWeight.w400)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (e.estLibre ? _vert : _rouge).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            e.estLibre ? 'Libre' : 'Occupé (${e.classeOccupee ?? ''})',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: e.estLibre ? _vert : _rouge),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          TextField(
            controller: _motifController,
            decoration: InputDecoration(labelText: 'Motif (optionnel)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            style: GoogleFonts.inter(fontSize: 14),
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}
