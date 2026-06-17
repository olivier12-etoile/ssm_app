import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/changement_mdp_screen.dart';
import 'screens/dashboard/tableau_de_bord_screen.dart';
import 'screens/directeur/gestion_utilisateurs_screen.dart';
import 'screens/directeur/gestion_classes_screen.dart';
import 'screens/directeur/gestion_matieres_screen.dart';
import 'screens/directeur/gestion_annees_screen.dart';
import 'screens/directeur/gestion_eleves_screen.dart';

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
      },
      home: const LoginScreen(),
    );
  }
}