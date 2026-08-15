import '../../models/dashboard_frais_model.dart';
import '../../models/statistique_detail_model.dart';
import '../../models/statistique_generale_model.dart';
import '../../models/utilisateur.dart';
import '../../services/annee_service.dart';
import '../../services/auth_service.dart';
import '../../services/caisse_service.dart';
import '../../services/classe_service.dart';
import '../../services/dashboard_frais_service.dart';
import '../../services/eleve_service.dart';
import '../../services/notification_attente_service.dart';
import '../../services/paiement_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../services/statistique_detail_service.dart';
import '../../services/statistique_generale_service.dart';
import '../../services/validation_note_service.dart';

// ══════════════════════════════════════════════════════════
// DashboardDirecteurDonnees — snapshot agrégé de toutes les
// données affichées par l'écran, avec valeurs de repli sûres
// (0 / listes vides) pour qu'un service en échec n'empêche pas
// l'affichage des autres.
// ══════════════════════════════════════════════════════════
class DashboardDirecteurDonnees {
  final Utilisateur? utilisateur;
  final String nomEcole;
  final Map<String, dynamic>? annee;
  final Map<String, dynamic>? periode;

  final int totalEleves;
  final int nouveauxInscrits;

  final int notesEnAttenteValidation;

  final ResumeFinancier? resumeFinancier;

  final int classesActives;
  final int classesCollege;
  final int classesLycee;

  final int notificationsNonLues;

  final List<Alerte> alertes;
  final List<Map<String, dynamic>> derniersPaiements;

  final bool caisseOuverte;

  const DashboardDirecteurDonnees({
    this.utilisateur,
    this.nomEcole = 'Mon établissement',
    this.annee,
    this.periode,
    this.totalEleves = 0,
    this.nouveauxInscrits = 0,
    this.notesEnAttenteValidation = 0,
    this.resumeFinancier,
    this.classesActives = 0,
    this.classesCollege = 0,
    this.classesLycee = 0,
    this.notificationsNonLues = 0,
    this.alertes = const [],
    this.derniersPaiements = const [],
    this.caisseOuverte = false,
  });

  String get prenomUtilisateur {
    final nom = utilisateur?.nom.trim() ?? '';
    if (nom.isEmpty) return 'Directeur';
    return nom.split(RegExp(r'\s+')).first;
  }

  int get debiteurs =>
      (resumeFinancier?.nombrePartiel ?? 0) + (resumeFinancier?.nombreAucunPaiement ?? 0);

  String? get libellePeriodeActive {
    final anneeLibelle = annee?['libelle'] as String?;
    final periodeNom = periode?['nom'] as String?;
    if (anneeLibelle == null && periodeNom == null) return null;
    if (anneeLibelle != null && periodeNom != null) return '$anneeLibelle · $periodeNom';
    return anneeLibelle ?? periodeNom;
  }

  bool get periodeEnCours {
    final statut = periode?['statut'] as String?;
    if (statut == null) return false;
    return {'active', 'ouverte', 'en_cours'}.contains(statut);
  }
}

// ══════════════════════════════════════════════════════════
// DashboardDirecteurViewModel — orchestre les appels aux
// services existants en parallèle (les Future sont créées
// avant d'être attendues, donc les requêtes partent en même
// temps) et agrège le résultat dans DashboardDirecteurDonnees.
// Chaque source est protégée individuellement : un service en
// échec renvoie une valeur de repli plutôt que de faire échouer
// tout le tableau de bord.
// ══════════════════════════════════════════════════════════
class DashboardDirecteurViewModel {
  static Future<DashboardDirecteurDonnees> charger() async {
    // ── Phase A : identité + période active (nécessaires aux appels suivants) ──
    final utilisateurFuture = AuthService.getUtilisateur();
    final anneeActiveFuture = _anneeActiveSecurisee();
    final nomEcoleFuture = _nomEcoleSecurise();

    final utilisateur = await utilisateurFuture;
    final anneeActive = await anneeActiveFuture;
    final nomEcole = await nomEcoleFuture;

    final annee = anneeActive['annee'] as Map<String, dynamic>?;
    final periode = anneeActive['periode_active'] as Map<String, dynamic>?;
    final anneeId = annee?['id'] as int?;
    final periodeId = periode?['id'] as int?;

    // ── Phase B : tout le reste, en parallèle ──
    final statsElevesFuture = _statsElevesSecurisees();
    final notesEnAttenteFuture = _notesEnAttenteSecurisees();
    final resumeFinancierFuture = _resumeFinancierSecurise();
    final classesFuture = _classesSecurisees();
    final notificationsFuture = _notificationsSecurisees();
    final paiementsFuture = _derniersPaiementsSecurises();
    final alertesFuture = _alertesSecurisees(anneeId, periodeId);
    final dashboardGeneralFuture = _dashboardGeneralSecurise(anneeId, periodeId);
    final caisseOuverteFuture = _caisseOuverteSecurisee();

    final statsEleves = await statsElevesFuture;
    final notesEnAttente = await notesEnAttenteFuture;
    final resumeFinancier = await resumeFinancierFuture;
    final classesRaw = await classesFuture;
    final notifications = await notificationsFuture;
    final paiements = await paiementsFuture;
    final alertes = await alertesFuture;
    final dashboardGeneral = await dashboardGeneralFuture;
    final caisseOuverte = await caisseOuverteFuture;

    final repartitionClasses = _repartirClasses(classesRaw);

    return DashboardDirecteurDonnees(
      utilisateur: utilisateur,
      nomEcole: nomEcole,
      annee: annee,
      periode: periode,
      totalEleves: statsEleves['total'] as int? ?? 0,
      nouveauxInscrits: dashboardGeneral?.effectifs.nouveauxInscrits ?? 0,
      notesEnAttenteValidation: notesEnAttente,
      resumeFinancier: resumeFinancier,
      classesActives: repartitionClasses.$1,
      classesCollege: repartitionClasses.$2,
      classesLycee: repartitionClasses.$3,
      notificationsNonLues: notifications['total'] as int? ?? 0,
      alertes: alertes,
      derniersPaiements: paiements,
      caisseOuverte: caisseOuverte,
    );
  }

