import 'package:flutter/material.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import 'menu_lateral.dart';

class TableauDeBordScreen extends StatefulWidget {
  const TableauDeBordScreen({super.key});

  @override
  State<TableauDeBordScreen> createState() => _TableauDeBordScreenState();
}

class _TableauDeBordScreenState extends State<TableauDeBordScreen> {
  Utilisateur? _utilisateur;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateur();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await AuthService.getUtilisateur();

    // Rediriger si mot de passe pas encore changé
    if (u != null && !u.motDePasseChange && mounted) {
      Navigator.pushReplacementNamed(context, '/changer-mot-de-passe');
      return;
    }

    setState(() => _utilisateur = u);
  }

  @override
  Widget build(BuildContext context) {
    if (_utilisateur == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        backgroundColor: Color(
          int.parse(
            _utilisateur!.couleurPrimaire.replaceAll('#', '0xFF'),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      drawer: MenuLateral(utilisateur: _utilisateur!),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${_utilisateur!.nom} 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rôle : ${_utilisateur!.role}  •  Code école : ${_utilisateur!.codeEcole}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Cartes rapides selon le rôle
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: _cartesRapides(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cartesRapides() {
    final cartes = <Widget>[];

    if (_utilisateur!.estDirecteur) {
      cartes.addAll([
        _carte(Icons.people, 'Utilisateurs', '/directeur/utilisateurs', Colors.blue),
        _carte(Icons.class_, 'Classes', '/directeur/classes', Colors.green),
        _carte(Icons.book, 'Matières', '/directeur/matieres', Colors.purple),
        _carte(Icons.grade, 'Validation Notes', '/notes/validation', Colors.orange),
      ]);
    }

    if (_utilisateur!.estCenseur) {
      cartes.addAll([
        _carte(Icons.grade, 'Validation Notes', '/notes/validation', Colors.orange),
      ]);
    }

    if (_utilisateur!.estSecretaire) {
      cartes.addAll([
        _carte(Icons.payment, 'Paiements', '/paiements', Colors.teal),
      ]);
    }

    if (_utilisateur!.estEnseignant) {
      cartes.addAll([
        _carte(Icons.edit_note, 'Saisie Notes', '/enseignant/notes', Colors.indigo),
        _carte(Icons.calendar_month, 'Années & Périodes', '/directeur/annees', Colors.teal),
        _carte(Icons.people, 'Élèves', '/directeur/eleves', Colors.deepOrange),
        // Pour le Directeur
_carte(Icons.edit_note, 'Saisie Notes', '/enseignant/notes', Colors.indigo),
      ]);
    }

    return cartes;
  }

  Widget _carte(IconData icone, String titre, String route, Color couleur) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 48, color: couleur),
            const SizedBox(height: 8),
            Text(
              titre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}