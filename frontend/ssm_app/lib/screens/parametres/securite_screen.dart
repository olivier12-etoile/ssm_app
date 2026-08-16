import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/permission_securite_model.dart';
import '../../services/auth_service.dart';
import '../../services/permission_securite_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

String _formatDateHeure(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

InputDecoration _decorationMotDePasse(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    prefixIcon: const Icon(Icons.lock_outline, size: 20, color: SSMPalette.texte3),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5)),
  );
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
        const SnackBar(content: Text('Mot de passe changé avec succès'), backgroundColor: SSMPalette.teal),
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
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Révoquer cette session ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          'L\'appareil "${session.appareil ?? 'inconnu'}" sera déconnecté immédiatement.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
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
        const SnackBar(content: Text('Session révoquée avec succès'), backgroundColor: SSMPalette.teal),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
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
        const SnackBar(content: Text('Paramètre de déconnexion automatique enregistré'), backgroundColor: SSMPalette.teal),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementDelaiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  bool get _delaiModifie => _deconnexionAutoActive != (_delaiInactivite != null) || (_deconnexionAutoActive && _delaiChoisi.round() != _delaiInactivite);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Sécurité', sousTitre: 'Mot de passe, sessions et historique', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _carteErreur(_erreur!, _charger)
                      : RefreshIndicator(onRefresh: _charger, color: SSMPalette.indigo, child: _corps()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SSMPanel(
          titre: 'Changer le mot de passe',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_erreurMotDePasse != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: SSMPalette.rougeClair, borderRadius: BorderRadius.circular(SSMRayons.petit)),
                  child: Text(_erreurMotDePasse!, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.rouge)),
                ),
              ],
              TextField(controller: _ancienController, obscureText: true, style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1), decoration: _decorationMotDePasse('Ancien mot de passe')),
              const SizedBox(height: 12),
              TextField(controller: _nouveauController, obscureText: true, style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1), decoration: _decorationMotDePasse('Nouveau mot de passe')),
              const SizedBox(height: 4),
              Text('Au moins 8 caractères, majuscule, minuscule et chiffre.', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
              const SizedBox(height: 12),
              TextField(controller: _confirmationController, obscureText: true, style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1), decoration: _decorationMotDePasse('Confirmer le nouveau mot de passe')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SSMPalette.indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  onPressed: _motDePasseEnCours ? null : _changerMotDePasse,
                  child: _motDePasseEnCours
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Changer le mot de passe'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SSMPanel(
          titre: 'Sessions actives',
          padding: _sessions.isEmpty ? null : EdgeInsets.zero,
          child: _sessions.isEmpty
              ? Text('Aucune session active.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2))
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SSMDataTable(
                    colonnes: const [SSMDataColumn('Appareil'), SSMDataColumn('Dernière activité'), SSMDataColumn('Action')],
                    lignes: [for (final s in _sessions) _ligneSession(s)],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SSMPanel(
          titre: 'Déconnexion automatique',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: SSMPalette.indigo,
                value: _deconnexionAutoActive,
                title: Text('Déconnexion automatique en cas d\'inactivité', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
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
                        activeColor: SSMPalette.indigo,
                        label: '${_delaiChoisi.round()} min',
                        onChanged: !_estDirecteur ? null : (v) => setState(() => _delaiChoisi = v),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${_delaiChoisi.round()} min',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                      ),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Les utilisateurs restent connectés indéfiniment.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                ),
              if (_estDirecteur) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SSMPalette.indigo,
                      side: const BorderSide(color: SSMPalette.indigo),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                    ),
                    onPressed: !_delaiModifie || _chargementDelaiEnCours ? null : _enregistrerDelai,
                    child: _chargementDelaiEnCours
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo))
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SSMPanel(
          titre: 'Historique',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: SSMPalette.indigo),
                title: Text('Historique des connexions', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                subtitle: Text(_estDirecteur ? 'Toutes les connexions de l\'école' : 'Vos connexions', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                trailing: const Icon(Icons.chevron_right, color: SSMPalette.texte3),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoriqueConnexionsScreen(estDirecteur: _estDirecteur))),
              ),
              if (_estGestionnaire) ...[
                const Divider(height: 1, color: SSMPalette.bordure),
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: SSMPalette.indigo),
                  title: Text('Journal des actions', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                  subtitle: Text('Directeur et censeur uniquement', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  trailing: const Icon(Icons.chevron_right, color: SSMPalette.texte3),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalActionsScreen())),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _ligneSession(SessionActive session) {
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other, size: 16, color: session.actuelle ? SSMPalette.teal : SSMPalette.texte3),
          const SizedBox(width: 6),
          Text(session.appareil ?? 'Appareil inconnu', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
        ],
      ),
      Text('Dernière activité : ${_formatDateHeure(session.derniereActivite)}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      session.actuelle
          ? const SSMPill.couleur(label: 'Session actuelle', couleur: SSMPalette.teal)
          : TextButton(
              onPressed: () => _revoquerSession(session),
              style: TextButton.styleFrom(foregroundColor: SSMPalette.rouge, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Révoquer'),
            ),
    ];
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onReessayer, child: const Text('Réessayer')),
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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Historique des connexions', onRetour: () => Navigator.pop(context)),
            if (widget.estDirecteur && _utilisateurs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<int?>(
                  initialValue: _userIdFiltre,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Filtrer par utilisateur',
                    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
                    prefixIcon: const Icon(Icons.person_outline, color: SSMPalette.texte3),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
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
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erreur!, style: GoogleFonts.inter(color: SSMPalette.rouge))))
                      : _lignes.isEmpty
                          ? Center(child: Text('Aucune connexion enregistrée.', style: GoogleFonts.inter(color: SSMPalette.texte3)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _lignes.length + (_page < _dernierePage ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _lignes.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: _chargementPage
                                          ? const CircularProgressIndicator(color: SSMPalette.indigo)
                                          : TextButton(onPressed: _chargerPageSuivante, child: const Text('Charger plus')),
                                    ),
                                  );
                                }
                                final c = _lignes[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: SSMPalette.blanc,
                                    borderRadius: BorderRadius.circular(SSMRayons.grand),
                                    border: Border.all(color: SSMPalette.bordure),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(color: SSMPalette.indigoClair, shape: BoxShape.circle),
                                        child: const Icon(Icons.login, size: 16, color: SSMPalette.indigo),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c.nomUser ?? 'Utilisateur #${c.userId}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                                            const SizedBox(height: 2),
                                            Text(
                                              [_formatDateHeure(c.dateConnexion), if (c.ip != null) c.ip!].join(' · '),
                                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte2),
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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Journal des actions', onRetour: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _moduleController,
                style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                decoration: InputDecoration(
                  labelText: 'Filtrer par module (ex: annees_academiques)',
                  labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
                  prefixIcon: const Icon(Icons.filter_alt_outlined, color: SSMPalette.texte3),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  suffixIcon: IconButton(icon: const Icon(Icons.search, color: SSMPalette.texte3), onPressed: _charger),
                ),
                onSubmitted: (_) => _charger(),
              ),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erreur!, style: GoogleFonts.inter(color: SSMPalette.rouge))))
                      : _lignes.isEmpty
                          ? Center(child: Text('Aucune action enregistrée.', style: GoogleFonts.inter(color: SSMPalette.texte3)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _lignes.length + (_page < _dernierePage ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _lignes.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: _chargementPage
                                          ? const CircularProgressIndicator(color: SSMPalette.indigo)
                                          : TextButton(onPressed: _chargerPageSuivante, child: const Text('Charger plus')),
                                    ),
                                  );
                                }
                                final a = _lignes[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: SSMPalette.blanc,
                                    borderRadius: BorderRadius.circular(SSMRayons.grand),
                                    border: const Border(left: BorderSide(color: SSMPalette.indigo, width: 3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text('${a.module} — ${a.action}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                                          ),
                                          Text(_formatDateHeure(a.dateAction), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: SSMPalette.texte3)),
                                        ],
                                      ),
                                      if (a.description != null && a.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(a.description!, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                                      ],
                                      const SizedBox(height: 4),
                                      Text('Par ${a.nomUser ?? '—'}', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
