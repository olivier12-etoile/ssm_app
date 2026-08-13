// ══════════════════════════════════════════════════════════
// Modèles du module Emploi du Temps
// ══════════════════════════════════════════════════════════

// ── TypeCreneau ──────────────────────────────────────────
enum TypeCreneau {
  cours('cours', 'Cours'),
  recreation('recreation', 'Récréation'),
  pause('pause', 'Pause');

  final String valeurApi;
  final String libelle;

  const TypeCreneau(this.valeurApi, this.libelle);

  static TypeCreneau depuisApi(String? valeur) => TypeCreneau.values.firstWhere(
        (t) => t.valeurApi == valeur,
        orElse: () => TypeCreneau.cours,
      );
}

// ── JourSemaine ──────────────────────────────────────────
enum JourSemaine {
  lundi('lundi', 'Lundi'),
  mardi('mardi', 'Mardi'),
  mercredi('mercredi', 'Mercredi'),
  jeudi('jeudi', 'Jeudi'),
  vendredi('vendredi', 'Vendredi'),
  samedi('samedi', 'Samedi');

  final String valeurApi;
  final String libelle;

  const JourSemaine(this.valeurApi, this.libelle);

  static JourSemaine depuisApi(String? valeur) => JourSemaine.values.firstWhere(
        (j) => j.valeurApi == valeur,
        orElse: () => JourSemaine.lundi,
      );
}

// ── CreneauHoraire ───────────────────────────────────────
class CreneauHoraire {
  final int? id;
  final String libelle;
  final String heureDebut; // format "HH:mm"
  final String heureFin;   // format "HH:mm"
  final int ordre;
  final TypeCreneau type;

  CreneauHoraire({
    this.id,
    required this.libelle,
    required this.heureDebut,
    required this.heureFin,
    required this.ordre,
    this.type = TypeCreneau.cours,
  });

  factory CreneauHoraire.fromJson(Map<String, dynamic> json) {
    return CreneauHoraire(
      id: json['id'] as int?,
      libelle: json['libelle'] as String? ?? '',
      heureDebut: _normaliserHeure(json['heure_debut']),
      heureFin: _normaliserHeure(json['heure_fin']),
      ordre: json['ordre'] as int? ?? 0,
      type: TypeCreneau.depuisApi(json['type'] as String?),
    );
  }

  // L'API renvoie l'heure au format "HH:mm" (cast datetime:H:i côté
  // Laravel), on tolère aussi "HH:mm:ss" par prudence.
  static String _normaliserHeure(dynamic valeur) {
    final texte = valeur?.toString() ?? '';
    return texte.length >= 5 ? texte.substring(0, 5) : texte;
  }

  Map<String, dynamic> toJson() => {
        'libelle': libelle,
        'heure_debut': heureDebut,
        'heure_fin': heureFin,
        'ordre': ordre,
        'type': type.valeurApi,
      };

  // Comparaison lexicographique valide car les heures sont au format
  // "HH:mm" (zéro-paddé) — utilisée pour l'avertissement de chevauchement
  // affiché côté écran de paramétrage, avant même l'appel au serveur.
  bool chevaucheAvec(CreneauHoraire autre) {
    return heureDebut.compareTo(autre.heureFin) < 0 && heureFin.compareTo(autre.heureDebut) > 0;
  }
}

// ── JourTravaille ────────────────────────────────────────
class JourTravaille {
  final int? id;
  final JourSemaine jour;
  final bool actif;

  JourTravaille({this.id, required this.jour, this.actif = true});

  factory JourTravaille.fromJson(Map<String, dynamic> json) => JourTravaille(
        id: json['id'] as int?,
        jour: JourSemaine.depuisApi(json['jour'] as String?),
        actif: json['actif'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'jour': jour.valeurApi, 'actif': actif};
}

// ── Seance ───────────────────────────────────────────────
class Seance {
  final int? id;
  final int creneauHoraireId;
  final String jour; // valeur API : lundi..samedi
  final int matiereId;
  final String? nomMatiere;
  final int enseignantId;
  final String? nomEnseignant;
  final String? salle;
  final String? couleur;

  Seance({
    this.id,
    required this.creneauHoraireId,
    required this.jour,
    required this.matiereId,
    this.nomMatiere,
    required this.enseignantId,
    this.nomEnseignant,
    this.salle,
    this.couleur,
  });

