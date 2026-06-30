import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/changement_mdp_screen.dart';
import 'screens/dashboard/tableau_de_bord_screen.dart';
import 'screens/directeur/gestion_utilisateurs_screen.dart';
import 'screens/directeur/gestion_classes_screen.dart';
import 'screens/directeur/gestion_matieres_screen.dart';
import 'screens/directeur/gestion_annees_screen.dart';
import 'screens/directeur/gestion_eleves_screen.dart';
import 'screens/directeur/validation_notes_screen.dart';
import 'screens/enseignant/saisie_notes_screen.dart';
import 'screens/secretaire/gestion_paiements_screen.dart';
import 'screens/secretaire/liste_renvoi_screen.dart';
import 'screens/profil/profil_screen.dart';
import 'screens/statistiques/statistiques_screen.dart';
import 'screens/bulletins/bulletins_screen.dart';
import 'screens/sync/sync_screen.dart';
import 'screens/enseignant/saisie_absences_screen.dart';
import 'screens/notifications/notifications_attente_screen.dart';
import 'screens/enseignant/dashboard_enseignant_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routes: {
        '/login':                  (context) => const LoginScreen(),
        '/changer-mot-de-passe':   (context) => const ChangementMdpScreen(),
        '/tableau-de-bord':        (context) => const TableauDeBordScreen(),
        '/directeur/utilisateurs': (context) => const GestionUtilisateursScreen(),
        '/directeur/classes':      (context) => const GestionClassesScreen(),
        '/directeur/matieres':     (context) => const GestionMatieresScreen(),
        '/directeur/annees':       (context) => const GestionAnneesScreen(),
        '/directeur/eleves':       (context) => const GestionElevesScreen(),
        '/notes/validation':       (context) => const ValidationNotesScreen(),
        '/enseignant/notes':       (context) => const SaisieNotesScreen(),
        '/paiements':              (context) => const GestionPaiementsScreen(),
        '/paiements/renvoi':       (context) => const ListeRenvoiScreen(),
        '/profil':                 (context) => const ProfilScreen(),
        '/statistiques':           (context) => const StatistiquesScreen(),
        '/bulletins':              (context) => const BulletinsScreen(),
        '/sync':                   (context) => const SyncScreen(),
        '/enseignant/absences': (context) => const SaisieAbsencesScreen(),
        '/notifications': (context) => const NotificationsAttenteScreen(),
        '/test-dashboard-enseignant': (context) => const DashboardEnseignantScreen(),
      },
      home: const LoginScreen(),
    );
  }
}