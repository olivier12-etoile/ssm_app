// ══════════════════════════════════════════════════════════
// PointEvolution — un jour de la courbe d'évolution
// ══════════════════════════════════════════════════════════
class PointEvolution {
  final String periode; // date au format yyyy-MM-dd
  final int envoyees;
  final int delivrees;
  final int echouees;

  PointEvolution({
    required this.periode,
    required this.envoyees,
    required this.delivrees,
    required this.echouees,
  });

  factory PointEvolution.fromJson(Map<String, dynamic> json) {
    return PointEvolution(
      periode: json['periode'] as String,
      envoyees: json['envoyees'] as int? ?? 0,
      delivrees: json['delivrees'] as int? ?? 0,
      echouees: json['echouees'] as int? ?? 0,
    );
  }

  DateTime get date => DateTime.parse(periode);
}

// ══════════════════════════════════════════════════════════
// StatistiqueNotification — résumé + répartitions + évolution
// ══════════════════════════════════════════════════════════
class StatistiqueNotification {
  final int totalEnvoyees;
  final int totalDelivrees;
  final int totalEchouees;
  final Map<String, int> parCanal;
  final Map<String, int> parCategorie;
  final List<PointEvolution> parPeriode;
  final double tauxReussite;

  StatistiqueNotification({
    this.totalEnvoyees = 0,
    this.totalDelivrees = 0,
    this.totalEchouees = 0,
    this.parCanal = const {},
    this.parCategorie = const {},
    this.parPeriode = const [],
    this.tauxReussite = 0.0,
  });

  int get totalDestinataires => totalEnvoyees + totalDelivrees + totalEchouees;

  factory StatistiqueNotification.fromJson(Map<String, dynamic> json) {
    return StatistiqueNotification(
      totalEnvoyees: json['total_envoyees'] as int? ?? 0,
      totalDelivrees: json['total_delivrees'] as int? ?? 0,
      totalEchouees: json['total_echouees'] as int? ?? 0,
      parCanal: _mapEntiers(json['par_canal']),
      parCategorie: _mapEntiers(json['par_categorie']),
      parPeriode: ((json['par_periode'] as List?) ?? [])
          .map((p) => PointEvolution.fromJson(p as Map<String, dynamic>))
          .toList(),
      tauxReussite: double.tryParse(json['taux_reussite']?.toString() ?? '0') ?? 0.0,
    );
  }

  static Map<String, int> _mapEntiers(dynamic valeur) {
    if (valeur is! Map) return {};
    return valeur.map((cle, v) => MapEntry(cle.toString(), (v as num).toInt()));
  }
}