  factory Seance.fromJson(Map<String, dynamic> json) {
    final matiere = json['matiere'] as Map<String, dynamic>?;
    final enseignant = json['enseignant'] as Map<String, dynamic>?;

    return Seance(
      id: json['id'] as int?,
      creneauHoraireId: json['creneau_horaire_id'] as int,
      jour: json['jour'] as String,
      matiereId: json['matiere_id'] as int? ?? matiere?['id'] as int? ?? 0,
      nomMatiere: json['matiere_nom'] as String? ?? matiere?['nom'] as String?,
      enseignantId: json['enseignant_id'] as int? ?? enseignant?['id'] as int? ?? 0,
      // Le modèle User (Laravel) porte la colonne "name", pas "nom".
      nomEnseignant: json['enseignant_nom'] as String? ?? enseignant?['name'] as String?,
      salle: json['salle'] as String?,
      couleur: json['couleur'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'creneau_horaire_id': creneauHoraireId,
        'jour': jour,
        'matiere_id': matiereId,
        'enseignant_id': enseignantId,
        'salle': salle,
        'couleur': couleur,
      };

  Seance copierAvec({
    int? id,
    int? creneauHoraireId,
    String? jour,
    int? matiereId,
    String? nomMatiere,
    int? enseignantId,
    String? nomEnseignant,
    String? salle,
    String? couleur,
  }) {
    return Seance(
      id: id ?? this.id,
      creneauHoraireId: creneauHoraireId ?? this.creneauHoraireId,
      jour: jour ?? this.jour,
      matiereId: matiereId ?? this.matiereId,
      nomMatiere: nomMatiere ?? this.nomMatiere,
      enseignantId: enseignantId ?? this.enseignantId,
      nomEnseignant: nomEnseignant ?? this.nomEnseignant,
      salle: salle ?? this.salle,
      couleur: couleur ?? this.couleur,
    );
  }
}

// ── ConflitDetecte ───────────────────────────────────────
class ConflitDetecte {
  final String type;
  final String message;
  final Map<String, dynamic> details;

  ConflitDetecte({required this.type, required this.message, this.details = const {}});

  factory ConflitDetecte.fromJson(Map<String, dynamic> json) => ConflitDetecte(
        type: json['type'] as String? ?? 'conflit',
        message: json['message'] as String? ?? 'Conflit détecté',
        details: json,
      );
}

// ── VolumeHoraireMatiere ─────────────────────────────────
class VolumeHoraireMatiere {
  final int matiereId;
  final String matiere; // nom de la matière
  final double heuresProgrammees;
  final double? heuresAttendues;

  VolumeHoraireMatiere({
    required this.matiereId,
    required this.matiere,
    required this.heuresProgrammees,
    this.heuresAttendues,
  });

  // Correspond à l'entrée renvoyée par l'accesseur "volumeHoraireParMatiere"
  // du modèle EmploiDuTemps côté backend : {matiere_id, matiere_nom,
  // nombre_seances, volume_horaire}. L'attendu (classe_matiere) n'y figure
  // pas, il est fusionné séparément via [avecAttendu].
  factory VolumeHoraireMatiere.fromJson(Map<String, dynamic> json) => VolumeHoraireMatiere(
        matiereId: json['matiere_id'] as int? ?? 0,
        matiere: json['matiere_nom'] as String? ?? '',
        heuresProgrammees: double.tryParse(json['volume_horaire'].toString()) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'matiere_id': matiereId,
        'matiere_nom': matiere,
        'volume_horaire': heuresProgrammees,
      };

  bool get estComplet => heuresAttendues != null && heuresProgrammees >= heuresAttendues!;

  VolumeHoraireMatiere avecAttendu(double? heuresAttendues) => VolumeHoraireMatiere(
        matiereId: matiereId,
        matiere: matiere,
        heuresProgrammees: heuresProgrammees,
        heuresAttendues: heuresAttendues,
      );
}

// ── EmploiDuTemps ────────────────────────────────────────
class EmploiDuTemps {
  final int? id;
  final int classeId;
  final String? classeNom;
  final int periodeId;
  final String statut; // brouillon | valide
  final Map<JourSemaine, Map<int, Seance>> grille;
  final List<VolumeHoraireMatiere> volumesHoraires;

  EmploiDuTemps({
    this.id,
    required this.classeId,
    this.classeNom,
    required this.periodeId,
    this.statut = 'brouillon',
    Map<JourSemaine, Map<int, Seance>>? grille,
    this.volumesHoraires = const [],
  }) : grille = grille ?? {};

  bool get estValide => statut == 'valide';

  Seance? seance(JourSemaine jour, int creneauHoraireId) => grille[jour]?[creneauHoraireId];

  // Objet "brut" tel que renvoyé par les endpoints de création
  // (POST /emplois-du-temps), sans ses séances.
  factory EmploiDuTemps.fromJson(Map<String, dynamic> json) {
    final classe = json['classe'] as Map<String, dynamic>?;
    return EmploiDuTemps(
      id: json['id'] as int?,
      classeId: json['classe_id'] as int? ?? classe?['id'] as int? ?? 0,
      classeNom: classe?['nom'] as String?,
      periodeId: json['periode_id'] as int? ?? 0,
      statut: json['statut'] as String? ?? 'brouillon',
    );
  }

  // Construit l'objet complet à partir de la réponse d'un endpoint de
  // détail (show, ou consultation par classe), qui renvoie séparément
  // l'emploi du temps, sa liste de séances et — pour l'endpoint show —
  // le volume horaire déjà programmé par matière.
  factory EmploiDuTemps.fromApiResponse(Map<String, dynamic> body) {
    final emploiJson = body['emploi_du_temps'] as Map<String, dynamic>?;
    final base = emploiJson != null ? EmploiDuTemps.fromJson(emploiJson) : null;
    final classe = body['classe'] as Map<String, dynamic>?;

    final grille = <JourSemaine, Map<int, Seance>>{};
    for (final s in (body['seances'] as List? ?? [])) {
      final seance = Seance.fromJson(s as Map<String, dynamic>);
      final jour = JourSemaine.depuisApi(seance.jour);
      grille.putIfAbsent(jour, () => {})[seance.creneauHoraireId] = seance;
    }

    return EmploiDuTemps(
      id: base?.id,
      classeId: base?.classeId ?? classe?['id'] as int? ?? 0,
      classeNom: base?.classeNom ?? classe?['nom'] as String?,
      periodeId: base?.periodeId ?? 0,
      statut: base?.statut ?? 'brouillon',
      grille: grille,
      volumesHoraires: (body['volume_horaire_par_matiere'] as List? ?? [])
          .map((v) => VolumeHoraireMatiere.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}
