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
        .titre-rapport {
            margin-top: 16px;
            font-size: 16px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
        }
        .sous-titre {
            margin-top: 2px;
            font-size: 10px;
            color: #666;
        }
        .titre-section {
            margin-top: 18px;
            font-size: 13px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            border-bottom: 2px solid {{ $ecole['couleur_primaire'] }};
            padding-bottom: 4px;
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

    <div class="titre-rapport">{{ $titre }}</div>
    <div class="sous-titre">
        {{ $sousTitre }}
        &nbsp;|&nbsp; Généré le {{ $genere_le }}
    </div>

    @foreach($sections as $section)
        <div class="titre-section">{{ $section['titre'] }}</div>
        <table class="donnees">
            <thead>
                <tr>
                    @foreach($section['colonnes'] as $colonne)
                        <th>{{ $colonne }}</th>
                    @endforeach
                </tr>
            </thead>
            <tbody>
                @forelse($section['lignes'] as $ligne)
                    <tr>
                        @foreach($ligne as $valeur)
                            <td>{{ $valeur ?? '—' }}</td>
                        @endforeach
                    </tr>
                @empty
                    <tr>
                        <td colspan="{{ count($section['colonnes']) }}">Aucune donnée.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    @endforeach

    <div class="footer">
        Généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
