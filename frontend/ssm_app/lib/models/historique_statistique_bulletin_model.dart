import 'bulletin_model.dart';

double _versDouble(dynamic valeur) => double.parse((valeur ?? 0).toString());

double? _versDoubleNullable(dynamic valeur) => valeur == null ? null : double.tryParse(valeur.toString());

int _versEntier(dynamic valeur) => (valeur as num?)?.toInt() ?? 0;

// ══════════════════════════════════════════════════════════
// BulletinHistorique — résumé plat d'un bulletin, utilisé aussi bien par
// la recherche (GET /bulletins/historique/rechercher, un bulletin par
// ligne avec élève/classe/période/année déjà imbriqués) que par
// l'historique d'un élève (GET /bulletins/historique/eleve/{id}, dont la
// structure imbriquée année → périodes est aplatie ici en une liste — le
// regroupement pour l'affichage en arborescence se fait côté écran, voir
// historique_bulletins_eleve_screen.dart).
//
// classeId n'est pas exposé par l'endpoint "historique d'un élève" (qui ne
// renvoie que le nom de la classe, pas son id) : il reste donc nullable.
// ══════════════════════════════════════════════════════════
class BulletinHistorique {
  final int id;
  final int eleveId;
  final String? nomEleve;
  final int? classeId;
  final String? nomClasse;
  final int periodeId;
  final String? nomPeriode;
  final int? anneeScolaireId;
  final String? nomAnnee;
  final double moyenneGenerale;
  final int? rang;
  final StatutBulletin statut;

  BulletinHistorique({
    required this.id,
    required this.eleveId,
    this.nomEleve,
    this.classeId,
    this.nomClasse,
    required this.periodeId,
    this.nomPeriode,
    this.anneeScolaireId,
    this.nomAnnee,
    required this.moyenneGenerale,
    this.rang,
    this.statut = StatutBulletin.genere,
  });

