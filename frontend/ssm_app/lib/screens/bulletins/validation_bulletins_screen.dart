import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/bulletin_model.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/bulletin_service.dart';
import '../../services/historique_statistique_bulletin_service.dart';
import 'apercu_bulletin_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// ══════════════════════════════════════════════════════════
// Validation groupée des bulletins "genere" (pas encore validés) d'une
// classe/période — réservée directeur/censeur, comme la validation des
// notes (voir ParametreValidationNote::ROLES_VALIDATION_DEFAUT côté
// backend, réutilisé ici pour rester cohérent).
// ══════════════════════════════════════════════════════════
class ValidationBulletinsScreen extends StatefulWidget {
  final int anneeScolaireId;
  final int? periodeIdInitiale;
  final int? classeIdInitiale;

  const ValidationBulletinsScreen({
    super.key,
    required this.anneeScolaireId,
    this.periodeIdInitiale,
    this.classeIdInitiale,
  });

  @override
  State<ValidationBulletinsScreen> createState() => _ValidationBulletinsScreenState();
}

class _ValidationBulletinsScreenState extends State<ValidationBulletinsScreen> {
  Utilisateur? _utilisateur;
  bool _chargementUtilisateur = true;

  List<dynamic> _classes = [];
  List<dynamic> _periodes = [];
  int? _classeId;
  int? _periodeId;
  bool _chargementListes = true;

  List<Bulletin> _bulletins = [];
  bool _chargementBulletins = false;
  String? _erreur;

  final Set<int> _selection = {};
  bool _validationEnCours = false;

  bool get _autorise => _utilisateur?.estDirecteur == true || _utilisateur?.estCenseur == true;

  @override
  void initState() {
    super.initState();
    _classeId = widget.classeIdInitiale;
    _periodeId = widget.periodeIdInitiale;
    _charger();
  }

