import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/dashboard_emploi_du_temps_model.dart';
import '../../services/dashboard_emploi_du_temps_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _rouge = Color(0xFFDC2626);
const Color _violet = Color(0xFF7C3AED);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

const List<String> _moisLabels = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];
const List<String> _joursLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

Color _couleurType(TypeEvenement type) {
  switch (type) {
    case TypeEvenement.vacances:
      return _teal;
    case TypeEvenement.ferie:
      return _ambre;
    case TypeEvenement.examen:
      return _rouge;
    case TypeEvenement.composition:
      return _indigo;
    case TypeEvenement.conseilClasse:
      return _violet;
  }
}

String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ══════════════════════════════════════════════════════════
// CalendrierScolaireScreen — vue mois + liste chronologique des
// événements du calendrier scolaire (vacances, fériés, examens,
// compositions, conseils de classe).
// ══════════════════════════════════════════════════════════
class CalendrierScolaireScreen extends StatefulWidget {
  final int anneeScolaireId;

  const CalendrierScolaireScreen({super.key, required this.anneeScolaireId});

  @override
  State<CalendrierScolaireScreen> createState() => _CalendrierScolaireScreenState();
}

class _CalendrierScolaireScreenState extends State<CalendrierScolaireScreen> {
  List<EvenementCalendrier> _evenements = [];
  bool _chargement = true;
  String? _erreur;

  bool _vueMois = true;
  TypeEvenement? _filtreType;
  DateTime _moisAffiche = DateTime(DateTime.now().year, DateTime.now().month, 1);

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
      final evenements = await DashboardEmploiDuTempsService.getCalendrier(widget.anneeScolaireId);
      setState(() {
        _evenements = evenements;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<EvenementCalendrier> get _evenementsFiltres =>
      _filtreType == null ? _evenements : _evenements.where((e) => e.type == _filtreType).toList();

  Future<void> _supprimer(EvenementCalendrier evenement) async {
    if (evenement.id == null) return;
    final confirme = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Supprimer "${evenement.libelle}" ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirme) return;

    try {
      await DashboardEmploiDuTempsService.supprimerEvenementCalendrier(evenement.id!);
      _afficherSucces('Événement supprimé');
      _charger();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _teal));
  }

