<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 20px; }
        body {
            font-family: 'DejaVu Sans', sans-serif;
            font-size: 11px;
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
            margin-top: 16px;
            font-size: 14px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            border-bottom: 2px solid {{ $ecole['couleur_primaire'] }};
            padding-bottom: 4px;
        }
        table.edt {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        table.edt th {
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #fff;
            padding: 6px;
            font-size: 10px;
            text-align: center;
        }
        table.edt td {
            padding: 6px;
            border: 1px solid #e0e0e0;
            font-size: 10px;
            text-align: center;
            vertical-align: middle;
        }
        table.edt td.horaire {
            font-weight: bold;
            background-color: #f7f7f7;
            width: 12%;
        }
        table.edt td.recreation {
            background-color: #fff3cd;
            font-weight: bold;
            color: #856404;
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

    <div class="titre-section">
        EMPLOI DU TEMPS — {{ $classe_nom }} — {{ $annee_libelle }}
    </div>

    <table class="edt">
        <thead>
            <tr>
                <th>Horaire</th>
                @foreach($jours as $j)
                <th>{{ ucfirst($j) }}</th>
                @endforeach
            </tr>
        </thead>
        <tbody>
            @foreach($grille as $row)
                @if($row['recreation'])
                <tr>
                    <td class="recreation" colspan="{{ count($jours) + 1 }}">
                        RÉCRÉATION {{ $row['debut'] }} - {{ $row['fin'] }}
                    </td>
                </tr>
                @else
                <tr>
                    <td class="horaire">{{ $row['debut'] }} - {{ $row['fin'] }}</td>
                    @foreach($jours as $j)
                        @php $cellule = $tableau[$j][$row['debut']] ?? null; @endphp
                        <td>
                            @if($cellule)
                                <strong>{{ $cellule['matiere_nom'] }}</strong><br>
                                <span style="font-size:9px;">{{ $cellule['enseignant_nom'] }}</span>
                                @if($cellule['salle'])
                                    <br><span style="font-size:8px;color:#666;">{{ $cellule['salle'] }}</span>
                                @endif
                            @endif
                        </td>
                    @endforeach
                </tr>
                @endif
            @endforeach
        </tbody>
    </table>

    <div class="footer">
        Emploi du temps généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
