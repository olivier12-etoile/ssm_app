// ══════════════════════════════════════════════════════════
// Modèles du tableau de bord général du module Statistiques
// (GET /statistiques/dashboard/general).
// ══════════════════════════════════════════════════════════

// ── EffectifsGeneraux ────────────────────────────────────
class EffectifsGeneraux {
  final int totalEleves;
  final int garcons;
  final int filles;
  final int nouveauxInscrits;
  final int reinscriptions;
  final int transferes;
  final int renvoyes;
  final int abandons;

  EffectifsGeneraux({
    required this.totalEleves,
    required this.garcons,
    required this.filles,
    required this.nouveauxInscrits,
    required this.reinscriptions,
    required this.transferes,
    required this.renvoyes,
    required this.abandons,
  });

  factory EffectifsGeneraux.fromJson(Map<String, dynamic> json) => EffectifsGeneraux(
        totalEleves: (json['total'] as num?)?.toInt() ?? 0,
        garcons: (json['garcons'] as num?)?.toInt() ?? 0,
        filles: (json['filles'] as num?)?.toInt() ?? 0,
        nouveauxInscrits: (json['nouveaux_inscrits'] as num?)?.toInt() ?? 0,
        reinscriptions: (json['reinscriptions'] as num?)?.toInt() ?? 0,
        transferes: (json['transferes'] as num?)?.toInt() ?? 0,
        renvoyes: (json['renvoyes'] as num?)?.toInt() ?? 0,
        abandons: (json['abandons'] as num?)?.toInt() ?? 0,
      );
}

// ── EffectifsEnseignants ─────────────────────────────────
class EffectifsEnseignants {
  final int total;
  final int permanents;
  final int vacataires;
  final int actifs;

  EffectifsEnseignants({
    required this.total,
    required this.permanents,
    required this.vacataires,
    required this.actifs,
  });

  factory EffectifsEnseignants.fromJson(Map<String, dynamic> json) => EffectifsEnseignants(
        total: (json['total'] as num?)?.toInt() ?? 0,
        permanents: (json['permanents'] as num?)?.toInt() ?? 0,
        vacataires: (json['vacataires'] as num?)?.toInt() ?? 0,
        actifs: (json['actifs'] as num?)?.toInt() ?? 0,
      );
}

// ── EffectifsClasses ─────────────────────────────────────
class EffectifsClasses {
  final int total;
  final double moyenneElevesParClasse;
  final int sallesUtilisees;

  EffectifsClasses({
    required this.total,
    required this.moyenneElevesParClasse,
    required this.sallesUtilisees,
  });

  factory EffectifsClasses.fromJson(Map<String, dynamic> json) => EffectifsClasses(
        total: (json['total_classes'] as num?)?.toInt() ?? 0,
        moyenneElevesParClasse: (json['moyenne_eleves_classe'] as num?)?.toDouble() ?? 0.0,
        sallesUtilisees: (json['salles_utilisees'] as num?)?.toInt() ?? 0,
      );
}

// ── ResumeFinancierGlobal ────────────────────────────────
class ResumeFinancierGlobal {
  final double attendu;
  final double encaisse;
  final double reste;
  final double tauxRecouvrement;

  ResumeFinancierGlobal({
    required this.attendu,
    required this.encaisse,
    required this.reste,
    required this.tauxRecouvrement,
  });

  factory ResumeFinancierGlobal.fromJson(Map<String, dynamic> json) => ResumeFinancierGlobal(
        attendu: (json['montant_attendu'] as num?)?.toDouble() ?? 0.0,
        encaisse: (json['montant_encaisse'] as num?)?.toDouble() ?? 0.0,
        reste: (json['montant_restant'] as num?)?.toDouble() ?? 0.0,
        tauxRecouvrement: (json['taux_recouvrement'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── ResumeResultatsGlobal ────────────────────────────────
class ResumeResultatsGlobal {
  final double? moyenneGenerale;
  final double tauxReussite;
  final double tauxEchec;
  final int nombreAuDessusDe10;
  final int nombreEnDessousDe10;

  // Répartition des élèves par tranche de moyenne (<10, 10-12, 12-14,
  // 14-16, >16) : pas encore renvoyée par l'API (dashboard/general), donc
  // toujours null pour l'instant. Le modèle la prévoit déjà pour que
  // l'écran puisse l'afficher dès qu'un backend la fournira, sans autre
  // changement Flutter.
  final Map<String, int>? repartitionMoyennes;

  ResumeResultatsGlobal({
    required this.moyenneGenerale,
    required this.tauxReussite,
    required this.tauxEchec,
    required this.nombreAuDessusDe10,
    required this.nombreEnDessousDe10,
    this.repartitionMoyennes,
  });

  factory ResumeResultatsGlobal.fromJson(Map<String, dynamic> json) => ResumeResultatsGlobal(
        moyenneGenerale: (json['moyenne_generale'] as num?)?.toDouble(),
        tauxReussite: (json['taux_reussite'] as num?)?.toDouble() ?? 0.0,
        tauxEchec: (json['taux_echec'] as num?)?.toDouble() ?? 0.0,
        nombreAuDessusDe10: (json['nombre_eleves_ge_10'] as num?)?.toInt() ?? 0,
        nombreEnDessousDe10: (json['nombre_eleves_lt_10'] as num?)?.toInt() ?? 0,
        repartitionMoyennes: (json['repartition_moyennes'] as Map<String, dynamic>?)
            ?.map((cle, valeur) => MapEntry(cle, (valeur as num?)?.toInt() ?? 0)),
      );
}

// ── DashboardGeneral ──────────────────────────────────────
class DashboardGeneral {
  final int anneeScolaireId;
  final int? periodeId;
  final EffectifsGeneraux effectifs;
  final EffectifsEnseignants enseignants;
  final EffectifsClasses classes;
  final ResumeFinancierGlobal financier;
  final ResumeResultatsGlobal resultats;

  DashboardGeneral({
    required this.anneeScolaireId,
    required this.periodeId,
    required this.effectifs,
    required this.enseignants,
    required this.classes,
    required this.financier,
    required this.resultats,
  });

  factory DashboardGeneral.fromJson(Map<String, dynamic> json) => DashboardGeneral(
        anneeScolaireId: (json['annee_scolaire_id'] as num?)?.toInt() ?? 0,
        periodeId: (json['periode_id'] as num?)?.toInt(),
        effectifs: EffectifsGeneraux.fromJson(json['effectifs'] as Map<String, dynamic>? ?? const {}),
        enseignants: EffectifsEnseignants.fromJson(json['enseignants'] as Map<String, dynamic>? ?? const {}),
        classes: EffectifsClasses.fromJson(json['classes'] as Map<String, dynamic>? ?? const {}),
        financier: ResumeFinancierGlobal.fromJson(json['financier'] as Map<String, dynamic>? ?? const {}),
        resultats: ResumeResultatsGlobal.fromJson(json['resultats'] as Map<String, dynamic>? ?? const {}),
      );
}
