// ══════════════════════════════════════════════════════════
// Modèles du dashboard, des statistiques, de la disponibilité et du
// calendrier du module Emploi du Temps.
// ══════════════════════════════════════════════════════════

// ── TypeEvenement ────────────────────────────────────────
enum TypeEvenement {
  vacances('vacances', 'Vacances'),
  ferie('ferie', 'Jour férié'),
  examen('examen', 'Examen'),
  composition('composition', 'Composition'),
  conseilClasse('conseil_classe', 'Conseil de classe');

  final String valeurApi;
  final String libelle;

  const TypeEvenement(this.valeurApi, this.libelle);

  static TypeEvenement depuisApi(String? valeur) => TypeEvenement.values.firstWhere(
        (t) => t.valeurApi == valeur,
        orElse: () => TypeEvenement.vacances,
      );
}

// ── ResumeEmploiDuTemps ──────────────────────────────────
class ResumeEmploiDuTemps {
  final int nombreClasses;
  final int nombreEmplois;
  final int nombreValides;
  final int nombreConflits;
  final int nombreSeancesAujourdhui;
  final int nombreIncomplets;

  ResumeEmploiDuTemps({
    required this.nombreClasses,
    required this.nombreEmplois,
    required this.nombreValides,
    required this.nombreConflits,
    required this.nombreSeancesAujourdhui,
    required this.nombreIncomplets,
  });

  factory ResumeEmploiDuTemps.fromJson(Map<String, dynamic> json) => ResumeEmploiDuTemps(
        nombreClasses: json['nombre_classes'] as int? ?? 0,
        nombreEmplois: json['nombre_emplois_crees'] as int? ?? 0,
        nombreValides: json['nombre_emplois_valides'] as int? ?? 0,
        nombreConflits: json['nombre_conflits'] as int? ?? 0,
        nombreSeancesAujourdhui: json['nombre_seances_aujourdhui'] as int? ?? 0,
        nombreIncomplets: json['nombre_emplois_incomplets'] as int? ?? 0,
      );
}

// ── DisponibiliteEnseignant ──────────────────────────────
// Statut d'un enseignant sur un jour + créneau donné : soit un point de
// la grille de disponibilité d'UN enseignant (getDisponibiliteEnseignant),
// soit — via [DisponibiliteEnseignant.pourEnseignant] — une ligne de la
// liste "enseignants disponibles à ce créneau" (getDisponibiliteCreneau).
class DisponibiliteEnseignant {
  final String jour;
  final int creneauId;
  final String libelleCreneau;
  final String statut; // libre | occupe
  final String? classeOccupee;
  final String? matiereOccupee;
  final int? enseignantId;
  final String? enseignantNom;

  DisponibiliteEnseignant({
    required this.jour,
    required this.creneauId,
    required this.libelleCreneau,
    required this.statut,
    this.classeOccupee,
    this.matiereOccupee,
    this.enseignantId,
    this.enseignantNom,
  });

  bool get estLibre => statut == 'libre';

  // Une entrée de la grille jour x créneau d'un enseignant donné.
  factory DisponibiliteEnseignant.fromJson(String jour, Map<String, dynamic> json) => DisponibiliteEnseignant(
        jour: jour,
        creneauId: json['creneau_horaire_id'] as int,
        libelleCreneau: json['creneau_libelle'] as String? ?? '',
        statut: json['statut'] as String? ?? 'libre',
        classeOccupee: json['classe_nom'] as String?,
        matiereOccupee: json['matiere_nom'] as String?,
      );

  // Une ligne "cet enseignant est libre/occupé à ce créneau" — jour et
  // créneau sont ceux déjà fixés par la requête, pas renvoyés par l'API.
  factory DisponibiliteEnseignant.pourEnseignant({
    required String jour,
    required int creneauId,
    required Map<String, dynamic> json,
  }) =>
      DisponibiliteEnseignant(
        jour: jour,
        creneauId: creneauId,
        libelleCreneau: '',
        statut: json['statut'] as String? ?? 'libre',
        classeOccupee: json['classe_nom'] as String?,
        matiereOccupee: json['matiere_nom'] as String?,
        enseignantId: json['enseignant_id'] as int?,
        enseignantNom: json['enseignant_nom'] as String?,
      );
}

// ── HeuresParEntite ───────────────────────────────────────
// Réutilisée pour les 3 répartitions d'heures (enseignant / matière /
// classe) : seule la clé "nom" change côté API selon l'endpoint.
class HeuresParEntite {
  final int? id;
  final String nom;
  final double heures;
  final int nombreSeances;

  HeuresParEntite({this.id, required this.nom, required this.heures, this.nombreSeances = 0});

  factory HeuresParEntite.fromJson(Map<String, dynamic> json) => HeuresParEntite(
        id: (json['enseignant_id'] ?? json['matiere_id'] ?? json['classe_id']) as int?,
        nom: (json['enseignant_nom'] ?? json['matiere_nom'] ?? json['classe_nom']) as String? ?? '',
        heures: double.tryParse(json['heures'].toString()) ?? 0,
        nombreSeances: json['nombre_seances'] as int? ?? 0,
      );
}

// ── EvenementCalendrier ──────────────────────────────────
class EvenementCalendrier {
  final int? id;
  final TypeEvenement type;
  final String libelle;
  final DateTime dateDebut;
  final DateTime dateFin;

  EvenementCalendrier({
    this.id,
    required this.type,
    required this.libelle,
    required this.dateDebut,
    required this.dateFin,
  });

  factory EvenementCalendrier.fromJson(Map<String, dynamic> json) => EvenementCalendrier(
        id: json['id'] as int?,
        type: TypeEvenement.depuisApi(json['type'] as String?),
        libelle: json['libelle'] as String? ?? '',
        dateDebut: DateTime.parse(json['date_debut'] as String),
        dateFin: DateTime.parse(json['date_fin'] as String),
      );

  Map<String, dynamic> toJson() => {
        'type': type.valeurApi,
        'libelle': libelle,
        'date_debut': formatDate(dateDebut),
        'date_fin': formatDate(dateFin),
      };

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool concerneLe(DateTime date) {
    final j = DateTime(date.year, date.month, date.day);
    return !j.isBefore(DateTime(dateDebut.year, dateDebut.month, dateDebut.day)) &&
        !j.isAfter(DateTime(dateFin.year, dateFin.month, dateFin.day));
  }
}