  // Depuis GET /bulletins/historique/rechercher.
  factory BulletinHistorique.fromJson(Map<String, dynamic> json) {
    final eleve = json['eleve'] as Map<String, dynamic>?;
    final classe = json['classe'] as Map<String, dynamic>?;
    final periode = json['periode'] as Map<String, dynamic>?;
    final annee = json['annee_scolaire'] as Map<String, dynamic>?;

    return BulletinHistorique(
      id: json['id'] as int,
      eleveId: json['eleve_id'] as int,
      nomEleve: eleve != null ? '${eleve['nom'] ?? ''} ${eleve['prenom'] ?? ''}'.trim() : null,
      classeId: json['classe_id'] as int?,
      nomClasse: classe?['nom'] as String?,
      periodeId: json['periode_id'] as int,
      nomPeriode: periode?['nom'] as String?,
      anneeScolaireId: json['annee_scolaire_id'] as int?,
      nomAnnee: annee?['libelle'] as String?,
      moyenneGenerale: _versDouble(json['moyenne_generale']),
      rang: json['rang'] as int?,
      statut: StatutBulletin.depuisApi(json['statut'] as String? ?? 'genere'),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ResultatRechercheBulletins — page de résultats de la recherche
// (l'endpoint est paginé, 30/page).
// ══════════════════════════════════════════════════════════
class ResultatRechercheBulletins {
  final List<BulletinHistorique> resultats;
  final int currentPage;
  final int lastPage;
  final int total;

  ResultatRechercheBulletins({
    required this.resultats,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get aPlusDePages => currentPage < lastPage;

  factory ResultatRechercheBulletins.fromJson(Map<String, dynamic> json) {
    return ResultatRechercheBulletins(
      resultats: (json['data'] as List? ?? [])
          .map((b) => BulletinHistorique.fromJson(b as Map<String, dynamic>))
          .toList(),
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      total: json['total'] as int? ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════
// StatistiqueClasseBulletin — GET /bulletins/statistiques/classe/{c}/{p}
// ══════════════════════════════════════════════════════════
class StatistiqueClasseBulletin {
  final int? classeId;
  final int? periodeId;
  final int effectif;
  final double? moyenneClasse;
  final double? meilleureMoyenne;
  final double? plusFaibleMoyenne;
  final int nombreAuDessusDe10;
  final int nombreEnDessousDe10;
  final double tauxReussite;

  StatistiqueClasseBulletin({
    this.classeId,
    this.periodeId,
    required this.effectif,
    this.moyenneClasse,
    this.meilleureMoyenne,
    this.plusFaibleMoyenne,
    required this.nombreAuDessusDe10,
    required this.nombreEnDessousDe10,
    required this.tauxReussite,
  });

  factory StatistiqueClasseBulletin.fromJson(Map<String, dynamic> json) {
    return StatistiqueClasseBulletin(
      classeId: json['classe_id'] as int?,
      periodeId: json['periode_id'] as int?,
      effectif: _versEntier(json['effectif']),
      moyenneClasse: _versDoubleNullable(json['moyenne_classe']),
      meilleureMoyenne: _versDoubleNullable(json['meilleure_moyenne']),
      plusFaibleMoyenne: _versDoubleNullable(json['plus_faible_moyenne']),
      nombreAuDessusDe10: _versEntier(json['nombre_eleves_superieur_egal_10']),
      nombreEnDessousDe10: _versEntier(json['nombre_eleves_inferieur_10']),
      tauxReussite: _versDouble(json['taux_reussite']),
    );
  }
}

// ══════════════════════════════════════════════════════════
// DistributionMoyenne — une tranche de
// GET /bulletins/statistiques/distribution/{c}/{p}
// ══════════════════════════════════════════════════════════
class DistributionMoyenne {
  final String tranche;
  final int nombre;
  final double pourcentage;

  DistributionMoyenne({required this.tranche, required this.nombre, this.pourcentage = 0});

  factory DistributionMoyenne.fromJson(Map<String, dynamic> json) {
    return DistributionMoyenne(
      tranche: json['tranche'] as String,
      nombre: _versEntier(json['nombre_eleves']),
      pourcentage: _versDouble(json['pourcentage']),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ComparaisonPeriodesBulletin — GET /bulletins/statistiques/comparaison
// ══════════════════════════════════════════════════════════
class ComparaisonPeriodesBulletin {
  final int classeId;
  final StatistiqueClasseBulletin periode1;
  final StatistiqueClasseBulletin periode2;
  final double? evolutionMoyenneClasse;
  final String? progression; // 'hausse' | 'baisse' | 'stable'

  ComparaisonPeriodesBulletin({
    required this.classeId,
    required this.periode1,
    required this.periode2,
    this.evolutionMoyenneClasse,
    this.progression,
  });

  factory ComparaisonPeriodesBulletin.fromJson(Map<String, dynamic> json) {
    return ComparaisonPeriodesBulletin(
      classeId: json['classe_id'] as int,
      periode1: StatistiqueClasseBulletin.fromJson(json['periode_1'] as Map<String, dynamic>),
      periode2: StatistiqueClasseBulletin.fromJson(json['periode_2'] as Map<String, dynamic>),
      evolutionMoyenneClasse: _versDoubleNullable(json['evolution_moyenne_classe']),
      progression: json['progression'] as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════
// CorrectionBulletin — une ligne de
// GET /bulletins/corrections/{bulletinId}/historique
//
// demandePar est exposé en String (nom de l'utilisateur) plutôt qu'en id :
// côté backend, la relation Eloquent "demandePar" (chargée via
// ->with('demandePar:id,name')) est sérialisée sous la même clé snake_case
// que la colonne brute demande_par et l'écrase dans le JSON — demande_par
// arrive donc déjà comme un objet {id, name}, pas comme un entier.
// ══════════════════════════════════════════════════════════
class CorrectionBulletin {
  final int id;
  final String champModifie;
  final String? ancienneValeur;
  final String? nouvelleValeur;
  final String motif;
  final String demandePar;
  final DateTime? createdAt;

  CorrectionBulletin({
    required this.id,
    required this.champModifie,
    this.ancienneValeur,
    this.nouvelleValeur,
    required this.motif,
    required this.demandePar,
    this.createdAt,
  });

  factory CorrectionBulletin.fromJson(Map<String, dynamic> json) {
    final demandeParBrut = json['demande_par'];
    String demandePar = '—';
    if (demandeParBrut is Map) {
      demandePar = demandeParBrut['name'] as String? ?? '—';
    } else if (demandeParBrut is int) {
      demandePar = 'Utilisateur #$demandeParBrut';
    }

    return CorrectionBulletin(
      id: json['id'] as int,
      champModifie: json['champ_modifie'] as String,
      ancienneValeur: json['ancienne_valeur'] as String?,
      nouvelleValeur: json['nouvelle_valeur'] as String?,
      motif: json['motif'] as String? ?? '',
      demandePar: demandePar,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
