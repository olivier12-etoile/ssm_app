import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/caisse_model.dart';
import '../../services/caisse_service.dart';
import '../../services/paiement_service.dart';
import '../../services/auth_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatMontant(double m) {
  final entier = m.round();
  final signe = entier < 0 ? '-' : '';
  final texte = entier.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$signe$buffer FCFA';
}

String _formatDateHeure(DateTime? d) {
  if (d == null) return '—';
  final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final heure = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '$date à $heure';
}

String _formatDateApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ══════════════════════════════════════════════════════════
// Écran principal — Gestion de caisse (directeur / secrétaire)
// ══════════════════════════════════════════════════════════
class GestionCaisseScreen extends StatefulWidget {
  const GestionCaisseScreen({super.key});

  @override
  State<GestionCaisseScreen> createState() => _GestionCaisseScreenState();
}

class _GestionCaisseScreenState extends State<GestionCaisseScreen> {
  bool _chargement = true;
  bool _accesAutorise = true;
  String? _erreur;

  List<Caisse> _caisses = [];
  final Map<int, SessionCaisse?> _sessionsActives = {};

  int? _caisseSelectionneeId;
  List<SessionCaisse> _historique = [];
  bool _chargementHistorique = false;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final autorise = utilisateur?.estDirecteur == true || utilisateur?.estSecretaire == true;
      if (!autorise) {
        setState(() {
          _accesAutorise = false;
          _chargement = false;
        });
        return;
      }
      await _chargerCaisses();
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerCaisses() async {
    try {
      final caisses = await CaisseService.getCaisses();
      final sessions = <int, SessionCaisse?>{};
      for (final c in caisses) {
        try {
          sessions[c.id!] = await CaisseService.getSessionActive(c.id!);
        } catch (_) {
          sessions[c.id!] = null;
        }
      }

      final caisseSelectionnee = _caisseSelectionneeId != null &&
              caisses.any((c) => c.id == _caisseSelectionneeId)
          ? _caisseSelectionneeId
          : (caisses.isNotEmpty ? caisses.first.id : null);

      setState(() {
        _caisses = caisses;
        _sessionsActives
          ..clear()
          ..addAll(sessions);
        _caisseSelectionneeId = caisseSelectionnee;
        _chargement = false;
        _erreur = null;
      });

      if (caisseSelectionnee != null) {
        await _chargerHistorique(caisseSelectionnee);
      }
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerHistorique(int caisseId) async {
    setState(() => _chargementHistorique = true);
    try {
      final historique = await CaisseService.getHistoriqueSessions(caisseId);
      if (!mounted) return;
      setState(() {
        _historique = historique;
        _chargementHistorique = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historique = [];
        _chargementHistorique = false;
      });
    }
  }

  void _selectionnerCaisse(int caisseId) {
    setState(() => _caisseSelectionneeId = caisseId);
    _chargerHistorique(caisseId);
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

  // ══════════════════════════════════════════════════════
  // Actions
  // ══════════════════════════════════════════════════════

  Future<void> _creerCaisseDialog() async {
    final controller = TextEditingController();

    final nom = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Créer une caisse'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Nom de la caisse',
            hintText: 'Ex : Caisse principale',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (nom == null) return;

    try {
      await CaisseService.creerCaisse(nom);
      _afficherSucces('Caisse créée avec succès');
      await _chargerCaisses();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _ouvrirCaisseDialog(Caisse caisse) async {
    final controller = TextEditingController();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ouvrir « ${caisse.nom} »'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: 'Montant initial (fond de caisse)',
            suffixText: 'FCFA',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ouvrir la caisse'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    final montant = double.tryParse(controller.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (montant == null || montant < 0) {
      _afficherErreur('Montant initial invalide.');
      return;
    }

    try {
      await CaisseService.ouvrirCaisse(caisse.id!, montant);
      _afficherSucces('Caisse ouverte avec succès');
      await _chargerCaisses();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _fermerCaisseDialog(SessionCaisse session) async {
    final resultat = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogFermetureCaisse(session: session),
    );

    if (resultat == true) {
      _afficherSucces('Caisse fermée avec succès');
      await _chargerCaisses();
    }
  }

  // ══════════════════════════════════════════════════════
  // Construction
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Gestion de caisse')),
      body: SafeArea(
        child: !_accesAutorise
            ? _vueAccesRefuse()
            : _chargement
                ? const Center(child: CircularProgressIndicator(color: _indigo))
                : _erreur != null
                    ? _vueErreur()
                    : _caisses.isEmpty
                        ? _vueCreerPremiereCaisse()
                        : RefreshIndicator(
                            onRefresh: _chargerCaisses,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Caisses',
                                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: _texteFonce),
                                    ),
                                    TextButton.icon(
                                      onPressed: _creerCaisseDialog,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Nouvelle caisse'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._caisses.map(_carteCaisse),
                                if (_caisseSelectionneeId != null) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Historique des sessions',
                                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: _texteFonce),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_chargementHistorique)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: CircularProgressIndicator(color: _indigo),
                                      ),
                                    )
                                  else if (_historique.isEmpty)
                                    _messageVide('Aucune session clôturée pour cette caisse.')
                                  else
                                    ..._historique.map(_carteHistorique),
                                ],
                              ],
                            ),
                          ),
      ),
    );
  }

  Widget _vueAccesRefuse() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: _gris, size: 40),
            const SizedBox(height: 12),
            Text(
              'Accès réservé au directeur et à la secrétaire.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _texte),
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
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initialiser,
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

  Widget _vueCreerPremiereCaisse() {
    final controller = TextEditingController();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.point_of_sale, color: _indigo, size: 48),
            const SizedBox(height: 16),
            Text(
              'Aucune caisse créée',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: _texteFonce),
            ),
            const SizedBox(height: 6),
            Text(
              'Créez une première caisse pour commencer à suivre les sessions d\'encaissement.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _texte),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 280,
              child: TextField(
                controller: controller,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Nom de la caisse',
                  hintText: 'Ex : Caisse principale',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                try {
                  await CaisseService.creerCaisse(controller.text.trim());
                  _afficherSucces('Caisse créée avec succès');
                  await _chargerCaisses();
                } catch (e) {
                  _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer la caisse'),
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Carte caisse
  // ══════════════════════════════════════════════════════

  Widget _carteCaisse(Caisse caisse) {
    final session = _sessionsActives[caisse.id];
    final estOuverte = session != null;
    final estSelectionnee = _caisseSelectionneeId == caisse.id;

    return GestureDetector(
      onTap: () => _selectionnerCaisse(caisse.id!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: estSelectionnee ? _indigo.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.6),
                width: estSelectionnee ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (estOuverte ? _vert : _gris).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.point_of_sale, color: estOuverte ? _vert : _gris, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caisse.nom,
                            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce),
                          ),
                          const SizedBox(height: 4),
                          _badgePilule(estOuverte ? 'Ouverte' : 'Fermée', estOuverte ? _vert : _gris),
                        ],
                      ),
                    ),
                  ],
                ),
                if (estOuverte) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ligneInfo('Fond de caisse', _formatMontant(session.montantInitial), mono: true),
                        const SizedBox(height: 4),
                        _ligneInfo('Ouverte le', _formatDateHeure(session.dateOuverture)),
                        if (session.ouvertParNom != null) ...[
                          const SizedBox(height: 4),
                          _ligneInfo('Ouverte par', session.ouvertParNom!),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: estOuverte
                      ? OutlinedButton.icon(
                          onPressed: () => _fermerCaisseDialog(session),
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Fermer la caisse'),
                          style: OutlinedButton.styleFrom(foregroundColor: _rouge, side: const BorderSide(color: _rouge)),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _ouvrirCaisseDialog(caisse),
                          icon: const Icon(Icons.lock_open, size: 18),
                          label: const Text('Ouvrir la caisse'),
                          style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ligneInfo(String label, String valeur, {bool mono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: _gris)),
        Text(
          valeur,
          style: mono
              ? GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)
              : GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texte),
        ),
      ],
    );
  }

  Widget _badgePilule(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
    );
  }

  // ══════════════════════════════════════════════════════
  // Historique des sessions
  // ══════════════════════════════════════════════════════

  Widget _carteHistorique(SessionCaisse s) {
    final ecart = s.ecart ?? 0;
    final ecartNul = ecart.abs() < 0.01;
    final couleurEcart = ecartNul ? _vert : _rouge;

    return Container(
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
              Expanded(
                child: Text(
                  '${_formatDateHeure(s.dateOuverture)} → ${_formatDateHeure(s.dateFermeture)}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce),
                ),
              ),
              _badgePilule(
                ecartNul ? 'Écart nul' : 'Écart ${ecart > 0 ? '+' : ''}${_formatMontant(ecart)}',
                couleurEcart,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statHistorique('Initial', s.montantInitial)),
              Expanded(child: _statHistorique('Théorique', s.montantTheorique ?? 0)),
              Expanded(child: _statHistorique('Réel', s.montantReel ?? 0)),
            ],
          ),
          if (s.fermeParNom != null) ...[
            const SizedBox(height: 8),
            Text('Fermée par ${s.fermeParNom}', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
          ],
          if (s.observationFermeture != null && s.observationFermeture!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Observation : ${s.observationFermeture}',
              style: GoogleFonts.inter(fontSize: 11, color: _texte, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statHistorique(String label, double montant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _gris)),
        const SizedBox(height: 2),
        Text(
          _formatMontant(montant),
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texteFonce),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// Dialog de fermeture de caisse
// ══════════════════════════════════════════════════════════
class _DialogFermetureCaisse extends StatefulWidget {
  final SessionCaisse session;

  const _DialogFermetureCaisse({required this.session});

  @override
  State<_DialogFermetureCaisse> createState() => _DialogFermetureCaisseState();
}

class _DialogFermetureCaisseState extends State<_DialogFermetureCaisse> {
  final TextEditingController _montantReelController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();

  double? _montantTheoriqueEstime;
  bool _chargementEstimation = true;
  bool _envoiEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _estimerMontantTheorique();
    _montantReelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _montantReelController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  // Estimation live à partir des paiements espèces enregistrés depuis
  // l'ouverture de la session (endpoint générique /paiements). Le montant
  // théorique définitif — exact, basé sur les paiements réellement rattachés
  // à cette session — est recalculé côté serveur à la confirmation.
  Future<void> _estimerMontantTheorique() async {
    try {
      final paiements = await PaiementService.lister(
        modePaiement: 'especes',
        dateDebut: _formatDateApi(widget.session.dateOuverture),
        dateFin: _formatDateApi(DateTime.now()),
      );
      final totalEspeces = paiements
          .where((p) => p['statut'] == 'valide')
          .fold<double>(0, (total, p) => total + double.parse(p['montant'].toString()));
      if (!mounted) return;
      setState(() {
        _montantTheoriqueEstime = widget.session.montantInitial + totalEspeces;
        _chargementEstimation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _montantTheoriqueEstime = widget.session.montantInitial;
        _chargementEstimation = false;
      });
    }
  }

  double? get _ecart {
    final reel = double.tryParse(_montantReelController.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (reel == null || _montantTheoriqueEstime == null) return null;
    return reel - _montantTheoriqueEstime!;
  }

  Future<void> _confirmer() async {
    final reel = double.tryParse(_montantReelController.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (reel == null || reel < 0) {
      setState(() => _erreur = 'Montant réel invalide.');
      return;
    }

    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });

    try {
      await CaisseService.fermerCaisse(
        widget.session.id!,
        reel,
        _observationController.text.trim().isEmpty ? null : _observationController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _envoiEnCours = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ecart = _ecart;
    final couleurEcart = ecart == null ? _gris : (ecart.abs() < 0.01 ? _vert : _ambre);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: _rouge, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Fermer la caisse',
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: _texteFonce),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Montant théorique estimé', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
                      const SizedBox(height: 4),
                      _chargementEstimation
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _formatMontant(_montantTheoriqueEstime ?? 0),
                              style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        'Fond initial + paiements espèces depuis l\'ouverture — le montant définitif est recalculé à la confirmation.',
                        style: GoogleFonts.inter(fontSize: 10, color: _gris, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('Montant réel compté *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texte)),
                const SizedBox(height: 6),
                TextField(
                  controller: _montantReelController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(suffixText: 'FCFA', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                if (ecart != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: couleurEcart.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: couleurEcart.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ecart.abs() < 0.01 ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: couleurEcart,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ecart.abs() < 0.01 ? 'Écart nul' : 'Écart : ${ecart > 0 ? '+' : ''}${_formatMontant(ecart)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: couleurEcart),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                Text('Observation (optionnel)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texte)),
                const SizedBox(height: 6),
                TextField(
                  controller: _observationController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: const InputDecoration(hintText: 'Remarque sur la clôture…', border: OutlineInputBorder()),
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: 10),
                  Text(_erreur!, style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
                ],

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _envoiEnCours ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _envoiEnCours ? null : _confirmer,
                      style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
                      child: _envoiEnCours
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirmer la fermeture'),
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
}
