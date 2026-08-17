import '../../models/emploi_du_temps_model.dart';
import '../../models/note_model.dart';
import '../../models/utilisateur.dart';
import '../../services/annee_service.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_emploi_du_temps_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/eleve_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/note_service.dart';
import '../../services/notification_attente_service.dart';
import '../../services/parametre_ecole_service.dart';

// ══════════════════════════════════════════════════════════
// SeanceDuJour — une case (créneau + séance) de l'emploi du
// temps personnel de l'enseignant pour la journée en cours.
// ══════════════════════════════════════════════════════════
class SeanceDuJour {
  final CreneauHoraire creneau;
  final Seance seance;

  const SeanceDuJour({required this.creneau, required this.seance});

  // DashboardEmploiDuTempsService.getMonEmploiDuTemps() réutilise le champ
  // "enseignant_nom" de Seance pour y placer le nom de la classe (voir son
  // commentaire) — seul moyen actuel de savoir quelle classe est concernée
  // sur ce planning personnel.
  String get classeNom => seance.nomEnseignant ?? '—';
}

// ══════════════════════════════════════════════════════════
// DashboardEnseignantDonnees — snapshot agrégé de toutes les
// données affichées par l'écran, avec valeurs de repli sûres
// pour qu'un service en échec n'empêche pas l'affichage des
// autres sections.
// ══════════════════════════════════════════════════════════
class DashboardEnseignantDonnees {
  final Utilisateur? utilisateur;
  final String nomEcole;
  final Map<String, dynamic>? annee;
  final Map<String, dynamic>? periode;

  final List<dynamic> affectations;
  final Map<String, dynamic> notesParStatut;
  final List<dynamic> notesRejetees;
  final List<dynamic> absencesAujourdhui;

  final int totalEleves;
  final List<SaisieNote> progressionSaisies;
  final List<SeanceDuJour> seancesAujourdhui;

  final int notificationsNonLues;

  const DashboardEnseignantDonnees({
    this.utilisateur,
    this.nomEcole = 'Mon établissement',
    this.annee,
    this.periode,
    this.affectations = const [],
    this.notesParStatut = const {},
    this.notesRejetees = const [],
    this.absencesAujourdhui = const [],
    this.totalEleves = 0,
    this.progressionSaisies = const [],
    this.seancesAujourdhui = const [],
    this.notificationsNonLues = 0,
  });

  String get prenomUtilisateur {
    final nom = utilisateur?.nom.trim() ?? '';
    if (nom.isEmpty) return 'Enseignant';
    return nom.split(RegExp(r'\s+')).first;
  }

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

  // Classes distinctes issues des affectations, chacune avec ses matières.
  List<Map<String, dynamic>> get classesAffectees {
    final classesGroupees = <int, Map<String, dynamic>>{};
    for (final a in affectations) {
      final classeId = a['classe_id'] as int;
      classesGroupees.putIfAbsent(
        classeId,
        () => {
          'classe_id': classeId,
          'classe_nom': a['classe_nom'],
          'matieres': <Map<String, dynamic>>[],
        },
      );
      (classesGroupees[classeId]!['matieres'] as List<Map<String, dynamic>>).add({
        'matiere_id': a['matiere_id'],
        'matiere_nom': a['matiere_nom'],
        'coefficient': a['coefficient'],
        'couleur': a['couleur'],
      });
    }
    return classesGroupees.values.toList();
  }

  int get nombreClasses => classesAffectees.length;

  int get nombreMatieres {
    final vues = <int>{};
    for (final a in affectations) {
      vues.add(a['matiere_id'] as int);
    }
    return vues.length;
  }

  int get saisiesEnAttente => progressionSaisies.length;
}