  // ── Sources sécurisées (valeur de repli si le service échoue) ──

  static Future<Map<String, dynamic>> _anneeActiveSecurisee() async {
    try {
      return await AnneeService.anneeActive();
    } catch (_) {
      return const {};
    }
  }

  static Future<String> _nomEcoleSecurise() async {
    try {
      final infos = await ParametreEcoleService.getInformationsEtablissement();
      return infos.nomCourt ?? infos.nomOfficiel ?? 'Mon établissement';
    } catch (_) {
      return 'Mon établissement';
    }
  }

  static Future<Map<String, dynamic>> _statsElevesSecurisees() async {
    try {
      return await EleveService.tableauDeBord();
    } catch (_) {
      return const {};
    }
  }

  static Future<int> _notesEnAttenteSecurisees() async {
    try {
      final saisies = await ValidationNoteService.getEnAttente();
      return saisies.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<ResumeFinancier?> _resumeFinancierSecurise() async {
    try {
      return await DashboardFraisService.getResume();
    } catch (_) {
      return null;
    }
  }

  static Future<List<dynamic>> _classesSecurisees() async {
    try {
      return await ClasseService.listerClasses();
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, dynamic>> _notificationsSecurisees() async {
    try {
      return await NotificationAttenteService.lister();
    } catch (_) {
      return const {};
    }
  }

  static Future<List<Map<String, dynamic>>> _derniersPaiementsSecurises() async {
    try {
      final paiements = (await PaiementService.lister()).cast<Map<String, dynamic>>();
      paiements.sort((a, b) {
        final dateA = DateTime.tryParse(a['date_paiement']?.toString() ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['date_paiement']?.toString() ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      return paiements.take(7).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Alerte>> _alertesSecurisees(int? anneeId, int? periodeId) async {
    if (anneeId == null || periodeId == null) return const [];
    try {
      return await StatistiqueDetailService.getAlertes(
        anneeScolaireId: anneeId,
        periodeId: periodeId,
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<DashboardGeneral?> _dashboardGeneralSecurise(int? anneeId, int? periodeId) async {
    if (anneeId == null) return null;
    try {
      return await StatistiqueGeneraleService.getDashboardGeneral(
        anneeScolaireId: anneeId,
        periodeId: periodeId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _caisseOuverteSecurisee() async {
    try {
      final caisses = await CaisseService.getCaisses();
      for (final caisse in caisses) {
        if (caisse.id == null) continue;
        final session = await CaisseService.getSessionActive(caisse.id!);
        if (session != null && session.estOuverte) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Répartition collège/lycée des classes actives ──
  // Renvoie (totalActives, college, lycee).
  static (int, int, int) _repartirClasses(List<dynamic> classesBrutes) {
    var actives = 0;
    var college = 0;
    var lycee = 0;
    for (final c in classesBrutes) {
      if (c is! Map) continue;
      if (c['statut'] != 'active') continue;
      actives++;
      if (c['cycle'] == 'college') {
        college++;
      } else {
        lycee++;
      }
    }
    return (actives, college, lycee);
  }
}
