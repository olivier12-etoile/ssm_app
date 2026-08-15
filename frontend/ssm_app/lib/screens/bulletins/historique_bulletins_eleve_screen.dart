import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bulletin_model.dart';
import '../../models/historique_statistique_bulletin_model.dart';
import '../../services/historique_statistique_bulletin_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'apercu_bulletin_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _rouge = Color(0xFFDC2626);

// ══════════════════════════════════════════════════════════
// Historique complet des bulletins d'un élève, groupé Année scolaire →
// Périodes (structure arborescente du brief) — accessible depuis l'onglet
// "Bulletins" de la fiche élève (module Élèves).
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.nomEleve != null ? 'Bulletins — ${widget.nomEleve}' : 'Historique des bulletins',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null
              ? _vueErreur()
              : RefreshIndicator(onRefresh: _charger, child: _corps()),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
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
            child: Center(child: Text('Aucun bulletin disponible pour cet élève.', style: GoogleFonts.inter(color: _gris))),
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
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: groupes.keys.first == nomAnnee,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _gris.withValues(alpha: 0.2)),
              ),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              title: Text(nomAnnee, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
              subtitle: Text('${periodes.length} période(s)', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(h.nomPeriode ?? 'Période', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
              ),
              if (h.rang != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('Rang ${h.rang}', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
                ),
              Text('${h.moyenneGenerale.toStringAsFixed(2)}/20',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
              const SizedBox(width: 10),
              SSMBadge(label: h.statut.libelle, couleur: h.statut.couleur),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: _gris, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
