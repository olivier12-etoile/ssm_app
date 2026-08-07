<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 25px; }
        body {
            font-family: 'DejaVu Sans', sans-serif;
            font-size: 12px;
            color: #222;
        }
        .entete {
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #ffffff;
            padding: 12px 16px;
            border-radius: 6px;
        }
        .entete h1 {
            margin: 0;
            font-size: 18px;
        }
        .entete p {
            margin: 2px 0 0 0;
            font-size: 11px;
            color: #f0f0f0;
        }
        .titre-section {
            margin-top: 18px;
            font-size: 14px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            border-bottom: 2px solid {{ $ecole['couleur_primaire'] }};
            padding-bottom: 4px;
        }
        .sous-titre {
            margin-top: 4px;
            font-size: 10px;
            color: #666;
        }
        table.donnees {
            width: 100%;
            border-collapse: collapse;
            margin-top: 8px;
        }
        table.donnees th {
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #fff;
            padding: 6px;
            font-size: 11px;
            text-align: left;
        }
        table.donnees td {
            padding: 6px;
            border-bottom: 1px solid #e0e0e0;
            font-size: 11px;
            vertical-align: middle;
        }
        table.donnees tr:nth-child(even) {
            background-color: #f7f7f7;
        }
        .footer {
            margin-top: 20px;
            font-size: 9px;
            color: #999;
            text-align: center;
        }
    </style>
</head>
<body>

    <div class="entete">
        <h1>{{ $ecole['nom'] }}</h1>
        <p>Code école : {{ $ecole['code_ecole'] }}</p>
    </div>

    <div class="titre-section">CLASSEMENT — {{ $classement['classe_nom'] }}</div>
    <div class="sous-titre">
        Période : {{ $classement['periode_nom'] }}
        &nbsp;|&nbsp; Moyenne de classe : {{ $classement['moyenne_classe'] ?? '—' }}/20
        &nbsp;|&nbsp; Généré le {{ $genere_le }}
    </div>

    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 8%;">Rang</th>
                <th style="width: 45%;">Nom complet</th>
                <th style="width: 17%;">Moyenne</th>
                <th style="width: 30%;">Mention</th>
            </tr>
        </thead>
        <tbody>
            @foreach($classement['eleves'] as $e)
            <tr>
                <td>{{ $e['rang'] ?? '—' }}</td>
                <td>{{ $e['nom'] }} {{ $e['prenom'] }}</td>
                <td>{{ $e['moyenne'] !== null ? $e['moyenne'] . '/20' : '—' }}</td>
                <td>{{ $e['mention'] ?? '—' }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">
        {{ count($classement['eleves']) }} élève(s) — Généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
