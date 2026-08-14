import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/permission_securite_model.dart';
import '../../services/auth_service.dart';
import '../../services/permission_securite_service.dart';
import '../../services/utilisateur_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

String _formatDateHeure(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════
// Section Sécurité : mot de passe, sessions actives, déconnexion
// automatique, historique des connexions et journal des actions.
// ══════════════════════════════════════════════════════════
class SecuriteScreen extends StatefulWidget {
  const SecuriteScreen({super.key});

  @override
  State<SecuriteScreen> createState() => _SecuriteScreenState();
}

class _SecuriteScreenState extends State<SecuriteScreen> {
  final _ancienController = TextEditingController();
  final _nouveauController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _motDePasseEnCours = false;
  String? _erreurMotDePasse;

  Utilisateur? _utilisateur;
  List<SessionActive> _sessions = [];
  int? _delaiInactivite;
  bool _deconnexionAutoActive = false;
  double _delaiChoisi = 30;

  bool _chargement = true;
  bool _chargementDelaiEnCours = false;
  String? _erreur;

  bool get _estDirecteur => _utilisateur?.estDirecteur == true;
  bool get _estGestionnaire => _utilisateur?.estDirecteur == true || _utilisateur?.estCenseur == true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _ancienController.dispose();
    _nouveauController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        AuthService.getUtilisateur(),
        PermissionSecuriteService.getSessionsActives(),
        PermissionSecuriteService.getDeconnexionAutoConfig(),
      ]);
      if (!mounted) return;
      final delai = resultats[2] as int?;
      setState(() {
        _utilisateur = resultats[0] as Utilisateur?;
        _sessions = resultats[1] as List<SessionActive>;
        _delaiInactivite = delai;
        _deconnexionAutoActive = delai != null;
        _delaiChoisi = (delai ?? 30).toDouble().clamp(5, 240);
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

  // ── Mot de passe ──────────────────────────────────────────

  Future<void> _changerMotDePasse() async {
    setState(() => _erreurMotDePasse = null);

    if (_nouveauController.text.trim().isEmpty) {
      setState(() => _erreurMotDePasse = 'Le nouveau mot de passe est obligatoire.');
      return;
    }
    if (_nouveauController.text != _confirmationController.text) {
      setState(() => _erreurMotDePasse = 'La confirmation ne correspond pas au nouveau mot de passe.');
      return;
    }

    setState(() => _motDePasseEnCours = true);
    try {
      await PermissionSecuriteService.changerMotDePasse(
        ancien: _ancienController.text,
        nouveau: _nouveauController.text,
        confirmation: _confirmationController.text,
      );
      if (!mounted) return;
      _ancienController.clear();
      _nouveauController.clear();
      _confirmationController.clear();
      setState(() => _motDePasseEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe changé avec succès'), backgroundColor: _vert),
      );
    } catch (e) {
      setState(() {
        _motDePasseEnCours = false;
        _erreurMotDePasse = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Sessions ──────────────────────────────────────────────

  Future<void> _revoquerSession(SessionActive session) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Révoquer cette session ?'),
        content: Text('L\'appareil "${session.appareil ?? 'inconnu'}" sera déconnecté immédiatement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await PermissionSecuriteService.revoquerSession(session.tokenId);
      if (!mounted) return;
      setState(() => _sessions = _sessions.where((s) => s.tokenId != session.tokenId).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session révoquée avec succès'), backgroundColor: _vert),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
      );
    }
  }

  // ── Déconnexion automatique ───────────────────────────────

  Future<void> _enregistrerDelai() async {
    setState(() => _chargementDelaiEnCours = true);
    try {
      final minutes = _deconnexionAutoActive ? _delaiChoisi.round() : null;
      await PermissionSecuriteService.updateDeconnexionAutoConfig(minutes);
      if (!mounted) return;
      setState(() {
        _delaiInactivite = minutes;
        _chargementDelaiEnCours = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètre de déconnexion automatique enregistré'), backgroundColor: _vert),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementDelaiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
      );
    }
  }

  bool get _delaiModifie => _deconnexionAutoActive != (_delaiInactivite != null) || (_deconnexionAutoActive && _delaiChoisi.round() != _delaiInactivite);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Sécurité', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null
              ? _carteErreur(_erreur!, _charger)
              : RefreshIndicator(onRefresh: _charger, child: _corps()),
    );
  }

  Widget _corps() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _titreSection('Changer le mot de passe'),
        _carteBlanche(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_erreurMotDePasse != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: _rouge.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(_erreurMotDePasse!, style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
                ),
              ],
              _champMotDePasse(_ancienController, 'Ancien mot de passe'),
              const SizedBox(height: 12),
              _champMotDePasse(_nouveauController, 'Nouveau mot de passe'),
              const SizedBox(height: 4),
              Text('Au moins 8 caractères, majuscule, minuscule et chiffre.', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
              const SizedBox(height: 12),
              _champMotDePasse(_confirmationController, 'Confirmer le nouveau mot de passe'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _motDePasseEnCours ? null : _changerMotDePasse,
                  child: _motDePasseEnCours
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Changer le mot de passe'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _titreSection('Sessions actives'),
        _sessions.isEmpty
            ? _carteBlanche(child: Text('Aucune session active.', style: GoogleFonts.inter(fontSize: 12, color: _texte)))
            : _carteBlanche(
                padding: EdgeInsets.zero,
                child: Column(
                  children: _sessions
                      .map((s) => _ligneSession(s, dernier: s == _sessions.last))
                      .toList(),
                ),
              ),
        const SizedBox(height: 24),
        _titreSection('Déconnexion automatique'),
        _carteBlanche(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _indigo,
                value: _deconnexionAutoActive,
                title: const Text('Déconnexion automatique en cas d\'inactivité'),
                onChanged: !_estDirecteur ? null : (v) => setState(() => _deconnexionAutoActive = v),
              ),
              if (_deconnexionAutoActive) ...[
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _delaiChoisi,
                        min: 5,
                        max: 240,
                        divisions: 47,
                        activeColor: _indigo,
                        label: '${_delaiChoisi.round()} min',
                        onChanged: !_estDirecteur ? null : (v) => setState(() => _delaiChoisi = v),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${_delaiChoisi.round()} min',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce),
                      ),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Les utilisateurs restent connectés indéfiniment.', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                ),
              if (_estDirecteur) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
                    onPressed: !_delaiModifie || _chargementDelaiEnCours ? null : _enregistrerDelai,
                    child: _chargementDelaiEnCours
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _titreSection('Historique'),
        _carteBlanche(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: _indigo),
                title: const Text('Historique des connexions'),
                subtitle: Text(_estDirecteur ? 'Toutes les connexions de l\'école' : 'Vos connexions', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                trailing: const Icon(Icons.chevron_right, color: _gris),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoriqueConnexionsScreen(estDirecteur: _estDirecteur))),
              ),
              if (_estGestionnaire) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: _indigo),
                  title: const Text('Journal des actions'),
                  subtitle: Text('Directeur et censeur uniquement', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  trailing: const Icon(Icons.chevron_right, color: _gris),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalActionsScreen())),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligneSession(SessionActive session, {required bool dernier}) {
    return Container(
      decoration: BoxDecoration(border: dernier ? null : Border(bottom: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.7)))),
      child: ListTile(
        leading: Icon(Icons.devices_other, color: session.actuelle ? _teal : _gris),
        title: Text(session.appareil ?? 'Appareil inconnu', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
        subtitle: Text(
          'Dernière activité : ${_formatDateHeure(session.derniereActivite)}',
          style: GoogleFonts.inter(fontSize: 11, color: _texte),
        ),
        trailing: session.actuelle
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('Session actuelle', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _teal)),
              )
            : TextButton(
                onPressed: () => _revoquerSession(session),
                style: TextButton.styleFrom(foregroundColor: _rouge),
                child: const Text('Révoquer'),
              ),
      ),
    );
  }

  Widget _champMotDePasse(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder()),
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
    );
  }

  Widget _carteBlanche({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onReessayer,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Écran dédié — Historique des connexions (paginé, filtrable par
// utilisateur si directeur).
// ══════════════════════════════════════════════════════════
class HistoriqueConnexionsScreen extends StatefulWidget {
  final bool estDirecteur;
  const HistoriqueConnexionsScreen({super.key, required this.estDirecteur});

  @override
  State<HistoriqueConnexionsScreen> createState() => _HistoriqueConnexionsScreenState();
}

class _HistoriqueConnexionsScreenState extends State<HistoriqueConnexionsScreen> {
  List<ConnexionHistorique> _lignes = [];
  List<dynamic> _utilisateurs = [];
  int? _userIdFiltre;
  int _page = 1;
  int _dernierePage = 1;
  bool _chargement = true;
  bool _chargementPage = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
    if (widget.estDirecteur) _chargerUtilisateurs();
  }

  Future<void> _chargerUtilisateurs() async {
    try {
      final data = await UtilisateurService.lister();
      if (mounted) setState(() => _utilisateurs = (data['data'] as List?) ?? []);
    } catch (_) {
      // Le filtre reste simplement vide si le chargement échoue.
    }
  }

  Future<void> _charger({bool ajouter = false}) async {
    setState(() {
      if (ajouter) {
        _chargementPage = true;
      } else {
        _chargement = true;
        _page = 1;
      }
      _erreur = null;
    });
    try {
      final data = await PermissionSecuriteService.getHistoriqueConnexions(userId: _userIdFiltre, page: _page);
      if (!mounted) return;
      setState(() {
        _lignes = ajouter ? [..._lignes, ...data['items'] as List<ConnexionHistorique>] : data['items'] as List<ConnexionHistorique>;
        _dernierePage = data['dernierePage'] as int;
        _chargement = false;
        _chargementPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _chargementPage = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _chargerPageSuivante() {
    if (_page >= _dernierePage || _chargementPage) return;
    _page++;
    _charger(ajouter: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Historique des connexions', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Column(
        children: [
          if (widget.estDirecteur && _utilisateurs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<int?>(
                initialValue: _userIdFiltre,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Filtrer par utilisateur', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tous les utilisateurs')),
                  ..._utilisateurs.map((u) => DropdownMenuItem<int?>(value: u['id'] as int, child: Text(u['name'] as String? ?? '—'))),
                ],
                onChanged: (v) {
                  setState(() => _userIdFiltre = v);
                  _charger();
                },
              ),
            ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator(color: _indigo))
                : _erreur != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge))))
                    : _lignes.isEmpty
                        ? Center(child: Text('Aucune connexion enregistrée.', style: GoogleFonts.inter(color: _gris)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _lignes.length + (_page < _dernierePage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _lignes.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: _chargementPage
                                        ? const CircularProgressIndicator(color: _indigo)
                                        : TextButton(onPressed: _chargerPageSuivante, child: const Text('Charger plus')),
                                  ),
                                );
                              }
                              final c = _lignes[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const CircleAvatar(radius: 16, backgroundColor: Color(0x1A1E3A8A), child: Icon(Icons.login, size: 16, color: _indigo)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.nomUser ?? 'Utilisateur #${c.userId}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                                          const SizedBox(height: 2),
                                          Text(
                                            [_formatDateHeure(c.dateConnexion), if (c.ip != null) c.ip!].join(' · '),
                                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _texte),
                                          ),
                                        ],
                                      ),
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

// ══════════════════════════════════════════════════════════
// Écran dédié — Journal des actions (paginé, filtrable par
// date/utilisateur/module). Directeur et censeur uniquement.
// ══════════════════════════════════════════════════════════
class JournalActionsScreen extends StatefulWidget {
  const JournalActionsScreen({super.key});

  @override
  State<JournalActionsScreen> createState() => _JournalActionsScreenState();
}

class _JournalActionsScreenState extends State<JournalActionsScreen> {
  final _moduleController = TextEditingController();
  List<ActionJournal> _lignes = [];
  int _page = 1;
  int _dernierePage = 1;
  bool _chargement = true;
  bool _chargementPage = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _moduleController.dispose();
    super.dispose();
  }

  Future<void> _charger({bool ajouter = false}) async {
    setState(() {
      if (ajouter) {
        _chargementPage = true;
      } else {
        _chargement = true;
        _page = 1;
      }
      _erreur = null;
    });
    try {
      final data = await PermissionSecuriteService.getJournalActions(
        module: _moduleController.text.trim().isEmpty ? null : _moduleController.text.trim(),
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _lignes = ajouter ? [..._lignes, ...data['items'] as List<ActionJournal>] : data['items'] as List<ActionJournal>;
        _dernierePage = data['dernierePage'] as int;
        _chargement = false;
        _chargementPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _chargementPage = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _chargerPageSuivante() {
    if (_page >= _dernierePage || _chargementPage) return;
    _page++;
    _charger(ajouter: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Journal des actions', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _moduleController,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Filtrer par module (ex: annees_academiques)',
                prefixIcon: const Icon(Icons.filter_alt_outlined),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _charger),
              ),
              onSubmitted: (_) => _charger(),
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator(color: _indigo))
                : _erreur != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge))))
                    : _lignes.isEmpty
                        ? Center(child: Text('Aucune action enregistrée.', style: GoogleFonts.inter(color: _gris)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _lignes.length + (_page < _dernierePage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _lignes.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: _chargementPage
                                        ? const CircularProgressIndicator(color: _indigo)
                                        : TextButton(onPressed: _chargerPageSuivante, child: const Text('Charger plus')),
                                  ),
                                );
                              }
                              final a = _lignes[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: _indigo, width: 4))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('${a.module} — ${a.action}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
                                        ),
                                        Text(_formatDateHeure(a.dateAction), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _gris)),
                                      ],
                                    ),
                                    if (a.description != null && a.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(a.description!, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                                    ],
                                    const SizedBox(height: 4),
                                    Text('Par ${a.nomUser ?? '—'}', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
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
