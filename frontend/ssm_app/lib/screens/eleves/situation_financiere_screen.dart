import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/paiement_model.dart';
import '../../models/utilisateur.dart';
import '../../services/paiement_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ssm_widgets.dart';
import '../../widgets/recu_pdf_viewer.dart';
import 'nouveau_paiement_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatDateCourt(DateTime? d) =>
    d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$buffer FCFA';
}

Color _couleurStatut(String statut) {
  switch (statut) {
    case 'a_jour':
    case 'paye':
      return _vert;
    case 'partiel':
      return _ambre;
    default:
      return _rouge;
  }
}

String _libelleStatut(String statut) {
  switch (statut) {
    case 'a_jour':
      return 'À jour';
    case 'paye':
      return 'Payé';
    case 'partiel':
      return 'Partiel';
    case 'aucun_paiement':
    case 'impaye':
      return 'Aucun paiement';
    default:
      return statut;
  }
}

class SituationFinanciereScreen extends StatefulWidget {
  final int eleveId;
  final int classeId;
  final int anneeScolaireId;
  final String? eleveNomComplet;
  final String? classeNom;

  const SituationFinanciereScreen({
    super.key,
    required this.eleveId,
    required this.classeId,
    required this.anneeScolaireId,
    this.eleveNomComplet,
    this.classeNom,
  });

  @override
  State<SituationFinanciereScreen> createState() => _SituationFinanciereScreenState();
}

class _SituationFinanciereScreenState extends State<SituationFinanciereScreen> {
  SituationFinanciere? _situation;
  bool _chargement = true;
  bool _estDirecteur = false;
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
      final resultats = await Future.wait([
        PaiementService.getSituationFinanciere(widget.eleveId, anneeScolaireId: widget.anneeScolaireId),
        AuthService.getUtilisateur(),
      ]);
      final situation = resultats[0] as SituationFinanciere;
      final utilisateur = resultats[1] as Utilisateur?;
      setState(() {
        _situation = situation;
        _estDirecteur = utilisateur?.estDirecteur == true;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
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

  Future<void> _ouvrirNouveauPaiement({int? fraisScolaireIdPreselectionne}) async {
    if (_situation == null) return;

    final resultat = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NouveauPaiementScreen(
          eleveId: widget.eleveId,
          eleveNomComplet: widget.eleveNomComplet ?? '${_situation!.eleveNom} ${_situation!.elevePrenom}',
          classeId: widget.classeId,
          anneeScolaireId: widget.anneeScolaireId,
          situation: _situation!,
          fraisScolaireIdPreselectionne: fraisScolaireIdPreselectionne,
        ),
      ),
    );

    if (resultat == true) {
      _afficherSucces('Paiement enregistré avec succès');
      _charger();
    }
  }

