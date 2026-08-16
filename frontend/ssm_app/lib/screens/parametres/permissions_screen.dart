import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/permission_securite_model.dart';
import '../../services/auth_service.dart';
import '../../services/permission_securite_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

// ══════════════════════════════════════════════════════════
// Section Utilisateurs & Permissions : matrice de droits par rôle × module.
// GET/PUT /parametres/permissions, POST /parametres/permissions/reinitialiser
// (PermissionRoleController). Accessible directeur uniquement — le rôle
// "directeur" lui-même n'est pas éditable (accès complet immuable côté
// backend, sécurité anti-blocage). Onglets par rôle stylés en pilules
// (indigo actif), même pattern que pedagogique_detail_screen.dart.
// ══════════════════════════════════════════════════════════
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Utilisateur? _utilisateur;
  int _roleActif = 0;

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
    _charger();
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
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  Future<void> _confirmerReinitialisation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        icon: const Icon(Icons.warning_amber_rounded, color: SSMPalette.rouge, size: 36),
        title: Text('Réinitialiser toutes les permissions ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          'Toute la matrice de permissions (censeur, enseignant, secrétaire, comptable) sera remise aux valeurs '
          "par défaut du système. Les personnalisations effectuées seront définitivement perdues.\n\n"
          'Cette action est irréversible.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
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
        const SnackBar(content: Text('Permissions réinitialisées aux valeurs par défaut'), backgroundColor: SSMPalette.teal),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _reinitialisationEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Permissions', sousTitre: 'Matrice des droits par rôle', onRetour: () => Navigator.pop(context)),
            if (!_chargement && _utilisateur?.estDirecteur == true && _erreur == null) _barreOnglets(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _utilisateur?.estDirecteur != true
                      ? _accesRefuse()
                      : _erreur != null
                          ? _carteErreur(_erreur!, _charger)
                          : _corps(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreOnglets() {
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < RoleUtilisateur.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _boutonOnglet(RoleUtilisateur.values[i].libelle, i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _boutonOnglet(String label, int index) {
    final actif = _roleActif == index;
    return GestureDetector(
      onTap: () => setState(() => _roleActif = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.indigo : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(SSMRayons.pilule),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.white : SSMPalette.texte2),
        ),
      ),
    );
  }

  Widget _corps() {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _roleActif,
            sizing: StackFit.expand,
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: SSMPalette.rouge,
                  side: const BorderSide(color: SSMPalette.rouge),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                ),
                onPressed: _reinitialisationEnCours ? null : _confirmerReinitialisation,
                icon: _reinitialisationEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.rouge))
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
          const SSMAlertItem(
            type: SSMAlerteType.succes,
            icone: Icons.verified_user,
            titre: 'Accès complet',
            sousTitre: 'Le directeur dispose toujours d\'un accès complet à tous les modules. Ce droit n\'est pas modifiable, afin d\'éviter tout blocage de l\'école.',
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
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1))),
          const Icon(Icons.check_circle, color: SSMPalette.teal, size: 18),
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
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          title: Row(
            children: [
              Expanded(child: Text(libelle, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1))),
              if (enCours)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo))
              else if (vientDetreEnregistre)
                const Icon(Icons.check_circle, color: SSMPalette.teal, size: 18)
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
      decoration: BoxDecoration(
        color: (nombre > 0 ? SSMPalette.indigo : SSMPalette.texte3).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SSMRayons.pilule),
      ),
      child: Text('$nombre/5', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: nombre > 0 ? SSMPalette.indigo : SSMPalette.texte3)),
    );
  }

  Widget _ligneSwitch(String label, bool valeur, ValueChanged<bool> onChanged, bool enCours) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: SSMPalette.indigo,
      value: valeur,
      title: Text(label, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
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
            const Icon(Icons.block, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(
              'Seul le directeur peut accéder à la matrice de permissions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: SSMPalette.texte2),
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
