import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
// StatutPresence — reflète l'enum backend (presences.statut).
// Couleurs alignées sur SSMPalette (teal/rouge/ambre) sans en
// dépendre directement : les modèles restent indépendants du
// thème dans ce projet (voir note_model.dart, bulletin_model.dart).
// ══════════════════════════════════════════════════════════
enum StatutPresence {
  present,
  absent,
  retard;

  String get label {
    switch (this) {
      case StatutPresence.present:
        return 'Présent';
      case StatutPresence.absent:
        return 'Absent';
      case StatutPresence.retard:
        return 'Retard';
    }
  }

  Color get couleur {
    switch (this) {
      case StatutPresence.present:
        return const Color(0xFF0D9488); // SSMPalette.teal
      case StatutPresence.absent:
        return const Color(0xFFEF4444); // SSMPalette.rouge
      case StatutPresence.retard:
        return const Color(0xFFD97706); // SSMPalette.ambre
    }
  }

  String get valeurApi => name;

  static StatutPresence depuisApi(String? valeur) => StatutPresence.values.firstWhere(
        (s) => s.name == valeur,
        orElse: () => StatutPresence.present,
      );
}

// ══════════════════════════════════════════════════════════
// Presence — ligne d'un appel (GET /presences/appels/{id}) OU
// ligne d'historique élève (GET /presences/historique/eleve/...),
// deux formes légèrement différentes renvoyées par le backend :
// - appel : id, eleve_id, eleve{nom,prenom,...}, statut, justifie...
// - historique : presence_id, date, classe, matiere, statut, justifie...
// fromJson() gère les deux formes.
// ══════════════════════════════════════════════════════════
class Presence {
  final int id;
  final int? eleveId;
  final String? nomEleve;
  final StatutPresence statut;
  final bool justifie;
  final String? motifJustification;
  final int? minutesRetard;
  final bool notifieParent;
  final String? date; // uniquement dans l'historique élève (Y-m-d)
  final String? classe; // idem
  final String? matiere; // idem

  Presence({
    required this.id,
    this.eleveId,
    this.nomEleve,
    this.statut = StatutPresence.present,
    this.justifie = false,
    this.motifJustification,
    this.minutesRetard,
    this.notifieParent = false,
    this.date,
    this.classe,
    this.matiere,
  });

