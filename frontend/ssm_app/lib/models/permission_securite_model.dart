// Modèles des sections Utilisateurs & Permissions, Sécurité, Système et
// Actions avancées du module Paramètres de l'École. Les clés JSON
// reprennent celles de l'API Laravel (voir
// backend/app/Http/Controllers/Api/PermissionRoleController.php,
// SecuriteController.php, SystemeController.php, ActionAvanceeController.php).

// ══════════════════════════════════════════════════════════
// Rôles utilisateur — aligné sur users.role / PermissionRole::ROLES côté
// backend (super_admin exclu : ce n'est pas un rôle géré par école).
// ══════════════════════════════════════════════════════════
enum RoleUtilisateur {
  directeur('directeur', 'Directeur'),
  censeur('censeur', 'Censeur'),
  enseignant('enseignant', 'Enseignant'),
  secretaire('secretaire', 'Secrétaire'),
  comptable('comptable', 'Comptable');

  final String valeur;
  final String libelle;
  const RoleUtilisateur(this.valeur, this.libelle);

  static RoleUtilisateur fromValeur(String valeur) {
    return RoleUtilisateur.values.firstWhere(
      (r) => r.valeur == valeur,
      orElse: () => RoleUtilisateur.enseignant,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Une entrée de la matrice de permissions — GET/PUT /parametres/permissions
// ══════════════════════════════════════════════════════════
class PermissionRole {
  final String role;
  final String module;
  final String? moduleLibelle;
  final bool peutConsulter;
  final bool peutCreer;
  final bool peutModifier;
  final bool peutSupprimer;
  final bool peutValider;

  const PermissionRole({
    required this.role,
    required this.module,
    this.moduleLibelle,
    required this.peutConsulter,
    required this.peutCreer,
    required this.peutModifier,
    required this.peutSupprimer,
    required this.peutValider,
  });

  factory PermissionRole.fromJson(Map<String, dynamic> json) {
    return PermissionRole(
      role: json['role'] as String,
      module: json['module'] as String,
      moduleLibelle: json['module_libelle'] as String?,
      peutConsulter: json['peut_consulter'] as bool? ?? false,
      peutCreer: json['peut_creer'] as bool? ?? false,
      peutModifier: json['peut_modifier'] as bool? ?? false,
      peutSupprimer: json['peut_supprimer'] as bool? ?? false,
      peutValider: json['peut_valider'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'module': module,
        'peut_consulter': peutConsulter,
        'peut_creer': peutCreer,
        'peut_modifier': peutModifier,
        'peut_supprimer': peutSupprimer,
        'peut_valider': peutValider,
      };

  PermissionRole copyWith({
    bool? peutConsulter,
    bool? peutCreer,
    bool? peutModifier,
    bool? peutSupprimer,
    bool? peutValider,
  }) {
    return PermissionRole(
      role: role,
      module: module,
      moduleLibelle: moduleLibelle,
      peutConsulter: peutConsulter ?? this.peutConsulter,
      peutCreer: peutCreer ?? this.peutCreer,
      peutModifier: peutModifier ?? this.peutModifier,
      peutSupprimer: peutSupprimer ?? this.peutSupprimer,
      peutValider: peutValider ?? this.peutValider,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Session Sanctum active — GET /parametres/securite/sessions
// Remarque : l'API ne renseigne pas l'IP à cet endroit (seule
// ConnexionHistorique en dispose, via connexions_utilisateurs) ; le champ
// est conservé nullable pour rester fidèle à la demande mais reste vide
// tant que le backend ne l'expose pas ici.
// ══════════════════════════════════════════════════════════
class SessionActive {
  final int tokenId;
  final String? appareil;
  final String? ip;
  final DateTime? derniereActivite;
  final bool actuelle;

  const SessionActive({
    required this.tokenId,
    this.appareil,
    this.ip,
    this.derniereActivite,
    required this.actuelle,
  });

  factory SessionActive.fromJson(Map<String, dynamic> json) {
    return SessionActive(
      tokenId: json['id'] as int,
      appareil: json['nom'] as String?,
      ip: json['ip'] as String?,
      derniereActivite: json['derniere_utilisation'] != null ? DateTime.tryParse(json['derniere_utilisation'] as String) : null,
      actuelle: json['est_actuelle'] as bool? ?? false,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Ligne d'historique de connexion — GET /parametres/securite/historique-connexions
// ══════════════════════════════════════════════════════════
class ConnexionHistorique {
  final int userId;
  final String? nomUser;
  final String? roleUser;
  final DateTime? dateConnexion;
  final String? ip;
  final String? appareil;

  const ConnexionHistorique({
    required this.userId,
    this.nomUser,
    this.roleUser,
    this.dateConnexion,
    this.ip,
    this.appareil,
  });

  factory ConnexionHistorique.fromJson(Map<String, dynamic> json) {
    final utilisateur = json['utilisateur'] as Map<String, dynamic>?;
    return ConnexionHistorique(
      userId: json['user_id'] as int,
      nomUser: utilisateur?['name'] as String?,
      roleUser: utilisateur?['role'] as String?,
      dateConnexion: json['date_connexion'] != null ? DateTime.tryParse(json['date_connexion'] as String) : null,
      ip: json['ip'] as String?,
      appareil: json['appareil'] as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Ligne du journal global — GET /parametres/securite/journal-actions
// ══════════════════════════════════════════════════════════
class ActionJournal {
  final int? userId;
  final String? nomUser;
  final String module;
  final String action;
  final String? description;
  final DateTime? dateAction;

  const ActionJournal({
    this.userId,
    this.nomUser,
    required this.module,
    required this.action,
    this.description,
    this.dateAction,
  });

  factory ActionJournal.fromJson(Map<String, dynamic> json) {
    final utilisateur = json['utilisateur'] as Map<String, dynamic>?;
    return ActionJournal(
      userId: json['user_id'] as int?,
      nomUser: utilisateur?['name'] as String?,
      module: json['module'] as String? ?? '—',
      action: json['action'] as String? ?? '—',
      description: json['description'] as String?,
      dateAction: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Statut système — GET /parametres/systeme/statut
// ══════════════════════════════════════════════════════════
class StatutSysteme {
  final String version;
  final String etatServeur;
  final String etatBaseDonnees;
  final String etatSynchronisation;

  const StatutSysteme({
    required this.version,
    required this.etatServeur,
    required this.etatBaseDonnees,
    required this.etatSynchronisation,
  });

  factory StatutSysteme.fromJson(Map<String, dynamic> json) {
    return StatutSysteme(
      version: json['version'] as String? ?? '—',
      etatServeur: json['serveur'] as String? ?? 'inconnu',
      etatBaseDonnees: json['base_de_donnees'] as String? ?? 'inconnu',
      etatSynchronisation: json['synchronisation'] as String? ?? 'inconnu',
    );
  }

  bool get serveurOperationnel => etatServeur == 'operationnel';
  bool get baseDonneesOperationnelle => etatBaseDonnees == 'operationnel';
  bool get synchronisationAJour => etatSynchronisation == 'a_jour';
}

// ══════════════════════════════════════════════════════════
// Statut de sauvegarde — GET /parametres/systeme/sauvegarde
// ══════════════════════════════════════════════════════════
class SauvegardeInfo {
  final DateTime? dateDerniereSauvegarde;
  final String statut; // reussie | echouee | en_cours
  final int? tailleFichier;

  const SauvegardeInfo({
    this.dateDerniereSauvegarde,
    required this.statut,
    this.tailleFichier,
  });

  factory SauvegardeInfo.fromJson(Map<String, dynamic> json) {
    return SauvegardeInfo(
      dateDerniereSauvegarde: json['date_derniere_sauvegarde'] != null ? DateTime.tryParse(json['date_derniere_sauvegarde'] as String) : null,
      statut: json['statut'] as String? ?? 'en_cours',
      tailleFichier: json['taille_fichier'] as int?,
    );
  }
}
