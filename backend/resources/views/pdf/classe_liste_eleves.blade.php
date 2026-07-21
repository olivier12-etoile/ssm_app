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
        .photo {
            width: 26px;
            height: 26px;
            border-radius: 50%;
        }
        .photo-vide {
            width: 26px;
            height: 26px;
            border-radius: 50%;
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #fff;
            text-align: center;
            font-size: 11px;
            font-weight: bold;
            line-height: 26px;
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

    <div class="titre-section">LISTE DES ÉLÈVES — {{ $classe->nom }}</div>
    <div class="sous-titre">
        Niveau : {{ $classe->niveau }}
        @if($classe->serie) &nbsp;|&nbsp; Série : {{ $classe->serie }} @endif
        @if($classe->annee) &nbsp;|&nbsp; Année : {{ $classe->annee->libelle }} @endif
        &nbsp;|&nbsp; Généré le {{ $genere_le }}
    </div>

    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 8%;">Photo</th>
                <th style="width: 16%;">Matricule</th>
                <th style="width: 40%;">Nom complet</th>
                <th style="width: 12%;">Sexe</th>
            </tr>
        </thead>
        <tbody>
            @foreach($eleves as $eleve)
            <tr>
                <td>
                    @if($eleve->photo_path)
                        <img class="photo" src="{{ public_path('storage/' . $eleve->photo_path) }}">
                    @else
                        <div class="photo-vide">{{ strtoupper(substr($eleve->nom, 0, 1)) }}</div>
                    @endif
                </td>
                <td>{{ $eleve->matricule }}</td>
                <td>{{ $eleve->nom }} {{ $eleve->prenom }}</td>
                <td>{{ $eleve->sexe }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">
        {{ count($eleves) }} élève(s) — Généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
