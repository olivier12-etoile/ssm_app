import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

class GestionAnneesScreen extends StatefulWidget {
  const GestionAnneesScreen({super.key});

  @override
  State<GestionAnneesScreen> createState() => _GestionAnneesScreenState();
}

class _GestionAnneesScreenState extends State<GestionAnneesScreen> {
  List<dynamic> _annees   = [];
  bool _chargement        = true;

  @override
  void initState() {
    super.initState();
    _chargerAnnees();
  }

  Future<void> _chargerAnnees() async {
    try {
      final liste = await AnneeService.listerAnnees();
      setState(() {
        _annees     = liste;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
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

  Future<void> _afficherDialogAnnee() async {
    final libelleController   = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nouvelle année académique'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: libelleController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé (ex: 2025-2026)',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Date début
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateDebut == null
                      ? 'Date de début'
                      : '${dateDebut!.day}/${dateDebut!.month}/${dateDebut!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateDebut = d);
                  },
                ),
                // Date fin
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateFin == null
                      ? 'Date de fin'
                      : '${dateFin!.day}/${dateFin!.month}/${dateFin!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateFin = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: libelleController.text.isEmpty ||
                        dateDebut == null ||
                        dateFin == null
                    ? null
                    : () async {
                        try {
                          await AnneeService.creerAnnee(
                            libelle:   libelleController.text,
                            dateDebut: '${dateDebut!.year}-${dateDebut!.month.toString().padLeft(2, '0')}-${dateDebut!.day.toString().padLeft(2, '0')}',
                            dateFin:   '${dateFin!.year}-${dateFin!.month.toString().padLeft(2, '0')}-${dateFin!.day.toString().padLeft(2, '0')}',
                          );
                          Navigator.pop(context);
                          _afficherSucces('Année créée avec succès');
                          _chargerAnnees();
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

  Future<void> _voirPeriodes(dynamic annee) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PeriodeScreen(annee: annee),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Années académiques',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerAnnees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAnnee,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle année'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _annees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 64, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      Text('Aucune année académique',
                          style: GoogleFonts.inter(color: const Color(0xFF334155))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _annees.length,
                  itemBuilder: (context, index) {
                    final annee  = _annees[index];
                    final nb     = (annee['periodes'] as List?)?.length ?? 0;
                    final enCours = annee['statut'] == 'en_cours';
                    final couleurStatut =
                        enCours ? const Color(0xFF16A34A) : const Color(0xFF94A3B8);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(color: couleurStatut, width: 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E3A8A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.calendar_month,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    annee['libelle'] as String,
                                    style: GoogleFonts.sora(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$nb période(s)',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SSMBadge(
                                    label: enCours ? 'EN COURS' : 'TERMINÉE',
                                    couleur: couleurStatut,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _voirPeriodes(annee),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Périodes'),
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

// ─── Écran des périodes ───────────────────────────────────
class _PeriodeScreen extends StatefulWidget {
  final dynamic annee;
  const _PeriodeScreen({required this.annee});

  @override
  State<_PeriodeScreen> createState() => _PeriodeScreenState();
}

class _PeriodeScreenState extends State<_PeriodeScreen> {
  List<dynamic> _periodes = [];
  bool _chargement        = true;

  @override
  void initState() {
    super.initState();
    _chargerPeriodes();
  }

  Future<void> _chargerPeriodes() async {
    try {
      final liste = await AnneeService.listerPeriodes(
          widget.annee['id'] as int);
      setState(() {
        _periodes   = liste;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
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
      case 'actif':    return const Color(0xFF16A34A);
      case 'cloture':  return const Color(0xFF94A3B8);
      default:         return const Color(0xFF0284C7);
    }
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'actif':    return 'ACTIF';
      case 'cloture':  return 'CLÔTURÉ';
      default:         return 'PLANIFIÉ';
    }
  }

  Future<void> _afficherDialogPeriode() async {
    final nomController = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Nouvelle période — ${widget.annee['libelle']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom (ex: 1er Trimestre)',
                    prefixIcon: Icon(Icons.segment),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateDebut == null
                      ? 'Date de début'
                      : '${dateDebut!.day}/${dateDebut!.month}/${dateDebut!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateDebut = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateFin == null
                      ? 'Date de fin'
                      : '${dateFin!.day}/${dateFin!.month}/${dateFin!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateFin = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomController.text.isEmpty ||
                      dateDebut == null ||
                      dateFin == null) return;
                  try {
                    await AnneeService.creerPeriode(
                      anneeAcademiqueId: widget.annee['id'] as int,
                      nom:               nomController.text,
                      dateDebut: '${dateDebut!.year}-${dateDebut!.month.toString().padLeft(2, '0')}-${dateDebut!.day.toString().padLeft(2, '0')}',
                      dateFin:   '${dateFin!.year}-${dateFin!.month.toString().padLeft(2, '0')}-${dateFin!.day.toString().padLeft(2, '0')}',
                    );
                    Navigator.pop(context);
                    _afficherSucces('Période créée');
                    _chargerPeriodes();
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

  Future<void> _changerStatut(int id, String statutActuel) async {
    final statuts = ['planifie', 'actif', 'cloture'];
    String selectionne = statutActuel;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Changer le statut'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: statuts.map((s) {
                return RadioListTile<String>(
                  title: Text(s),
                  value: s,
                  groupValue: selectionne,
                  onChanged: (v) => setStateDialog(() => selectionne = v!),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await AnneeService.changerStatutPeriode(id, selectionne);
                    Navigator.pop(context);
                    _afficherSucces('Statut mis à jour');
                    _chargerPeriodes();
                  } catch (e) {
                    _afficherErreur(
                        e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Confirmer'),
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
          'Périodes — ${widget.annee['libelle']}',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogPeriode,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle période'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _periodes.isEmpty
              ? Center(
                  child: Text('Aucune période',
                      style: GoogleFonts.inter(color: const Color(0xFF334155))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _periodes.length,
                  itemBuilder: (context, index) {
                    final p      = _periodes[index];
                    final statut = p['statut'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _couleurStatut(statut),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.segment, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['nom'] as String,
                                  style: GoogleFonts.sora(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p['date_debut']} → ${p['date_fin']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _changerStatut(p['id'] as int, statut),
                            child: SSMBadge(
                              label: _labelStatut(statut),
                              couleur: _couleurStatut(statut),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
