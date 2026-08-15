import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/paiement_model.dart';
import '../../models/utilisateur.dart';
import '../../models/caisse_model.dart';
import '../../services/paiement_service.dart';
import '../../services/auth_service.dart';
import '../../services/caisse_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/recu_pdf_viewer.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import '../../widgets/ssm/ssm_statut_financier_badge.dart';
import '../../widgets/correction_paiement_dialog.dart';
import 'nouveau_paiement_screen.dart';

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

// Palette unique du statut financier (3 états dérivés côté client) : la
// même que ssm_pill.paye/.partiel/.retard, pour rester cohérent avec le
// badge 4-états (SSMStatutFinancierBadge) et le reste du module.
Color _couleurStatut(String statut) {
  switch (statut) {
    case 'a_jour':
    case 'paye':
      return SSMPalette.teal;
    case 'partiel':
      return SSMPalette.ambre;
    default:
      return SSMPalette.rouge;
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

SSMPill _pillStatut(String statut, {Key? key}) {
  switch (statut) {
    case 'a_jour':
    case 'paye':
      return SSMPill.paye(key: key, label: _libelleStatut(statut));
    case 'partiel':
      return SSMPill.partiel(key: key, label: _libelleStatut(statut));
    default:
      return SSMPill.retard(key: key, label: _libelleStatut(statut));
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
  StatutFinancierEleve? _statutFinancier;
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
      _chargerStatutFinancier();
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Chargé séparément du reste : un échec ici (ex. année scolaire non
  // active) ne doit pas empêcher l'affichage du reste de la situation.
  Future<void> _chargerStatutFinancier() async {
    try {
      final statut = await CaisseService.getStatutFinancier(widget.eleveId);
      if (!mounted) return;
      setState(() => _statutFinancier = statut);
    } catch (_) {
      // Le badge reste simplement masqué si l'appel échoue.
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.teal),
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
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Annuler ce paiement ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reçu ${paiement.numeroRecu ?? ''} — ${_formatMontant(paiement.montant)}',
              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: SSMPalette.texte2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motif de l\'annulation *',
                labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Retour', style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
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

  Future<void> _corrigerPaiement(Paiement paiement) async {
    final resultat = await CorrectionPaiementDialog.afficher(context, paiement);
    if (resultat == true) {
      _afficherSucces('Paiement corrigé avec succès');
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      floatingActionButton: _situation == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _ouvrirNouveauPaiement(),
              backgroundColor: SSMPalette.indigo,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Nouveau paiement',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
            : _erreur != null
                ? _vueErreur()
                : RefreshIndicator(
                    onRefresh: _charger,
                    color: SSMPalette.indigo,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      children: [
                        _entete(),
                        if (_statutFinancier != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: SSMStatutFinancierBadge(
                              statut: _statutFinancier!.statut,
                              taille: SSMTailleBadge.large,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _cartesResume(),
                        const SizedBox(height: 20),
                        SSMPanel(
                          titre: 'Détail par frais',
                          child: _situation!.detailParFrais.isEmpty
                              ? _messageVide('Aucun frais scolaire applicable pour cet élève.')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < _situation!.detailParFrais.length; i++) ...[
                                      if (i > 0) const SizedBox(height: 10),
                                      _ligneDetailFrais(_situation!.detailParFrais[i]),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        SSMPanel(
                          titre: 'Historique des paiements',
                          padding: EdgeInsets.zero,
                          child: _situation!.historique.isEmpty
                              ? _messageVide('Aucun paiement enregistré.')
                              : SSMDataTable(
                                  colonnes: const [
                                    SSMDataColumn('Reçu'),
                                    SSMDataColumn('Montant'),
                                    SSMDataColumn('Mode'),
                                    SSMDataColumn('Date'),
                                    SSMDataColumn('Statut'),
                                    SSMDataColumn('Actions'),
                                  ],
                                  lignes: [for (final p in _situation!.historique) _lignePaiement(p)],
                                ),
                        ),
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
            Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(message, style: GoogleFonts.inter(color: SSMPalette.texte3))),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _entete() {
    final nomComplet = widget.eleveNomComplet ?? '${_situation!.eleveNom} ${_situation!.elevePrenom}';

    return SSMSousEnTete(
      titre: nomComplet,
      sousTitre: widget.classeNom ?? 'Situation financière',
      onRetour: () => Navigator.pop(context),
      actions: [_pillStatut(_situation!.statutGlobal)],
    );
  }

  Widget _cartesResume() {
    final couleur = _couleurStatut(_situation!.statutGlobal);
    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 520 ? 3 : 1;
      final cartes = [
        SSMStatCard(icone: Icons.account_balance_wallet_outlined, couleur: SSMPalette.indigo, valeur: _formatMontant(_situation!.montantAttendu), label: 'Attendu'),
        SSMStatCard(icone: Icons.payments_outlined, couleur: SSMPalette.teal, valeur: _formatMontant(_situation!.montantPaye), label: 'Payé'),
        SSMStatCard(icone: Icons.error_outline, couleur: couleur, valeur: _formatMontant(_situation!.resteAPayer), label: 'Reste'),
      ];
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 108,
        ),
        itemBuilder: (context, i) => cartes[i],
      );
    });
  }

  // ══════════════════════════════════════════════════════
  // DÉTAIL PAR FRAIS
  // ══════════════════════════════════════════════════════

  Widget _ligneDetailFrais(DetailFrais detail) {
    final statutNormalise = detail.statut == 'paye' ? 'a_jour' : detail.statut;
    final couleur = _couleurStatut(statutNormalise);

    return Material(
      color: detail.reste > 0 ? const Color(0xFFF9FAFB) : Colors.transparent,
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        onTap: detail.reste > 0 ? () => _ouvrirNouveauPaiement(fraisScolaireIdPreselectionne: detail.fraisScolaireId) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.nomFrais,
                      style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                    ),
                  ),
                  _pillStatut(detail.statut),
                ],
              ),
              const SizedBox(height: 8),
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
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.texte2),
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
    );
  }

  // ══════════════════════════════════════════════════════
  // HISTORIQUE DES PAIEMENTS
  // ══════════════════════════════════════════════════════

  List<Widget> _lignePaiement(Paiement paiement) {
    final estAnnule = paiement.estAnnule;
    final libelle = [paiement.fraisNom, paiement.echeanceLibelle].whereType<String>().join(' — ');

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(paiement.numeroRecu ?? '—', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          if (libelle.isNotEmpty)
            Text(libelle, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (estAnnule && paiement.motifAnnulation != null)
            Text('Motif : ${paiement.motifAnnulation}', style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.rouge, fontStyle: FontStyle.italic)),
        ],
      ),
      Text(
        _formatMontant(paiement.montant),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: estAnnule ? SSMPalette.texte3 : SSMPalette.texte1,
          decoration: estAnnule ? TextDecoration.lineThrough : null,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(paiement.modePaiement.icone, size: 15, color: estAnnule ? SSMPalette.texte3 : SSMPalette.teal),
          const SizedBox(width: 5),
          Text(paiement.modePaiement.libelle, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
        ],
      ),
      Text(_formatDateCourt(paiement.datePaiement), style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      estAnnule ? const SSMPill.retard(label: 'Annulé') : const SSMPill.paye(label: 'Validé'),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RecuPdfViewer(paiementId: paiement.id!, numeroRecu: paiement.numeroRecu, compact: true),
          if (_estDirecteur && !estAnnule) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: SSMPalette.indigo, size: 18),
              tooltip: 'Corriger ce paiement',
              onPressed: () => _corrigerPaiement(paiement),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: SSMPalette.rouge, size: 18),
              tooltip: 'Annuler ce paiement',
              onPressed: () => _confirmerAnnulation(paiement),
            ),
          ],
        ],
      ),
    ];
  }
}
