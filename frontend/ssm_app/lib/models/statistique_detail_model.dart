// ══════════════════════════════════════════════════════════
// Modèles des écrans détaillés du module Statistiques (Phase 5) :
// inscriptions, paiements, pédagogique, centre de décision.
// ══════════════════════════════════════════════════════════

// ── RepartitionNiveau ─────────────────────────────────────
// Fusionne /inscriptions/par-niveau (total, nombre de classes) et
// /inscriptions/par-sexe (garçons/filles par niveau) — voir
// StatistiqueDetailService.getInscriptionsParNiveau().
class RepartitionNiveau {
  final String niveau;
  final int total;
  final int garcons;
  final int filles;

  RepartitionNiveau({
    required this.niveau,
    required this.total,
    required this.garcons,
    required this.filles,
  });

  factory RepartitionNiveau.fromJson(Map<String, dynamic> json) => RepartitionNiveau(
        niveau: json['niveau'] as String? ?? '—',
        total: (json['total'] as num?)?.toInt() ?? 0,
        garcons: (json['garcons'] as num?)?.toInt() ?? 0,
        filles: (json['filles'] as num?)?.toInt() ?? 0,
      );
}

// ── RepartitionClasse ─────────────────────────────────────
class RepartitionClasse {
  final String classe;
  final int total;

  RepartitionClasse({required this.classe, required this.total});

  factory RepartitionClasse.fromJson(Map<String, dynamic> json) => RepartitionClasse(
        classe: json['classe_nom'] as String? ?? '—',
        total: (json['effectif'] as num?)?.toInt() ?? 0,
      );
}

// ── EvolutionEffectif ─────────────────────────────────────
class EvolutionEffectif {
  final String annee;
  final int total;

  EvolutionEffectif({required this.annee, required this.total});