  factory Presence.fromJson(Map<String, dynamic> json) {
    final eleve = json['eleve'] as Map<String, dynamic>?;
    return Presence(
      id: (json['id'] ?? json['presence_id']) as int,
      eleveId: json['eleve_id'] as int? ?? eleve?['id'] as int?,
      nomEleve: eleve != null ? '${eleve['nom'] ?? ''} ${eleve['prenom'] ?? ''}'.trim() : null,
      statut: StatutPresence.depuisApi(json['statut'] as String?),
      justifie: json['justifie'] as bool? ?? false,
      motifJustification: json['motif_justification'] as String?,
      minutesRetard: json['minutes_retard'] as int?,
      notifieParent: json['notifie_parent'] as bool? ?? false,
      date: json['date'] as String?,
      classe: json['classe'] as String?,
      matiere: json['matiere'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'eleve_id': eleveId,
        'statut': statut.valeurApi,
        'justifie': justifie,
        'motif_justification': motifJustification,
        'minutes_retard': minutesRetard,
      };

  Presence copyWith({
    StatutPresence? statut,
    bool? justifie,
    String? motifJustification,
    int? minutesRetard,
    bool? notifieParent,
  }) {
    return Presence(
      id: id,
      eleveId: eleveId,
      nomEleve: nomEleve,
      statut: statut ?? this.statut,
      justifie: justifie ?? this.justifie,
      motifJustification: motifJustification ?? this.motifJustification,
      minutesRetard: minutesRetard ?? this.minutesRetard,
      notifieParent: notifieParent ?? this.notifieParent,
      date: date,
      classe: classe,
      matiere: matiere,
    );
  }
}

// ══════════════════════════════════════════════════════════
// AppelPresence — une session d'appel (POST/GET /presences/appels)
// ══════════════════════════════════════════════════════════
class AppelPresence {
  final int id;
  final int classeId;
  final int? matiereId;
  final String? nomMatiere;
  final int enseignantId;
  final int periodeId;
  final DateTime dateAppel;
  final int? creneauHoraireId;
  final String statut; // en_cours | termine
  final List<Presence> presences;

  AppelPresence({
    required this.id,
    required this.classeId,
    this.matiereId,
    this.nomMatiere,
    required this.enseignantId,
    required this.periodeId,
    required this.dateAppel,
    this.creneauHoraireId,
    this.statut = 'en_cours',
    this.presences = const [],
  });

  bool get estTermine => statut == 'termine';

  int get nombrePresents => presences.where((p) => p.statut == StatutPresence.present).length;
  int get nombreAbsents => presences.where((p) => p.statut == StatutPresence.absent).length;
  int get nombreRetards => presences.where((p) => p.statut == StatutPresence.retard).length;

  factory AppelPresence.fromJson(Map<String, dynamic> json) {
    final matiere = json['matiere'] as Map<String, dynamic>?;
    return AppelPresence(
      id: json['id'] as int,
      classeId: json['classe_id'] as int,
      matiereId: json['matiere_id'] as int?,
      nomMatiere: matiere?['nom'] as String?,
      enseignantId: json['enseignant_id'] as int,
      periodeId: json['periode_id'] as int,
      dateAppel: DateTime.tryParse(json['date_appel'].toString()) ?? DateTime.now(),
      creneauHoraireId: json['creneau_horaire_id'] as int?,
      statut: json['statut'] as String? ?? 'en_cours',
      presences: (json['presences'] as List<dynamic>? ?? [])
          .map((p) => Presence.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'classe_id': classeId,
        'matiere_id': matiereId,
        'periode_id': periodeId,
        'date_appel': dateAppel.toIso8601String().split('T').first,
        'creneau_horaire_id': creneauHoraireId,
        'statut': statut,
      };
}

// ══════════════════════════════════════════════════════════
// HistoriquePresenceEleve — GET /presences/historique/eleve/{id}/{periodeId}
// ══════════════════════════════════════════════════════════
class HistoriquePresenceEleve {
  final int totalPresences;
  final int totalAbsencesJustifiees;
  final int totalAbsencesNonJustifiees;
  final int totalRetards;
  final double tauxPresence;
  final List<Presence> detail;

  HistoriquePresenceEleve({
    this.totalPresences = 0,
    this.totalAbsencesJustifiees = 0,
    this.totalAbsencesNonJustifiees = 0,
    this.totalRetards = 0,
    this.tauxPresence = 0,
    this.detail = const [],
  });

  factory HistoriquePresenceEleve.fromJson(Map<String, dynamic> json) {
    final totaux = json['totaux'] as Map<String, dynamic>? ?? {};
    final presences = json['presences'] as List<dynamic>? ?? [];
    return HistoriquePresenceEleve(
      totalPresences: totaux['presents'] as int? ?? 0,
      totalAbsencesJustifiees: totaux['absences_justifiees'] as int? ?? 0,
      totalAbsencesNonJustifiees: totaux['absences_non_justifiees'] as int? ?? 0,
      totalRetards: totaux['retards'] as int? ?? 0,
      tauxPresence: double.tryParse(totaux['taux_presence'].toString()) ?? 0,
      detail: presences.map((p) => Presence.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totaux': {
          'presents': totalPresences,
          'absences_justifiees': totalAbsencesJustifiees,
          'absences_non_justifiees': totalAbsencesNonJustifiees,
          'retards': totalRetards,
          'taux_presence': tauxPresence,
        },
        'presences': detail.map((p) => p.toJson()).toList(),
      };
}

// ══════════════════════════════════════════════════════════
// EleveAbsences — ligne du classement "élèves les plus absents"
// ══════════════════════════════════════════════════════════
class EleveAbsences {
  final int eleveId;
  final String nom;
  final String prenom;
  final int nombreAbsences; // justifiées + non justifiées
  final int retards;
  final double tauxPresence;

  EleveAbsences({
    required this.eleveId,
    required this.nom,
    required this.prenom,
    this.nombreAbsences = 0,
    this.retards = 0,
    this.tauxPresence = 0,
  });

  factory EleveAbsences.fromJson(Map<String, dynamic> json) {
    final absencesJustifiees = json['absences_justifiees'] as int? ?? 0;
    final absencesNonJustifiees = json['absences_non_justifiees'] as int? ?? 0;
    return EleveAbsences(
      eleveId: json['eleve_id'] as int,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      nombreAbsences: absencesJustifiees + absencesNonJustifiees,
      retards: json['retards'] as int? ?? 0,
      tauxPresence: double.tryParse(json['taux_presence'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'eleve_id': eleveId,
        'nom': nom,
        'prenom': prenom,
        'retards': retards,
        'taux_presence': tauxPresence,
      };
}

// ══════════════════════════════════════════════════════════
// StatistiquePresenceClasse — GET /presences/statistiques/classe/{id}/{periodeId}
// ══════════════════════════════════════════════════════════
class StatistiquePresenceClasse {
  final int totalAppels;
  final double tauxPresence;
  final List<EleveAbsences> elevesPlusAbsents;

  StatistiquePresenceClasse({
    this.totalAppels = 0,
    this.tauxPresence = 0,
    this.elevesPlusAbsents = const [],
  });

  factory StatistiquePresenceClasse.fromJson(Map<String, dynamic> json) {
    final eleves = (json['eleves'] as List<dynamic>? ?? [])
        .map((e) => EleveAbsences.fromJson(e as Map<String, dynamic>))
        .toList();
    return StatistiquePresenceClasse(
      totalAppels: json['total_appels'] as int? ?? 0,
      tauxPresence: double.tryParse(json['taux_presence_classe'].toString()) ?? 0,
      elevesPlusAbsents: eleves,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_appels': totalAppels,
        'taux_presence_classe': tauxPresence,
        'eleves': elevesPlusAbsents.map((e) => e.toJson()).toList(),
      };
}
