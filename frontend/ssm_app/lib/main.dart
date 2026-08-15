import 'package:flutter/material.dart';
import 'config/theme_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/changement_mdp_screen.dart';
import 'screens/dashboard/dashboard_directeur_screen.dart';
import 'screens/directeur/gestion_utilisateurs_screen.dart';
import 'screens/directeur/fiche_utilisateur_screen.dart';
import 'screens/directeur/gestion_classes_screen.dart';
import 'screens/directeur/fiche_classe_screen.dart';
import 'screens/directeur/gestion_matieres_screen.dart';
import 'screens/directeur/matieres_par_classe_screen.dart';
import 'screens/directeur/fiche_matiere_classe_screen.dart';
import 'screens/directeur/gestion_annees_screen.dart';
import 'screens/directeur/fiche_annee_screen.dart';
import 'screens/directeur/rangs_classe_screen.dart';
import 'screens/directeur/eleves_non_en_regle_screen.dart';
import 'screens/directeur/gestion_eleves_screen.dart';
import 'screens/directeur/liste_intelligente_screen.dart';
import 'screens/directeur/eleves_par_classe_screen.dart';
import 'screens/directeur/fiche_eleve_screen.dart';
import 'screens/directeur/gestion_affectations_screen.dart';
import 'screens/directeur/affectations_classe_screen.dart';
import 'screens/notes/validation_notes_screen.dart';
import 'screens/notes/selection_saisie_screen.dart';
import 'screens/notes/notes_module_screen.dart';
import 'screens/parametres/frais_scolaires_screen.dart';
import 'screens/directeur/dashboard_censeur_screen.dart';
import 'screens/censeur/suivi_absences_classe_screen.dart';
import 'screens/enseignant/saisie_absences_screen.dart';
import 'screens/enseignant/liste_presence_screen.dart';
import 'screens/enseignant/dashboard_enseignant_screen.dart';
import 'screens/emploi_du_temps/emploi_du_temps_module_screen.dart';
import 'screens/emploi_du_temps/parametrage_creneaux_screen.dart';
import 'screens/secretaire/gestion_paiements_screen.dart';
import 'screens/secretaire/liste_renvoi_screen.dart';
import 'screens/paiements/gestion_caisse_screen.dart';
import 'screens/paiements/rapports_paiements_screen.dart';
import 'screens/secretaire/dashboard_secretaire_screen.dart';
import 'screens/profil/profil_screen.dart';
import 'screens/statistiques/statistiques_module_screen.dart';
import 'screens/bulletins/bulletins_module_screen.dart';
import 'screens/sync/sync_screen.dart';
import 'screens/notifications/notifications_module_screen.dart';
import 'screens/parametres/parametres_module_screen.dart';

void main() {
  runApp(const SSMApp());
}

class SSMApp extends StatelessWidget {
  const SSMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart School Manager',
      debugShowCheckedModeBanner: false,
      theme: SSMTheme.themeClaire,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/changer-mot-de-passe': (context) => const ChangementMdpScreen(),
        '/tableau-de-bord': (context) => const DashboardDirecteurScreen(),
        '/dashboard/enseignant': (context) => const DashboardEnseignantScreen(),
        '/dashboard/censeur': (context) => const DashboardCenseurScreen(),
        '/censeur/classe/absences': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return SuiviAbsencesClasseScreen(
            classeId: args['classeId'] as int,
            classeNom: args['classeNom'] as String,
          );
        },
        '/dashboard/secretaire': (context) => const DashboardSecretaireScreen(),
        '/directeur/utilisateurs': (context) =>
            const GestionUtilisateursScreen(),
        '/directeur/utilisateur/fiche': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return FicheUtilisateurScreen(userId: args['userId'] as int);
        },
        '/directeur/classes': (context) => const GestionClassesScreen(),
        '/directeur/classe/fiche': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return FicheClasseScreen(classeId: args['classeId'] as int);
        },
        '/directeur/matieres': (context) => const GestionMatieresScreen(),
        '/directeur/matieres/classe': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return MatieresParClasseScreen(
            classeId: args['classeId'] as int,
            nomClasse: args['nomClasse'] as String?,
          );
        },
        '/directeur/matiere/fiche': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return FicheMatiereClasseScreen(
            classeId: args['classeId'] as int,
            classeNom: args['classeNom'] as String,
            matiereId: args['matiereId'] as int,
            matiereNom: args['matiereNom'] as String,
            couleurMatiere: args['couleurMatiere'] as Color,
            coefficient: args['coefficient'] as double,
            enseignantNom: args['enseignantNom'] as String?,
          );
        },
        '/directeur/annees': (context) => const GestionAnneesScreen(),
        '/directeur/annee/fiche': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return FicheAnneeScreen(
            anneeId: args['anneeId'] as int,
            libelle: args['libelle'] as String,
            statut: args['statut'] as String,
          );
        },
        '/directeur/rangs': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return RangsClasseScreen(
            classeId: args['classeId'] as int,
            classeNom: args['classeNom'] as String,
            periodeId: args['periodeId'] as int,
            periodeNom: args['periodeNom'] as String,
          );
        },
        '/directeur/eleves-non-regle': (context) =>
            const ElevesNonEnRegleScreen(),
        '/directeur/frais': (context) => const FraisScolairesScreen(),
        '/directeur/eleves': (context) => const GestionElevesScreen(),
        '/eleves/liste-intelligente': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ListeIntelligenteScreen(
            type: args['type'] as String,
            titre: args['titre'] as String,
          );
        },
        '/directeur/eleves/classe': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ElevesParClasseScreen(
            classeId: args['classeId'] as int,
            anneeId: args['anneeId'] as int,
          );
        },
        '/eleve/fiche': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return FicheEleveScreen(eleveId: args['eleveId'] as int);
        },
        '/directeur/affectations': (context) =>
            const GestionAffectationsScreen(),
        '/directeur/affectations/classe': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AffectationsClasseScreen(
            classeId: args['classeId'] as int,
            classeNom: args['classeNom'] as String,
          );
        },
        '/notes': (context) => const NotesModuleScreen(),
        '/notes/validation': (context) => const ValidationNotesScreen(),
        '/enseignant/notes': (context) => const SelectionSaisieScreen(),
        '/enseignant/absences': (context) => const SaisieAbsencesScreen(),
        '/emploi-du-temps': (context) => const EmploiDuTempsModuleScreen(),
        '/emploi-du-temps/parametrage': (context) => const ParametrageCreneauxScreen(),
        '/enseignant/presence': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ListePresenceScreen(
            classeId: args['classeId'] as int,
            classeNom: args['classeNom'] as String,
          );
        },
        '/paiements': (context) => const GestionPaiementsScreen(),
        '/paiements/renvoi': (context) => const ListeRenvoiScreen(),
        '/paiements/caisse': (context) => const GestionCaisseScreen(),
        '/paiements/rapports': (context) => const RapportsPaiementsScreen(),
        '/profil': (context) => const ProfilScreen(),
        '/statistiques': (context) => const StatistiquesModuleScreen(),
        '/bulletins': (context) => const BulletinsModuleScreen(),
        '/sync': (context) => const SyncScreen(),
        '/notifications': (context) => const NotificationsModuleScreen(),
        '/parametres': (context) => const ParametresModuleScreen(),
      },
      home: const LoginScreen(),
    );
  }
}