  factory EvolutionEffectif.fromJson(Map<String, dynamic> json) => EvolutionEffectif(
        annee: json['annee_libelle'] as String? ?? '—',
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

// ── PaiementClasse ────────────────────────────────────────
// Réutilisée aussi pour "par niveau" (le champ `classe` porte alors le nom
// du niveau) — même forme renvoyée par les deux endpoints backend.
class PaiementClasse {
  final String classe;
  final int elevesAJour;
  final int elevesEnRetard;
  final double resteAPayer;
  final double tauxRecouvrement;

  PaiementClasse({
    required this.classe,
    required this.elevesAJour,
    required this.elevesEnRetard,
    required this.resteAPayer,
    required this.tauxRecouvrement,
  });

  factory PaiementClasse.fromJson(Map<String, dynamic> json) => PaiementClasse(
        classe: (json['classe_nom'] ?? json['niveau']) as String? ?? '—',
        elevesAJour: (json['eleves_a_jour'] as num?)?.toInt() ?? 0,
        elevesEnRetard: (json['eleves_en_retard'] as num?)?.toInt() ?? 0,
        resteAPayer: (json['reste_a_payer'] as num?)?.toDouble() ?? 0.0,
        tauxRecouvrement: (json['taux_recouvrement'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── PaiementMensuel ───────────────────────────────────────
class PaiementMensuel {
  final String mois;
  final double montantEncaisse;

  PaiementMensuel({required this.mois, required this.montantEncaisse});

  factory PaiementMensuel.fromJson(Map<String, dynamic> json) => PaiementMensuel(
        mois: json['libelle'] as String? ?? '—',
        montantEncaisse: (json['montant'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── EleveNonEnRegle ───────────────────────────────────────
class EleveNonEnRegle {
  final String nom;
  final String prenom;
  final String classe;
  final String? telephoneParent;
  final double resteAPayer;

  EleveNonEnRegle({
    required this.nom,
    required this.prenom,
    required this.classe,
    required this.telephoneParent,
    required this.resteAPayer,
  });

  String get nomComplet => '$nom $prenom';

  factory EleveNonEnRegle.fromJson(Map<String, dynamic> json) => EleveNonEnRegle(
        nom: json['nom'] as String? ?? '',
        prenom: json['prenom'] as String? ?? '',
        classe: json['classe_nom'] as String? ?? 'Non affecté',
        telephoneParent: json['telephone_parent'] as String?,
        resteAPayer: (json['reste_a_payer'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── StatMatiere ───────────────────────────────────────────
class StatMatiere {
  final String matiere;
  final double? moyenneGenerale;
  final double? meilleureNote;
  final double? plusFaibleNote;
  final double tauxReussite;

  StatMatiere({
    required this.matiere,
    required this.moyenneGenerale,
    required this.meilleureNote,
    required this.plusFaibleNote,
    required this.tauxReussite,
  });

  factory StatMatiere.fromJson(Map<String, dynamic> json) => StatMatiere(
        matiere: json['matiere_nom'] as String? ?? '—',
        moyenneGenerale: (json['moyenne_generale'] as num?)?.toDouble(),
        meilleureNote: (json['meilleure_note'] as num?)?.toDouble(),
        plusFaibleNote: (json['plus_faible_note'] as num?)?.toDouble(),
        tauxReussite: (json['taux_reussite'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── StatEnseignant ────────────────────────────────────────
class StatEnseignant {
  final String nom;
  final int nbNotesSaisies;
  final int nbClasses;
  final double? moyenneClasses;

  StatEnseignant({
    required this.nom,
    required this.nbNotesSaisies,
    required this.nbClasses,
    required this.moyenneClasses,
  });

  factory StatEnseignant.fromJson(Map<String, dynamic> json) => StatEnseignant(
        nom: json['enseignant_nom'] as String? ?? '—',
        nbNotesSaisies: (json['notes_saisies'] as num?)?.toInt() ?? 0,
        nbClasses: (json['nombre_classes'] as num?)?.toInt() ?? 0,
        moyenneClasses: (json['moyenne_classes'] as num?)?.toDouble(),
      );
}

// ── StatClasse ────────────────────────────────────────────
// meilleurEleve/dernierEleve sont déjà formatés en libellé affichable
// ("Nom Prénom (moyenne/20)") à partir des objets imbriqués renvoyés par
// l'API, pour rester simple côté écran.
class StatClasse {
  final String classe;
  final double? moyenneGenerale;
  final String? meilleurEleve;
  final String? dernierEleve;
  final double tauxReussite;

  StatClasse({
    required this.classe,
    required this.moyenneGenerale,
    required this.meilleurEleve,
    required this.dernierEleve,
    required this.tauxReussite,
  });

  static String? _formaterEleve(dynamic json) {
    if (json == null) return null;
    final e = json as Map<String, dynamic>;
    return '${e['nom']} ${e['prenom']} (${e['moyenne']}/20)';
  }

  factory StatClasse.fromJson(Map<String, dynamic> json) => StatClasse(
        classe: json['classe_nom'] as String? ?? '—',
        moyenneGenerale: (json['moyenne_generale'] as num?)?.toDouble(),
        meilleurEleve: _formaterEleve(json['meilleur_eleve']),
        dernierEleve: _formaterEleve(json['dernier_eleve']),
        tauxReussite: (json['taux_reussite'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── EleveClassement ───────────────────────────────────────
// Le rang n'est pas renvoyé par l'API (simple liste triée) : il est fourni
// par l'appelant (position dans la liste), voir StatistiqueDetailService.
class EleveClassement {
  final int rang;
  final String nom;
  final String prenom;
  final String classe;
  final double? moyenne;

  EleveClassement({
    required this.rang,
    required this.nom,
    required this.prenom,
    required this.classe,
    required this.moyenne,
  });

  String get nomComplet => '$nom $prenom';

  factory EleveClassement.fromJson(Map<String, dynamic> json, int rang) => EleveClassement(
        rang: rang,
        nom: json['nom'] as String? ?? '',
        prenom: json['prenom'] as String? ?? '',
        classe: json['classe_nom'] as String? ?? '—',
        moyenne: (json['moyenne_generale'] as num?)?.toDouble(),
      );
}

// ── Alerte ─────────────────────────────────────────────────
class Alerte {
  final String type; // info | warning | danger
  final String titre;
  final String description;
  final num valeur;
  final String action;
  final String routeAction;

  Alerte({
    required this.type,
    required this.titre,
    required this.description,
    required this.valeur,
    required this.action,
    required this.routeAction,
  });

  factory Alerte.fromJson(Map<String, dynamic> json) => Alerte(
        type: json['type'] as String? ?? 'info',
        titre: json['titre'] as String? ?? '',
        description: json['description'] as String? ?? '',
        valeur: (json['valeur'] as num?) ?? 0,
        action: json['action'] as String? ?? 'Voir',
        routeAction: json['route_action'] as String? ?? '',
      );

  String get valeurFormatee => valeur % 1 == 0 ? valeur.toInt().toString() : valeur.toStringAsFixed(1);
}