// ══════════════════════════════════════════════════════════
// DashboardEnseignantViewModel — orchestre les appels aux
// services existants en parallèle et agrège le résultat dans
// DashboardEnseignantDonnees. Chaque source est protégée
// individuellement : un service en échec renvoie une valeur de
// repli plutôt que de faire échouer tout le tableau de bord.
// ══════════════════════════════════════════════════════════
class DashboardEnseignantViewModel {
  static Future<DashboardEnseignantDonnees> charger() async {
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

    // ── Phase B : tableau de bord général (dont dépendent classes/élèves) ──
    final dashboardGeneral = await _dashboardGeneralSecurise();
    final affectations = (dashboardGeneral['affectations'] as List?) ?? [];

    // ── Phase C : tout le reste, en parallèle ──
    final totalElevesFuture = _totalElevesSecurise(affectations, anneeId);
    final progressionFuture = _progressionSecurisee();
    final seancesFuture = _seancesAujourdhuiSecurisees(anneeId, periodeId);
    final notificationsFuture = _notificationsSecurisees();

    final totalEleves = await totalElevesFuture;
    final progression = await progressionFuture;
    final seances = await seancesFuture;
    final notifications = await notificationsFuture;

    final notesBrut = dashboardGeneral['notes'];
    final notesParStatut = notesBrut is Map ? Map<String, dynamic>.from(notesBrut) : <String, dynamic>{};

    return DashboardEnseignantDonnees(
      utilisateur: utilisateur,
      nomEcole: nomEcole,
      annee: annee,
      periode: periode,
      affectations: affectations,
      notesParStatut: notesParStatut,
      notesRejetees: (dashboardGeneral['notes_rejetees'] as List?) ?? [],
      absencesAujourdhui: (dashboardGeneral['absences_aujourdhui'] as List?) ?? [],
      totalEleves: totalEleves,
      progressionSaisies: progression,
      seancesAujourdhui: seances,
      notificationsNonLues: notifications['total'] as int? ?? 0,
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

  static Future<Map<String, dynamic>> _dashboardGeneralSecurise() async {
    try {
      return await DashboardService.chargerDashboard();
    } catch (_) {
      return const {};
    }
  }

  static Future<int> _totalElevesSecurise(List<dynamic> affectations, int? anneeId) async {
    if (anneeId == null) return 0;
    final classesGroupees = <int>{};
    for (final a in affectations) {
      classesGroupees.add(a['classe_id'] as int);
    }
    if (classesGroupees.isEmpty) return 0;

    try {
      final listes = await Future.wait(
        classesGroupees.map((classeId) => EleveService.elevesParClasse(classeId, anneeId)),
      );
      return listes.fold<int>(0, (total, l) => total + l.length);
    } catch (_) {
      return 0;
    }
  }

  static Future<List<SaisieNote>> _progressionSecurisee() async {
    try {
      return await NoteService.getProgression();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SeanceDuJour>> _seancesAujourdhuiSecurisees(int? anneeId, int? periodeId) async {
    if (periodeId == null) return const [];
    final jourAujourdhui = _jourAujourdhui();
    if (jourAujourdhui == null) return const [];

    try {
      final resultats = await Future.wait([
        EmploiDuTempsService.getCreneauxHoraires(anneeScolaireId: anneeId),
        DashboardEmploiDuTempsService.getMonEmploiDuTemps(periodeId),
      ]);
      final creneaux = (resultats[0] as List<CreneauHoraire>)..sort((a, b) => a.ordre.compareTo(b.ordre));
      final emploi = resultats[1] as EmploiDuTemps;
      final seancesJour = emploi.grille[jourAujourdhui] ?? {};

      return [
        for (final creneau in creneaux)
          if (creneau.id != null && seancesJour[creneau.id] != null)
            SeanceDuJour(creneau: creneau, seance: seancesJour[creneau.id]!),
      ];
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

  static const Map<int, JourSemaine> _joursParWeekday = {
    1: JourSemaine.lundi,
    2: JourSemaine.mardi,
    3: JourSemaine.mercredi,
    4: JourSemaine.jeudi,
    5: JourSemaine.vendredi,
    6: JourSemaine.samedi,
  };

  static JourSemaine? _jourAujourdhui() => _joursParWeekday[DateTime.now().weekday];
}