  Future<void> _ouvrirFormulaireEvenement() async {
    final cree = await showDialog<bool>(
      context: context,
      builder: (_) => _EvenementFormDialog(anneeScolaireId: widget.anneeScolaireId),
    );
    if (cree == true) {
      _afficherSucces('Événement créé avec succès');
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Calendrier scolaire', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_vueMois ? Icons.view_list : Icons.calendar_view_month),
            tooltip: _vueMois ? 'Vue liste' : 'Vue calendrier',
            onPressed: () => setState(() => _vueMois = !_vueMois),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaireEvenement,
        backgroundColor: _indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Ajouter un événement', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
                        : _vueMois
                            ? _vueCalendrierMois()
                            : _vueListe(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreFiltres() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _puceFiltre('Tous', null),
            ...TypeEvenement.values.map((t) => _puceFiltre(t.libelle, t)),
          ],
        ),
      ),
    );
  }

  Widget _puceFiltre(String label, TypeEvenement? type) {
    final selectionne = _filtreType == type;
    final couleur = type == null ? _indigo : _couleurType(type);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: selectionne ? Colors.white : couleur)),
        selected: selectionne,
        onSelected: (_) => setState(() => _filtreType = type),
        selectedColor: couleur,
        backgroundColor: couleur.withValues(alpha: 0.1),
        side: BorderSide(color: couleur.withValues(alpha: 0.3)),
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

  // ══════════════════════════════════════════════════════
  // VUE LISTE CHRONOLOGIQUE
  // ══════════════════════════════════════════════════════

  Widget _vueListe() {
    final evenements = List<EvenementCalendrier>.from(_evenementsFiltres)
      ..sort((a, b) => a.dateDebut.compareTo(b.dateDebut));

    if (evenements.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.event_busy_outlined, size: 56, color: _gris),
                  const SizedBox(height: 12),
                  Text('Aucun événement', style: GoogleFonts.inter(fontSize: 14, color: _texte)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: evenements.length,
      itemBuilder: (context, index) => _carteEvenement(evenements[index]),
    );
  }

  Widget _carteEvenement(EvenementCalendrier evenement) {
    final couleur = _couleurType(evenement.type);
    final memeJour = evenement.dateDebut.year == evenement.dateFin.year &&
        evenement.dateDebut.month == evenement.dateFin.month &&
        evenement.dateDebut.day == evenement.dateFin.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: couleur, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: Text(evenement.type.libelle, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(evenement.libelle, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
                const SizedBox(height: 4),
                Text(
                  memeJour
                      ? _formatDate(evenement.dateDebut)
                      : '${_formatDate(evenement.dateDebut)} → ${_formatDate(evenement.dateFin)}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _texte),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.delete_outline, color: _rouge, size: 20), onPressed: () => _supprimer(evenement)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VUE CALENDRIER (MOIS)
  // ══════════════════════════════════════════════════════

  Widget _vueCalendrierMois() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1, 1)),
            ),
            Text('${_moisLabels[_moisAffiche.month - 1]} ${_moisAffiche.year}',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1, 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: _joursLabels
              .map((j) => Expanded(child: Center(child: Text(j, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _gris)))))
              .toList(),
        ),
        const SizedBox(height: 6),
        _grilleMois(),
        const SizedBox(height: 20),
        Text('Légende', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: TypeEvenement.values.map((t) {
            final couleur = _couleurType(t);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(t.libelle, style: GoogleFonts.inter(fontSize: 11, color: _texte)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _grilleMois() {
    final premierJourMois = DateTime(_moisAffiche.year, _moisAffiche.month, 1);
    final nombreJours = DateTime(_moisAffiche.year, _moisAffiche.month + 1, 0).day;
    // weekday: 1 = lundi ... 7 = dimanche -> nombre de cases vides avant le 1er.
    final decalage = premierJourMois.weekday - 1;

    final cellules = <Widget>[];
    for (var i = 0; i < decalage; i++) {
      cellules.add(const SizedBox());
    }
    for (var jour = 1; jour <= nombreJours; jour++) {
      final date = DateTime(_moisAffiche.year, _moisAffiche.month, jour);
      final evenementsDuJour = _evenementsFiltres.where((e) => e.concerneLe(date)).toList();
      final estAujourdhui = _estAujourdhui(date);

      cellules.add(
        GestureDetector(
          onTap: evenementsDuJour.isEmpty ? null : () => _ouvrirJour(date, evenementsDuJour),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: estAujourdhui ? _indigo.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: estAujourdhui ? Border.all(color: _indigo) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$jour', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce)),
                const SizedBox(height: 3),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  children: evenementsDuJour
                      .take(3)
                      .map((e) => Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: _couleurType(e.type), shape: BoxShape.circle),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: cellules,
    );
  }

  bool _estAujourdhui(DateTime date) {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  Future<void> _ouvrirJour(DateTime date, List<EvenementCalendrier> evenements) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDate(date), style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
            const SizedBox(height: 12),
            ...evenements.map(_carteEvenement),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _EvenementFormDialog — création d'un événement du calendrier.
// ══════════════════════════════════════════════════════════
class _EvenementFormDialog extends StatefulWidget {
  final int anneeScolaireId;

  const _EvenementFormDialog({required this.anneeScolaireId});

  @override
  State<_EvenementFormDialog> createState() => _EvenementFormDialogState();
}

class _EvenementFormDialogState extends State<_EvenementFormDialog> {
  final _libelleController = TextEditingController();
  TypeEvenement _type = TypeEvenement.vacances;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _enregistrement = false;
  String? _erreur;

  @override
  void dispose() {
    _libelleController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (_libelleController.text.trim().isEmpty || _dateDebut == null || _dateFin == null) {
      setState(() => _erreur = 'Complétez le libellé, la date de début et la date de fin.');
      return;
    }
    if (_dateFin!.isBefore(_dateDebut!)) {
      setState(() => _erreur = 'La date de fin doit être après la date de début.');
      return;
    }

    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await DashboardEmploiDuTempsService.creerEvenementCalendrier(
        EvenementCalendrier(type: _type, libelle: _libelleController.text.trim(), dateDebut: _dateDebut!, dateFin: _dateFin!),
        anneeScolaireId: widget.anneeScolaireId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _enregistrement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _choisirDate({required bool debut}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (debut ? _dateDebut : _dateFin) ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (date == null) return;
    setState(() {
      if (debut) {
        _dateDebut = date;
      } else {
        _dateFin = date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Nouvel événement', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
              const SizedBox(height: 20),
              DropdownButtonFormField<TypeEvenement>(
                value: _type,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: TypeEvenement.values.map((t) => DropdownMenuItem(value: t, child: Text(t.libelle))).toList(),
                onChanged: (t) => setState(() => _type = t ?? TypeEvenement.vacances),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _libelleController,
                decoration: InputDecoration(
                  labelText: 'Libellé *',
                  hintText: 'ex: Vacances de Noël, Examen blanc...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _choisirDate(debut: true),
                      child: Text(_dateDebut == null ? 'Date début *' : _formatDate(_dateDebut!),
                          style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _choisirDate(debut: false),
                      child: Text(_dateFin == null ? 'Date fin *' : _formatDate(_dateFin!), style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
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
                      onPressed: _enregistrement ? null : _enregistrer,
                      child: _enregistrement
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  }
}
