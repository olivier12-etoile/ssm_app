import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/permission_securite_model.dart';
import '../../services/auth_service.dart';
import '../../services/permission_securite_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

// ══════════════════════════════════════════════════════════
// Section Utilisateurs & Permissions : matrice de droits par rôle × module.
// GET/PUT /parametres/permissions, POST /parametres/permissions/reinitialiser
// (PermissionRoleController). Accessible directeur uniquement — le rôle
// "directeur" lui-même n'est pas éditable (accès complet immuable côté
// backend, sécurité anti-blocage).
// ══════════════════════════════════════════════════════════
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with SingleTickerProviderStateMixin {
  Utilisateur? _utilisateur;
  late final TabController _tabController;

  Map<String, String> _modules = {};
  Map<String, Map<String, PermissionRole>> _matrice = {};

  bool _chargement = true;
  bool _reinitialisationEnCours = false;
  String? _erreur;

  // module en cours d'enregistrement (pour l'indicateur inline).
  String? _moduleEnCours;
  String? _moduleVientDetreEnregistre;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: RoleUtilisateur.values.length, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        PermissionSecuriteService.getMatricePermissions(),
      ]);
      if (!mounted) return;

      final donnees = resultats[1] as Map<String, dynamic>;
      final modules = donnees['modules'] as Map<String, String>;
      final liste = donnees['matrice'] as List<PermissionRole>;

      final matrice = <String, Map<String, PermissionRole>>{};
      for (final p in liste) {
        matrice.putIfAbsent(p.role, () => {})[p.module] = p;
      }

      setState(() {
        _utilisateur = resultats[0] as Utilisateur?;
        _modules = modules;
        _matrice = matrice;
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

  Future<void> _basculerDroit(String role, String module, PermissionRole actuelle, String droit, bool valeur) async {
    final cle = '$role|$module';
    setState(() => _moduleEnCours = cle);

    final misAJourOptimiste = switch (droit) {
      'consulter' => actuelle.copyWith(peutConsulter: valeur),
      'creer' => actuelle.copyWith(peutCreer: valeur),
      'modifier' => actuelle.copyWith(peutModifier: valeur),
      'supprimer' => actuelle.copyWith(peutSupprimer: valeur),
      _ => actuelle.copyWith(peutValider: valeur),
    };

    setState(() => _matrice[role]![module] = misAJourOptimiste);

    try {
      final confirmee = await PermissionSecuriteService.updatePermission(misAJourOptimiste);
      if (!mounted) return;
      setState(() {
        _matrice[role]![module] = confirmee;
        _moduleEnCours = null;
        _moduleVientDetreEnregistre = cle;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _moduleVientDetreEnregistre == cle) {
          setState(() => _moduleVientDetreEnregistre = null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Rollback en cas d'échec (ex. rôle directeur refusé côté serveur).
      setState(() {
        _matrice[role]![module] = actuelle;
        _moduleEnCours = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
      );
    }
  }

  Future<void> _confirmerReinitialisation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _rouge, size: 36),
        title: const Text('Réinitialiser toutes les permissions ?'),
        content: const Text(
          'Toute la matrice de permissions (censeur, enseignant, secrétaire, comptable) sera remise aux valeurs '
          "par défaut du système. Les personnalisations effectuées seront définitivement perdues.\n\n"
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _reinitialisationEnCours = true);
    try {
      await PermissionSecuriteService.reinitialiserPermissionsDefauts();
      await _charger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions réinitialisées aux valeurs par défaut'), backgroundColor: _vert),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _reinitialisationEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Permissions', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        bottom: _chargement
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: RoleUtilisateur.values.map((r) => Tab(text: r.libelle)).toList(),
              ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _utilisateur?.estDirecteur != true
              ? _accesRefuse()
              : _erreur != null
                  ? _carteErreur(_erreur!, _charger)
                  : _corps(),
    );
  }

  Widget _corps() {
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: RoleUtilisateur.values.map((role) => _vueRole(role)).toList(),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: _rouge, side: const BorderSide(color: _rouge)),
                onPressed: _reinitialisationEnCours ? null : _confirmerReinitialisation,
                icon: _reinitialisationEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _rouge))
                    : const Icon(Icons.restore),
                label: const Text('Réinitialiser aux valeurs par défaut'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vueRole(RoleUtilisateur role) {
    if (role == RoleUtilisateur.directeur) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _teal.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: _teal.withValues(alpha: 0.3))),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: _teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Le directeur dispose toujours d\'un accès complet à tous les modules. Ce droit n\'est pas modifiable, afin d\'éviter tout blocage de l\'école.',
                    style: GoogleFonts.inter(fontSize: 12, color: _texte),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._modules.entries.map((e) => _cartePermissionLectureSeule(e.value)),
        ],
      );
    }

    final permissionsRole = _matrice[role.valeur] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _modules.entries.map((entree) {
        final module = entree.key;
        final libelle = entree.value;
        final permission = permissionsRole[module];
        if (permission == null) return const SizedBox.shrink();
        return _cartePermissionEditable(role.valeur, module, libelle, permission);
      }).toList(),
    );
  }

  Widget _cartePermissionLectureSeule(String libelle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce))),
          const Icon(Icons.check_circle, color: _teal, size: 18),
        ],
      ),
    );
  }

  Widget _cartePermissionEditable(String role, String module, String libelle, PermissionRole permission) {
    final cle = '$role|$module';
    final enCours = _moduleEnCours == cle;
    final vientDetreEnregistre = _moduleVientDetreEnregistre == cle;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          title: Row(
            children: [
              Expanded(child: Text(libelle, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce))),
              if (enCours)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
              else if (vientDetreEnregistre)
                const Icon(Icons.check_circle, color: _vert, size: 18)
              else
                _resumeDroits(permission),
            ],
          ),
          children: [
            _ligneSwitch('Consulter', permission.peutConsulter, (v) => _basculerDroit(role, module, permission, 'consulter', v), enCours),
            _ligneSwitch('Créer', permission.peutCreer, (v) => _basculerDroit(role, module, permission, 'creer', v), enCours),
            _ligneSwitch('Modifier', permission.peutModifier, (v) => _basculerDroit(role, module, permission, 'modifier', v), enCours),
            _ligneSwitch('Supprimer', permission.peutSupprimer, (v) => _basculerDroit(role, module, permission, 'supprimer', v), enCours),
            _ligneSwitch('Valider', permission.peutValider, (v) => _basculerDroit(role, module, permission, 'valider', v), enCours),
          ],
        ),
      ),
    );
  }

  Widget _resumeDroits(PermissionRole p) {
    final nombre = [p.peutConsulter, p.peutCreer, p.peutModifier, p.peutSupprimer, p.peutValider].where((v) => v).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (nombre > 0 ? _indigo : _gris).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text('$nombre/5', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: nombre > 0 ? _indigo : _gris)),
    );
  }

  Widget _ligneSwitch(String label, bool valeur, ValueChanged<bool> onChanged, bool enCours) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: _indigo,
      value: valeur,
      title: Text(label, style: GoogleFonts.inter(fontSize: 13)),
      onChanged: enCours ? null : onChanged,
    );
  }

  Widget _accesRefuse() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(
              'Seul le directeur peut accéder à la matrice de permissions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _texte),
            ),
          ],
        ),
      ),
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
