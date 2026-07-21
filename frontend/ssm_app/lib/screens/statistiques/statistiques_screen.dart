import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/statistique_service.dart';
import '../../services/annee_service.dart';
import '../../services/absence_service.dart';
import '../../widgets/ssm_widgets.dart';

class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _absencesStats;
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
      final resultats = await Future.wait([
        StatistiqueService.chargerStatistiques(anneeId: _anneeId),
        AbsenceService.statistiques(),
      ]);
      setState(() {
        _stats          = resultats[0];
        _absencesStats  = resultats[1];
        _chargement     = false;
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

  double _moyenneGenerale() {
    final classes = _stats?['notes']?['moyennes_classes'] as List?;
    if (classes == null || classes.isEmpty) return 0.0;
    final total = classes.fold<double>(
      0.0,
      (somme, c) => somme + (double.tryParse(c['moyenne'].toString()) ?? 0.0),
    );
    return total / classes.length;
  }

  @override
  Widget build(BuildContext context) {
    final totalEleves    = _stats?['effectifs']?['total'] ?? 0;
    final totalEncaisse  = _stats?['finances']?['total_encaisse'] ?? 0;
    final absentsJour     = _absencesStats?['absents_aujourdhui'] ?? 0;
    final moyenneGenerale = _moyenneGenerale();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Statistiques',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
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
          : ListView(
              children: [
                SSMEnteteEcran(
                  salutation: 'Statistiques 📊',
                  sousTitre: 'Vue d\'ensemble de votre école',
                  valeurPrincipale: '$totalEleves',
                  labelValeur: 'élèves',
                ),
                Padding(
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
                      const SizedBox(height: 20),

                      // ── Grille des statistiques clés ──────────
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          SSMStatCard(
                            titre: 'Total élèves',
                            valeur: '$totalEleves',
                            icone: Icons.people,
                            couleurIcone: const Color(0xFF1E3A8A),
                          ),
                          SSMStatCard(
                            titre: 'Total encaissé',
                            valeur: '$totalEncaisse FCFA',
                            icone: Icons.account_balance_wallet,
                            couleurIcone: const Color(0xFF0D9488),
                          ),
                          SSMStatCard(
                            titre: 'Absences du jour',
                            valeur: '$absentsJour',
                            icone: Icons.event_busy,
                            couleurIcone: const Color(0xFFEA580C),
                          ),
                          SSMStatCard(
                            titre: 'Moyenne générale',
                            valeur: '${moyenneGenerale.toStringAsFixed(1)}/20',
                            icone: Icons.grade,
                            couleurIcone: const Color(0xFFD97706),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Encaissements par mois ─────────────────
                      if ((_stats?['finances']?['paiements_mois'] as List?)
                              ?.isNotEmpty ==
                          true) ...[
                        SSMSectionTitre(titre: 'Encaissements par mois'),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            children: ((_stats!['finances']['paiements_mois']
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
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: _progressionMois(total),
                                        backgroundColor:
                                            const Color(0xFFF1F5F9),
                                        color: const Color(0xFF0D9488),
                                        minHeight: 8,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$total FCFA',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Notes par statut ───────────────────────
                      // Laravel sérialise un pluck() vide en `[]` (liste) et
                      // non en `{}` (objet) — on ne peut donc pas caster
                      // directement en Map.
                      if (_stats?['notes']?['par_statut'] is Map) ...[
                        SSMSectionTitre(titre: 'Notes par statut'),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            children: Map<String, dynamic>.from(
                                    _stats!['notes']['par_statut'] as Map)
                                .entries
                                .map((e) {
                              return _ligneStatut(
                                e.key,
                                e.value.toString(),
                                _couleurStatut(e.key),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Moyenne par classe ──────────────────────
                      if ((_stats?['notes']?['moyennes_classes'] as List?)
                              ?.isNotEmpty ==
                          true) ...[
                        SSMSectionTitre(titre: 'Moyenne par classe'),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            children: ((_stats!['notes']['moyennes_classes']
                                    as List)
                                .map((c) {
                              final moyenne = double.tryParse(
                                      c['moyenne'].toString()) ??
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
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: moyenne / 20,
                                        backgroundColor:
                                            const Color(0xFFF1F5F9),
                                        color: _couleurMoyenne(moyenne),
                                        minHeight: 8,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$moyenne/20',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: _couleurMoyenne(moyenne),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
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
            style: GoogleFonts.inter(color: couleur, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            valeur,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ],
      ),
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

  Color _couleurMoyenne(double moyenne) {
    if (moyenne >= 15) return const Color(0xFF16A34A);
    if (moyenne >= 10) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
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
