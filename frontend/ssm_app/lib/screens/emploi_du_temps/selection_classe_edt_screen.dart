import 'package:flutter/material.dart';
import '../../services/classe_service.dart';

class SelectionClasseEdtScreen extends StatefulWidget {
  const SelectionClasseEdtScreen({super.key});

  @override
  State<SelectionClasseEdtScreen> createState() =>
      _SelectionClasseEdtScreenState();
}

class _SelectionClasseEdtScreenState extends State<SelectionClasseEdtScreen> {
  List<dynamic> _classes = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerClasses();
  }

  Future<void> _chargerClasses() async {
    try {
      final liste = await ClasseService.listerClasses();
      setState(() {
        _classes = liste;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emplois du temps'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerClasses,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? const Center(
                  child: Text('Aucune classe pour l\'instant',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final classe = _classes[index];
                    final classeId = classe['id'] as int;
                    final classeNom = classe['nom'] as String;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/emploi-du-temps/classe',
                          arguments: {
                            'classeId': classeId,
                            'classeNom': classeNom,
                          },
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text(
                            classe['niveau'].toString().substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          classeNom,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Niveau : ${classe['niveau']}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}
