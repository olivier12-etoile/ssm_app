import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

class SSMDataColumn {
  final String label;
  final double? largeur;

  const SSMDataColumn(this.label, {this.largeur});
}

// ══════════════════════════════════════════════════════════
// SSMDataTable — Tableau propre : en-tête gris uppercase,
// lignes avec surbrillance au survol, cellules espacées
// ══════════════════════════════════════════════════════════
class SSMDataTable extends StatelessWidget {
  final List<SSMDataColumn> colonnes;
  final List<List<Widget>> lignes;
  final ValueChanged<int>? onLigneTap;

  const SSMDataTable({
    super.key,
    required this.colonnes,
    required this.lignes,
    this.onLigneTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 46,
        horizontalMargin: 13,
        columnSpacing: 24,
        dividerThickness: 1,
        headingRowColor: WidgetStateProperty.all(Colors.transparent),
        dataTextStyle: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
        columns: [
          for (final colonne in colonnes)
            DataColumn(
              label: SizedBox(
                width: colonne.largeur,
                child: Text(
                  colonne.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: SSMPalette.texte3,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
        rows: [
          for (int i = 0; i < lignes.length; i++)
            DataRow(
              color: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered)
                    ? const Color(0xFFFAFCFF)
                    : Colors.transparent,
              ),
              onSelectChanged: onLigneTap != null ? (_) => onLigneTap!(i) : null,
              cells: [for (final cellule in lignes[i]) DataCell(cellule)],
            ),
        ],
      ),
    );
  }
}