  Future<void> _confirmerAnnulation(Paiement paiement) async {
    final motifController = TextEditingController();

    final motif = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler ce paiement ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reçu ${paiement.numeroRecu ?? ''} — ${_formatMontant(paiement.montant)}',
              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: _texte),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motif de l\'annulation *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
            onPressed: () {
              if (motifController.text.trim().isEmpty) return;
              Navigator.pop(context, motifController.text.trim());
            },
            child: const Text('Annuler le paiement'),
          ),
        ],
      ),
    );

    if (motif == null || motif.isEmpty) return;

    try {
      await PaiementService.annulerPaiement(paiement.id!, motif);
      _afficherSucces('Paiement annulé');
      _charger();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _situation == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _ouvrirNouveauPaiement(),
              backgroundColor: _indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Nouveau paiement',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: _indigo))
            : _erreur != null
                ? _vueErreur()
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      children: [
                        _enTete(),
                        const SizedBox(height: 16),
                        _cartesResume(),
                        const SizedBox(height: 20),
                        SSMSectionTitre(titre: 'Détail par frais'),
                        if (_situation!.detailParFrais.isEmpty)
                          _messageVide('Aucun frais scolaire applicable pour cet élève.')
                        else
                          ..._situation!.detailParFrais.map(_carteDetailFrais),
                        const SizedBox(height: 20),
                        SSMSectionTitre(titre: 'Historique des paiements'),
                        if (_situation!.historique.isEmpty)
                          _messageVide('Aucun paiement enregistré.')
                        else
                          ..._situation!.historique.map(_cartePaiement),
                      ],
                    ),
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

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(message, style: GoogleFonts.inter(color: _gris))),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    final nomComplet = widget.eleveNomComplet ?? '${_situation!.eleveNom} ${_situation!.elevePrenom}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Situation financière',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  nomComplet,
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (widget.classeNom != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.classeNom!,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
          SSMBadge(
            label: _libelleStatut(_situation!.statutGlobal),
            couleur: Colors.white,
            icone: _situation!.statutGlobal == 'a_jour' ? Icons.check_circle : Icons.warning_amber,
          ),
        ],
      ),
    );
  }

  Widget _cartesResume() {
    final couleur = _couleurStatut(_situation!.statutGlobal);
    return Row(
      children: [
        Expanded(
          child: SSMStatCard(
            titre: 'Attendu',
            valeur: _formatMontant(_situation!.montantAttendu),
            icone: Icons.account_balance_wallet_outlined,
            couleurIcone: _indigo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMStatCard(
            titre: 'Payé',
            valeur: _formatMontant(_situation!.montantPaye),
            icone: Icons.payments_outlined,
            couleurIcone: _teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMStatCard(
            titre: 'Reste',
            valeur: _formatMontant(_situation!.resteAPayer),
            icone: Icons.error_outline,
            couleurIcone: couleur,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // DÉTAIL PAR FRAIS
  // ══════════════════════════════════════════════════════

  Widget _carteDetailFrais(DetailFrais detail) {
    final couleur = _couleurStatut(detail.statut == 'paye' ? 'a_jour' : detail.statut);

    return GestureDetector(
      onTap: detail.reste > 0
          ? () => _ouvrirNouveauPaiement(fraisScolaireIdPreselectionne: detail.fraisScolaireId)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: couleur, width: 4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.nomFrais,
                        style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce),
                      ),
                    ),
                    _badge(_libelleStatut(detail.statut), couleur),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: detail.progression,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: couleur,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatMontant(detail.montantPaye)} / ${_formatMontant(detail.montantDu)}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _texte),
                    ),
                    if (detail.reste > 0)
                      Text(
                        'Reste ${_formatMontant(detail.reste)}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: couleur),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HISTORIQUE DES PAIEMENTS
  // ══════════════════════════════════════════════════════

  Widget _cartePaiement(Paiement paiement) {
    final estAnnule = paiement.estAnnule;
    final libelle = [paiement.fraisNom, paiement.echeanceLibelle].whereType<String>().join(' — ');

    return Opacity(
      opacity: estAnnule ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (estAnnule ? _gris : _teal).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(paiement.modePaiement.icone, color: estAnnule ? _gris : _teal, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle.isEmpty ? paiement.modePaiement.libelle : libelle,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${paiement.numeroRecu ?? '—'} · ${_formatDateCourt(paiement.datePaiement)}',
                        style: GoogleFonts.inter(fontSize: 11, color: _gris),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatMontant(paiement.montant),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: estAnnule ? _gris : _texteFonce,
                    decoration: estAnnule ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (estAnnule) _badge('Annulé', _rouge) else _badge(paiement.modePaiement.libelle, _indigo),
                const Spacer(),
                RecuPdfViewer(
                  paiementId: paiement.id!,
                  numeroRecu: paiement.numeroRecu,
                  compact: true,
                ),
                if (_estDirecteur && !estAnnule)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: _rouge),
                    tooltip: 'Annuler ce paiement',
                    onPressed: () => _confirmerAnnulation(paiement),
                  ),
              ],
            ),
            if (estAnnule && paiement.motifAnnulation != null) ...[
              const SizedBox(height: 4),
              Text(
                'Motif : ${paiement.motifAnnulation}',
                style: GoogleFonts.inter(fontSize: 11, color: _rouge, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur),
      ),
    );
  }
}
