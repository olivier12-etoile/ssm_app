import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bulletin_model.dart';
import '../../models/historique_statistique_bulletin_model.dart';
import '../../services/historique_statistique_bulletin_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'apercu_bulletin_screen.dart';

// ══════════════════════════════════════════════════════════
// Historique complet des bulletins d'un élève, groupé Année scolaire →
// Périodes (structure arborescente du brief, ssm_panel imbriqués) —
// accessible depuis l'onglet "Bulletins" de la fiche élève (module Élèves).
// ══════════════════════════════════════════════════════════
class HistoriqueBulletinsEleveScreen extends StatefulWidget {
  final int eleveId;
  final String? nomEleve;

  const HistoriqueBulletinsEleveScreen({super.key, required this.eleveId, this.nomEleve});

  @override
  State<HistoriqueBulletinsEleveScreen> createState() => _HistoriqueBulletinsEleveScreenState();
}

class _HistoriqueBulletinsEleveScreenState extends State<HistoriqueBulletinsEleveScreen> {
  List<BulletinHistorique> _bulletins = [];
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
      final bulletins = await HistoriqueStatistiqueBulletinService.getHistoriqueEleve(widget.eleveId);
      if (!mounted) return;
      setState(() {
        _bulletins = bulletins;
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

  // Regroupe par nomAnnee puis nomPeriode en conservant l'ordre renvoyé par
  // le backend (année la plus récente et périodes déjà triées par
  // PeriodeAcademique.ordre côté API).
  Map<String, List<BulletinHistorique>> get _parAnnee {
    final groupes = <String, List<BulletinHistorique>>{};
    for (final b in _bulletins) {
      groupes.putIfAbsent(b.nomAnnee ?? 'Année inconnue', () => []).add(b);
    }
    return groupes;
  }

  void _ouvrirApercu(BulletinHistorique h) {
    final resume = Bulletin(
      id: h.id,
      eleveId: h.eleveId,
      nomEleve: h.nomEleve ?? widget.nomEleve,
      classeId: h.classeId ?? 0,
      nomClasse: h.nomClasse,
      periodeId: h.periodeId,
      nomPeriode: h.nomPeriode,
      moyenneGenerale: h.moyenneGenerale,
      rang: h.rang,
      effectifClasse: 0,
      totalCoefficients: 0,
      totalPoints: 0,
      statut: h.statut,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApercuBulletinScreen(bulletinId: h.id, resume: resume)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: widget.nomEleve != null ? 'Bulletins — ${widget.nomEleve}' : 'Historique des bulletins',
              onRetour: () => Navigator.pop(context),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(onRefresh: _charger, color: SSMPalette.indigo, child: _corps()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    final groupes = _parAnnee;
    if (groupes.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text('Aucun bulletin disponible pour cet élève.', style: GoogleFonts.inter(color: SSMPalette.texte3))),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupes.entries.map((entree) {
        final nomAnnee = entree.key;
        final periodes = entree.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SSMPanel(
            titre: nomAnnee,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: periodes.map(_lignePeriode).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _lignePeriode(BulletinHistorique h) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _ouvrirApercu(h),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
          child: Row(
            children: [
              Expanded(
                child: Text(h.nomPeriode ?? 'Période', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
              ),
              if (h.rang != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('Rang ${h.rang}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
                ),
              Text('${h.moyenneGenerale.toStringAsFixed(2)}/20',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
              const SizedBox(width: 10),
              SSMPill.couleur(label: h.statut.libelle, couleur: h.statut.couleur),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: SSMPalette.texte3, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
