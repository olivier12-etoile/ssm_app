import 'package:flutter/material.dart';
import '../../services/statistique_service.dart';
import '../../services/annee_service.dart';

class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _annees = [];
  int? _anneeId;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final annees = await AnneeService.listerAnnees();
      setState(() => _annees = annees);
      await _chargerStats();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerStats() async {
    setState(() => _chargement = true);
    try {
      final stats = await StatistiqueService.chargerStatistiques(
        anneeId: _anneeId,
      );
      setState(() {
        _stats      = stats;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerStats,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Filtre année ───────────────────────────
                  if (_annees.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _anneeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filtrer par année académique',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Toutes les années'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Toutes les années'),
                        ),
                        ..._annees.map((a) {
                          return DropdownMenuItem<int>(
                            value: a['id'] as int,
                            child: Text(a['libelle'] as String),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() => _anneeId = v);
                        _chargerStats();
                      },
                    ),
                  const SizedBox(height: 24),

                  // ── Effectifs ──────────────────────────────
                  _titreSectionn('👥 Effectifs'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _carteStatistique(
                        'Total élèves',
                        '${_stats?['effectifs']?['total'] ?? 0}',
                        Icons.people,
                        Colors.blue,
                      ),
                      _carteStatistique(
                        'Garçons',
                        '${_stats?['effectifs']?['garcons'] ?? 0}',
                        Icons.boy,
                        Colors.lightBlue,
                      ),
                      _carteStatistique(
                        'Filles',
                        '${_stats?['effectifs']?['filles'] ?? 0}',
                        Icons.girl,
                        Colors.pink,
                      ),
                      _carteStatistique(
                        'Enseignants',
                        '${_stats?['effectifs']?['enseignants'] ?? 0}',
                        Icons.school,
                        Colors.orange,
                      ),
                      _carteStatistique(
                        'Classes',
                        '${_stats?['effectifs']?['classes'] ?? 0}',
                        Icons.class_,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Finances ───────────────────────────────
                  _titreSectionn('💰 Finances'),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet,
                              size: 40, color: Colors.teal),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total encaissé',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '${_stats?['finances']?['total_encaisse'] ?? 0} FCFA',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Paiements par mois
                  if ((_stats?['finances']?['paiements_mois'] as List?)
                          ?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Encaissements par mois',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...((_stats!['finances']['paiements_mois']
                                    as List)
                                .map((p) {
                              final mois = _nomMois(p['mois'] as int);
                              final total = p['total'];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '$mois ${p['annee']}',
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: _progressionMois(total),
                                        backgroundColor: Colors.grey[200],
                                        color: Colors.teal,
                                        minHeight: 8,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$total FCFA',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Notes ──────────────────────────────────
                  _titreSectionn('📊 Notes'),
                  const SizedBox(height: 12),

                  // Notes par statut
                  if (_stats?['notes']?['par_statut'] != null)
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes par statut',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...(_stats!['notes']['par_statut']
                                    as Map<String, dynamic>)
                                .entries
                                .map((e) {
                              return _ligneStatut(
                                e.key,
                                e.value.toString(),
                                _couleurStatut(e.key),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Moyennes par classe
                  if ((_stats?['notes']?['moyennes_classes'] as List?)
                          ?.isNotEmpty ==
                      true)
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Moyenne par classe',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...((_stats!['notes']['moyennes_classes']
                                    as List)
                                .map((c) {
                              final moyenne =
                                  double.tryParse(c['moyenne'].toString()) ??
                                      0.0;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        c['nom'] as String,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: moyenne / 20,
                                        backgroundColor: Colors.grey[200],
                                        color: _couleurMoyenne(moyenne),
                                        minHeight: 8,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$moyenne/20',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _couleurMoyenne(moyenne),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _titreSectionn(String titre) {
    return Text(
      titre,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
      ),
    );
  }

  Widget _carteStatistique(
      String titre, String valeur, IconData icone, Color couleur) {
    return Card(
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 28, color: couleur),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          Text(
            titre,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _ligneStatut(String statut, String valeur, Color couleur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statut.toUpperCase(),
            style: TextStyle(color: couleur, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            valeur,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'valide':    return Colors.green;
      case 'soumis':    return Colors.blue;
      case 'rejete':    return Colors.red;
      case 'brouillon': return Colors.orange;
      default:          return Colors.grey;
    }
  }

  Color _couleurMoyenne(double moyenne) {
    if (moyenne >= 15) return Colors.green;
    if (moyenne >= 10) return Colors.orange;
    return Colors.red;
  }

  String _nomMois(int mois) {
    const moisNoms = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return moisNoms[mois];
  }

  double _progressionMois(dynamic total) {
    final paiements = (_stats!['finances']['paiements_mois'] as List);
    if (paiements.isEmpty) return 0;
    final max = paiements
        .map((p) => double.tryParse(p['total'].toString()) ?? 0.0)
        .reduce((a, b) => a > b ? a : b);
    if (max == 0) return 0;
    return (double.tryParse(total.toString()) ?? 0.0) / max;
  }
}