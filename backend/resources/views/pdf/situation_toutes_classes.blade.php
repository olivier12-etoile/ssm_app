<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 25px; }
        body { font-family: 'DejaVu Sans', sans-serif; font-size: 12px; color: #222; }
        .entete { background-color: {{ $ecole['couleur_primaire'] }}; color: #fff; padding: 12px 16px; border-radius: 6px; }
        .entete h1 { margin: 0; font-size: 18px; }
        .entete p { margin: 2px 0 0 0; font-size: 11px; color: #f0f0f0; }
        .titre-section { margin-top: 18px; font-size: 14px; font-weight: bold; color: {{ $ecole['couleur_primaire'] }}; border-bottom: 2px solid {{ $ecole['couleur_primaire'] }}; padding-bottom: 4px; }
        .sous-titre { margin-top: 4px; font-size: 10px; color: #666; }
        table.donnees { width: 100%; border-collapse: collapse; margin-top: 8px; }
        table.donnees th { background-color: {{ $ecole['couleur_primaire'] }}; color: #fff; padding: 6px; font-size: 10px; text-align: left; }
        table.donnees td { padding: 6px; border-bottom: 1px solid #e0e0e0; font-size: 10px; vertical-align: middle; }
        table.donnees tr:nth-child(even) { background-color: #f7f7f7; }
        .footer { margin-top: 20px; font-size: 9px; color: #999; text-align: center; }
    </style>
</head>
<body>
    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}</p>
    </div>

    <div class="titre-section">SITUATION FINANCIÈRE — TOUTES LES CLASSES</div>
    <div class="sous-titre">Année scolaire {{ $annee }} — Généré le {{ $genere_le }}</div>

    <table class="donnees">
        <thead>
            <tr>
                <th>Classe</th>
                <th>Effectif</th>
                <th>En règle</th>
                <th>Partiel</th>
                <th>Non réglé</th>
                <th>En retard</th>
                <th>Attendu</th>
                <th>Encaissé</th>
                <th>Reste</th>
                <th>Taux</th>
            </tr>
        </thead>
        <tbody>
            @foreach($situations as $s)
            <tr>
                <td>{{ $s['classe_nom'] }}</td>
                <td>{{ $s['nombre_eleves'] }}</td>
                <td>{{ $s['nombre_en_regle'] }}</td>
                <td>{{ $s['nombre_partiel'] }}</td>
                <td>{{ $s['nombre_non_regle'] }}</td>
                <td>{{ $s['nombre_en_retard'] }}</td>
                <td>{{ number_format($s['montant_attendu'], 0, ',', ' ') }}</td>
                <td>{{ number_format($s['montant_encaisse'], 0, ',', ' ') }}</td>
                <td>{{ number_format($s['reste_a_recouvrer'], 0, ',', ' ') }}</td>
                <td>{{ $s['taux_recouvrement'] }}%</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">Généré le {{ $genere_le }} via Smart School Manager (SSM)</div>
</body>
</html>
