import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/permission_securite_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

// ══════════════════════════════════════════════════════════
// Section Actions avancées — zone sensible. Accessible directeur
// uniquement. Chaque action exige le mot de passe du directeur en
// reconfirmation (pas seulement le token de session), puis une dernière
// confirmation explicite avant exécution. Les cartes reprennent la
// palette "danger" de ssm_alert_item (fond rouge très clair, bordure
// rouge) pour bien marquer la dangerosité, sans réutiliser le widget
// SSMPanel dont l'en-tête est réservé au style neutre/indigo.
// POST /parametres/actions-avancees/archiver-annee,
// POST /parametres/actions-avancees/reinitialiser-parametres
// (ActionAvanceeController).
// ══════════════════════════════════════════════════════════
class ActionsAvanceesScreen extends StatefulWidget {
  const ActionsAvanceesScreen({super.key});

  @override
  State<ActionsAvanceesScreen> createState() => _ActionsAvanceesScreenState();
}

class _ActionsAvanceesScreenState extends State<ActionsAvanceesScreen> {
  Utilisateur? _utilisateur;
  List<dynamic> _annees = [];
  int? _anneeSelectionneeId;

  bool _chargement = true;
  String? _actionEnCours; // 'archiver' | 'reinitialiser'

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final annees = utilisateur?.estDirecteur == true ? await AnneeService.listerAnnees() : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _utilisateur = utilisateur;
        _annees = annees;
        _anneeSelectionneeId = annees.isNotEmpty ? annees.first['id'] as int : null;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
    }
  }

  // ── Flux de confirmation à deux étapes + mot de passe ────

  Future<void> _executerActionSensible({
    required String cleAction,
    required String titreConfirmation,
    required String messageAvertissement,
    required Future<void> Function(String motDePasse) action,
    required String messageSucces,
  }) async {
    final motDePasse = await showDialog<String>(
      context: context,
      builder: (context) => _DialogMotDePasse(titre: titreConfirmation, message: messageAvertissement),
    );
    if (motDePasse == null || motDePasse.isEmpty) return;

    if (!mounted) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        icon: const Icon(Icons.report_gmailerrorred, color: SSMPalette.rouge, size: 40),
        title: Text('Êtes-vous vraiment sûr ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          'Cette action est irréversible. Elle va être exécutée immédiatement.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer définitivement'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _actionEnCours = cleAction);
    try {
      await action(motDePasse);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageSucces), backgroundColor: SSMPalette.teal));
      setState(() => _actionEnCours = null);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionEnCours = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  Future<void> _archiverAnnee() async {
    final anneeId = _anneeSelectionneeId;
    if (anneeId == null) return;

    final libelle = _annees.firstWhere((a) => a['id'] == anneeId, orElse: () => null)?['libelle'] as String? ?? '—';

    await _executerActionSensible(
      cleAction: 'archiver',
      titreConfirmation: 'Archiver l\'année "$libelle" ?',
      messageAvertissement:
          "L'année scolaire sera archivée et passera en lecture seule : plus aucune donnée ne pourra y être ajoutée "
          'ou modifiée. Aucune donnée existante ne sera supprimée.\n\n'
          "L'année doit déjà être clôturée pour pouvoir être archivée.",
      action: (motDePasse) => PermissionSecuriteService.archiverAnnee(anneeScolaireId: anneeId, motDePasseConfirmation: motDePasse),
      messageSucces: 'Année scolaire archivée avec succès',
    );
  }

  Future<void> _reinitialiserParametres() async {
    await _executerActionSensible(
      cleAction: 'reinitialiser',
      titreConfirmation: 'Réinitialiser tous les paramètres ?',
      messageAvertissement:
          "Tous les réglages de configuration de l'école (établissement, académique, bulletins, validation des notes, "
          'classes, matières, frais) seront remis à leurs valeurs par défaut.\n\n'
          "Les données métier (élèves, notes, paiements) ne sont PAS concernées.",
      action: (motDePasse) => PermissionSecuriteService.reinitialiserParametres(motDePasse),
      messageSucces: 'Paramètres réinitialisés aux valeurs par défaut avec succès',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Actions avancées', sousTitre: 'Zone sensible — réservée au directeur', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _utilisateur?.estDirecteur != true
                      ? _accesRefuse()
                      : _corps(),
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
        const SSMAlertItem(
          type: SSMAlerteType.danger,
          icone: Icons.warning_amber_rounded,
          titre: 'Zone sensible',
          sousTitre: 'Chaque action ci-dessous exige votre mot de passe et une confirmation finale avant exécution.',
        ),
        const SizedBox(height: 20),
        _carteAction(
          icone: Icons.archive_outlined,
          titre: 'Archiver une année scolaire',
          description: "Rend une année scolaire clôturée définitivement en lecture seule. Aucune donnée n'est supprimée.",
          contenu: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_annees.isEmpty)
                Text('Aucune année scolaire disponible.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3))
              else
                DropdownButtonFormField<int>(
                  initialValue: _anneeSelectionneeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Année scolaire',
                    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
                    isDense: true,
                    filled: true,
                    fillColor: SSMPalette.blanc,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  items: _annees
                      .map((a) => DropdownMenuItem<int>(
                            value: a['id'] as int,
                            child: Text('${a['libelle']} (${a['statut']})', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _anneeSelectionneeId = v),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen))),
                  onPressed: _annees.isEmpty || _actionEnCours != null ? null : _archiverAnnee,
                  icon: _actionEnCours == 'archiver'
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('Archiver'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _carteAction(
          icone: Icons.settings_backup_restore,
          titre: 'Réinitialiser les paramètres',
          description: "Remet tous les paramètres de configuration de l'école à leurs valeurs par défaut. Les données métier ne sont pas touchées.",
          contenu: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen))),
              onPressed: _actionEnCours != null ? null : _reinitialiserParametres,
              icon: _actionEnCours == 'reinitialiser'
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.settings_backup_restore, size: 18),
              label: const Text('Réinitialiser'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _carteAction({required IconData icone, required String titre, required String description, required Widget contenu}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.rouge.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                child: Icon(icone, color: SSMPalette.rouge, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.texte1))),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
          const SizedBox(height: 14),
          contenu,
        ],
      ),
    );
  }

  Widget _accesRefuse() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text('Seul le directeur peut accéder aux actions avancées.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Dialog de reconfirmation par mot de passe, avec le message
// d'avertissement spécifique à l'action.
// ══════════════════════════════════════════════════════════
class _DialogMotDePasse extends StatefulWidget {
  final String titre;
  final String message;
  const _DialogMotDePasse({required this.titre, required this.message});

  @override
  State<_DialogMotDePasse> createState() => _DialogMotDePasseState();
}

class _DialogMotDePasseState extends State<_DialogMotDePasse> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _erreur;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _valider() {
    if (_controller.text.isEmpty) {
      setState(() => _erreur = 'Le mot de passe est requis pour continuer.');
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SSMPalette.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
      icon: const Icon(Icons.warning_amber_rounded, color: SSMPalette.ambre, size: 36),
      title: Text(widget.titre, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
            decoration: InputDecoration(
              labelText: 'Votre mot de passe',
              labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
              prefixIcon: const Icon(Icons.lock_outline, color: SSMPalette.texte3),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: SSMPalette.texte3),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              errorText: _erreur,
            ),
            onSubmitted: (_) => _valider(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.ambre, foregroundColor: Colors.white, elevation: 0),
          onPressed: _valider,
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}
