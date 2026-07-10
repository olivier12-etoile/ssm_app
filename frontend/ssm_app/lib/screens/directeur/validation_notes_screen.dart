import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/note_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/matiere_service.dart';
import '../../widgets/ssm_widgets.dart';

class ValidationNotesScreen extends StatefulWidget {
  final int? classeIdPreselectionne;

  const ValidationNotesScreen({super.key, this.classeIdPreselectionne});

  @override
  State<ValidationNotesScreen> createState() => _ValidationNotesScreenState();
}

class _ValidationNotesScreenState extends State<ValidationNotesScreen> {
  List<dynamic> _classes  = [];
  List<dynamic> _annees   = [];
  List<dynamic> _periodes = [];
  List<dynamic> _matieres = [];
  List<dynamic> _notes    = [];

  int? _classeId;
  int? _anneeId;
  int? _periodeId;
  int? _matiereId;
  String? _filtreStatut;

  bool _chargement      = true;
  bool _chargementNotes = false;

  static const _statuts = ['soumis', 'valide', 'rejete'];

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
        MatiereService.listerMatieres(),
      ]);
      setState(() {
        _classes    = resultats[0] as List;
        _annees     = resultats[1] as List;
        _matieres   = resultats[2] as List;
        if (widget.classeIdPreselectionne != null &&
            _classes.any((c) => c['id'] == widget.classeIdPreselectionne)) {
          _classeId = widget.classeIdPreselectionne;
        }
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerPeriodes(int anneeId) async {
    final liste = await AnneeService.listerPeriodes(anneeId);
    setState(() {
      _periodes  = liste;
      _periodeId = null;
    });
  }

  Future<void> _chargerNotes() async {
    if (_classeId == null || _periodeId == null || _matiereId == null) return;
    setState(() => _chargementNotes = true);
    try {
      final notes = await NoteService.listerNotes(
        classeId:  _classeId!,
        periodeId: _periodeId!,
        matiereId: _matiereId!,
      );
      setState(() {
        _notes           = notes;
        _chargementNotes = false;
      });
    } catch (e) {
      setState(() => _chargementNotes = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'valide':    return const Color(0xFF16A34A);
      case 'soumis':    return const Color(0xFF0284C7);
      case 'rejete':    return const Color(0xFFDC2626);
      case 'brouillon': return const Color(0xFFEA580C);
      default:          return const Color(0xFF94A3B8);
    }
  }

  Color _couleurMention(double valeur) {
    if (valeur >= 16) return const Color(0xFF16A34A);
    if (valeur >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  List<dynamic> get _notesFiltrees {
    if (_filtreStatut == null) return _notes;
    return _notes.where((n) => n['statut'] == _filtreStatut).toList();
  }

  bool _aNotesSoumises() {
    return _notes.any((n) => n['statut'] == 'soumis');
  }

  Future<void> _valider() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider les notes'),
        content: const Text(
          'Voulez-vous valider toutes les notes soumises ?\nCette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      try {
        await NoteService.validerNotes(
          classeId:  _classeId!,
          periodeId: _periodeId!,
          matiereId: _matiereId!,
        );
        _afficherSucces('Notes validées définitivement');
        _chargerNotes();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _rejeter() async {
    final motifController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter les notes'),
        content: TextField(
          controller: motifController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex: Notes incohérentes, vérifier la classe...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (motifController.text.isEmpty) return;
              try {
                await NoteService.rejeterNotes(
                  classeId:   _classeId!,
                  periodeId:  _periodeId!,
                  matiereId:  _matiereId!,
                  motifRejet: motifController.text,
                );
                Navigator.pop(context);
                _afficherSucces('Notes rejetées — l\'enseignant doit corriger');
                _chargerNotes();
              } catch (e) {
                _afficherErreur(
                    e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'valide':    return 'Validé';
      case 'soumis':    return 'Soumis';
      case 'rejete':    return 'Rejeté';
      default:          return statut;
    }
  }

  Widget _chipStatut(String? statut, String label) {
    final selectionne = _filtreStatut == statut;
    final couleur =
        statut == null ? const Color(0xFF1E3A8A) : _couleurStatut(statut);
    return GestureDetector(
      onTap: () => setState(() => _filtreStatut = statut),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Validation des notes',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filtres ──────────────────────────────
                Container(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _classeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Classe',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Classe'),
                              items: _classes.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(c['nom'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _classeId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _anneeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Année',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Année'),
                              items: _annees.map((a) {
                                return DropdownMenuItem<int>(
                                  value: a['id'] as int,
                                  child: Text(a['libelle'] as String),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _anneeId   = v;
                                  _periodeId = null;
                                });
                                if (v != null) _chargerPeriodes(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _periodeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Période',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Période'),
                              items: _periodes.map((p) {
                                return DropdownMenuItem<int>(
                                  value: p['id'] as int,
                                  child: Text(p['nom'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _periodeId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _matiereId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Matière',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Matière'),
                              items: _matieres.map((m) {
                                return DropdownMenuItem<int>(
                                  value: m['id'] as int,
                                  child: Text(m['nom'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _matiereId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _classeId == null ||
                                  _anneeId == null ||
                                  _periodeId == null ||
                                  _matiereId == null
                              ? null
                              : _chargerNotes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Charger les notes'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chips filtre statut ───────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipStatut(null, 'Tous'),
                        ..._statuts.map((s) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _chipStatut(s, _labelStatut(s)),
                            )),
                      ],
                    ),
                  ),
                ),

                // ── Boutons Valider / Rejeter ─────────────
                if (_aNotesSoumises())
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _valider,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Valider'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _rejeter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Rejeter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // ── Liste des notes ───────────────────────
                Expanded(
                  child: _chargementNotes
                      ? const Center(child: CircularProgressIndicator())
                      : _notesFiltrees.isEmpty
                          ? Center(
                              child: Text(
                                'Aucune note trouvée\nSélectionnez les filtres et cliquez sur Charger',
                                style: GoogleFonts.inter(color: const Color(0xFF334155)),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _notesFiltrees.length,
                              itemBuilder: (context, index) {
                                final note   = _notesFiltrees[index];
                                final statut = note['statut'] as String;
                                final eleve  = note['eleve'];
                                final valeur = double.tryParse(
                                        note['valeur'].toString()) ??
                                    0.0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
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
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _couleurMention(valeur),
                                        child: Text(
                                          note['valeur'].toString(),
                                          style: GoogleFonts.sora(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              eleve != null
                                                  ? '${eleve['nom']} ${eleve['prenom']}'
                                                  : 'Élève inconnu',
                                              style: GoogleFonts.sora(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (note['motif_rejet'] != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Motif : ${note['motif_rejet']}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      SSMBadge(
                                        label: _labelStatut(statut).toUpperCase(),
                                        couleur: _couleurStatut(statut),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