  Future<void> _charger() async {
    try {
      final resultats = await Future.wait([
        AuthService.getUtilisateur(),
        ClasseService.lister(anneeId: widget.anneeScolaireId),
        AnneeService.listerPeriodes(widget.anneeScolaireId),
      ]);
      if (!mounted) return;
      setState(() {
        _utilisateur = resultats[0] as Utilisateur?;
        _classes = _aplatirClasses(resultats[1]);
        _periodes = resultats[2] as List<dynamic>;
        _chargementUtilisateur = false;
        _chargementListes = false;
      });
      if (_autorise && _classeId != null && _periodeId != null) _chargerBulletins();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementUtilisateur = false;
        _chargementListes = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<dynamic> _aplatirClasses(dynamic valeur) {
    final toutes = <dynamic>[];
    void parcourir(dynamic v) {
      if (v is List) {
        toutes.addAll(v);
      } else if (v is Map) {
        for (final sous in v.values) {
          parcourir(sous);
        }
      }
    }

    parcourir(valeur);
    return toutes;
  }

  void _changerClasse(int? classeId) {
    setState(() {
      _classeId = classeId;
      _bulletins = [];
      _selection.clear();
    });
    if (classeId != null && _periodeId != null) _chargerBulletins();
  }

  void _changerPeriode(int? periodeId) {
    setState(() {
      _periodeId = periodeId;
      _bulletins = [];
      _selection.clear();
    });
    if (periodeId != null && _classeId != null) _chargerBulletins();
  }

  Future<void> _chargerBulletins() async {
    setState(() {
      _chargementBulletins = true;
      _erreur = null;
      _selection.clear();
    });
    try {
      final tous = await BulletinService.listerBulletinsClasse(classeId: _classeId!, periodeId: _periodeId!);
      if (!mounted) return;
      setState(() {
        _bulletins = tous.where((b) => b.statut == StatutBulletin.genere).toList();
        _chargementBulletins = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementBulletins = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _basculerSelection(int bulletinId) {
    setState(() {
      if (_selection.contains(bulletinId)) {
        _selection.remove(bulletinId);
      } else {
        _selection.add(bulletinId);
      }
    });
  }

  void _basculerToutSelectionner() {
    setState(() {
      if (_selection.length == _bulletins.length) {
        _selection.clear();
      } else {
        _selection
          ..clear()
          ..addAll(_bulletins.map((b) => b.id));
      }
    });
  }

  // Aucune route backend ne valide une liste précise de bulletin_ids : on
  // valide chacun individuellement (HistoriqueStatistiqueBulletinService.
  // validerBulletin), en continuant même si l'un d'eux échoue.
  Future<void> _validerSelection() async {
    if (_selection.isEmpty) return;
    final confirme = await _confirmer(
      titre: 'Valider la sélection ?',
      message: '${_selection.length} bulletin(s) sélectionné(s) seront validés officiellement.',
    );
    if (confirme != true) return;

    setState(() => _validationEnCours = true);
    var reussis = 0;
    var echecs = 0;
    for (final id in _selection.toList()) {
      try {
        await HistoriqueStatistiqueBulletinService.validerBulletin(id);
        reussis++;
      } catch (_) {
        echecs++;
      }
    }
    if (!mounted) return;
    setState(() => _validationEnCours = false);
    _afficherResultatValidation(reussis, echecs);
    _chargerBulletins();
  }

  Future<void> _validerTous() async {
    if (_bulletins.isEmpty) return;
    final confirme = await _confirmer(
      titre: 'Valider tous les bulletins ?',
      message: '${_bulletins.length} bulletin(s) "généré(s)" de cette classe et cette période seront validés officiellement.',
    );
    if (confirme != true) return;

    setState(() => _validationEnCours = true);
    try {
      final nombre = await HistoriqueStatistiqueBulletinService.validerEnMasse(
        classeId: _classeId!,
        periodeId: _periodeId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nombre bulletin(s) validé(s)'), backgroundColor: _vert),
      );
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _validationEnCours = false);
      _chargerBulletins();
    }
  }

  Future<bool?> _confirmer({required String titre, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _afficherResultatValidation(int reussis, int echecs) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(echecs == 0 ? '$reussis bulletin(s) validé(s)' : '$reussis validé(s), $echecs échec(s)'),
        backgroundColor: echecs == 0 ? _vert : Colors.orange,
      ),
    );
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  void _ouvrirApercu(Bulletin b) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApercuBulletinScreen(bulletinId: b.id, resume: b)),
    ).then((_) => _chargerBulletins());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Validation des bulletins', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargementUtilisateur || _chargementListes
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : !_autorise
              ? _vueNonAutorise()
              : _corps(),
      bottomNavigationBar: (_autorise && !_chargementUtilisateur && !_chargementListes) ? _barreActions() : null,
    );
  }

  Widget _vueNonAutorise() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: _gris, size: 40),
            const SizedBox(height: 12),
            Text(
              'Seuls le directeur ou le censeur peuvent valider des bulletins.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _texte),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _carteSelecteurs(),
          const SizedBox(height: 12),
          if (_bulletins.isNotEmpty)
            Row(
              children: [
                Text('${_bulletins.length} bulletin(s) en attente', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                const Spacer(),
                TextButton(
                  onPressed: _basculerToutSelectionner,
                  child: Text(_selection.length == _bulletins.length ? 'Tout désélectionner' : 'Tout sélectionner'),
                ),
              ],
            ),
          Expanded(child: _listeBulletins()),
        ],
      ),
    );
  }

  Widget _carteSelecteurs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gris.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _classeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Classe', border: OutlineInputBorder(), isDense: true),
              items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
              onChanged: _changerClasse,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _periodeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Période', border: OutlineInputBorder(), isDense: true),
              items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
              onChanged: _changerPeriode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listeBulletins() {
    if (_chargementBulletins) {
      return const Center(child: CircularProgressIndicator(color: _indigo));
    }
    if (_erreur != null) {
      return Center(child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge)));
    }
    if (_classeId == null || _periodeId == null) {
      return Center(child: Text('Sélectionnez une classe et une période.', style: GoogleFonts.inter(color: _gris)));
    }
    if (_bulletins.isEmpty) {
      return Center(
        child: Text('Aucun bulletin en attente de validation pour cette sélection.', style: GoogleFonts.inter(color: _gris)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _bulletins.length,
      itemBuilder: (context, index) {
        final b = _bulletins[index];
        final coche = _selection.contains(b.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _ouvrirApercu(b),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: coche ? _indigo.withValues(alpha: 0.5) : _gris.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Checkbox(value: coche, onChanged: (_) => _basculerSelection(b.id), activeColor: _indigo),
                    if (b.rang != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('${b.rang}${b.rangExAequo ? 'ex' : ''}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _indigo)),
                      ),
                    Expanded(
                      child: Text(
                        b.nomEleve ?? 'Élève #${b.eleveId}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${b.moyenneGenerale.toStringAsFixed(2)}/20',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texteFonce)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: _gris, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _barreActions() {
    if (_bulletins.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_validationEnCours || _selection.isEmpty) ? null : _validerSelection,
                style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
                icon: const Icon(Icons.playlist_add_check, size: 18),
                label: Text('Valider la sélection (${_selection.length})'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _validationEnCours ? null : _validerTous,
                style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white),
                icon: _validationEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.done_all, size: 18),
                label: Text('Valider tous (${_bulletins.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
