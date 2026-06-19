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
        .infos {
            width: 100%;
            margin-top: 14px;
            border-collapse: collapse;
        }
        .infos td {
            padding: 4px 6px;
            font-size: 12px;
        }
        .infos td.label {
            color: #666;
            width: 110px;
        }
        .titre-section {
            margin-top: 18px;
            font-size: 14px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
            border-bottom: 2px solid {{ $ecole['couleur_primaire'] }};
            padding-bottom: 4px;
        }
        table.notes {
            width: 100%;
            border-collapse: collapse;
            margin-top: 8px;
        }
        table.notes th {
            background-color: {{ $ecole['couleur_primaire'] }};
            color: #fff;
            padding: 6px;
            font-size: 11px;
            text-align: left;
        }
        table.notes td {
            padding: 6px;
            border-bottom: 1px solid #e0e0e0;
            font-size: 11px;
        }
        table.notes tr:nth-child(even) {
            background-color: #f7f7f7;
        }
        .moyenne-box {
            margin-top: 16px;
            padding: 12px 16px;
            background-color: #f0f0f0;
            border-left: 6px solid {{ $ecole['couleur_primaire'] }};
            border-radius: 4px;
        }
        .moyenne-box .moyenne {
            font-size: 20px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
        }
        .signature {
            margin-top: 40px;
            width: 100%;
        }
        .signature td {
            width: 50%;
            text-align: center;
            font-size: 11px;
            padding-top: 30px;
            border-top: 1px solid #999;
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
        <p>Code école : {{ $ecole['code_ecole'] }}
            @if(!empty($ecole['telephone'])) &nbsp;|&nbsp; Tél : {{ $ecole['telephone'] }} @endif
            @if(!empty($ecole['adresse'])) &nbsp;|&nbsp; {{ $ecole['adresse'] }} @endif
        </p>
    </div>

    <table class="infos">
        <tr>
            <td class="label">Élève</td>
            <td><strong>{{ $eleve['nom'] }} {{ $eleve['prenom'] }}</strong></td>
            <td class="label">Matricule</td>
            <td>{{ $eleve['matricule'] }}</td>
        </tr>
        <tr>
            <td class="label">Classe</td>
            <td>{{ $classe }}</td>
            <td class="label">Sexe</td>
            <td>{{ $eleve['sexe'] === 'M' ? 'Masculin' : 'Féminin' }}</td>
        </tr>
        <tr>
            <td class="label">Période</td>
            <td>{{ $periode['nom'] }}</td>
            <td class="label">Année</td>
            <td>{{ $annee }}</td>
        </tr>
    </table>

    <div class="titre-section">BULLETIN DE NOTES</div>

    <table class="notes">
        <thead>
            <tr>
                <th style="width: 40%;">Matière</th>
                <th style="width: 15%;">Coefficient</th>
                <th style="width: 15%;">Note /20</th>
                <th style="width: 15%;">Points</th>
                <th style="width: 15%;">Mention</th>
            </tr>
        </thead>
        <tbody>
            @foreach($notes as $note)
            <tr>
                <td>{{ $note['matiere'] }}</td>
                <td>{{ $note['coefficient'] }}</td>
                <td><strong>{{ $note['note'] }}</strong></td>
                <td>{{ $note['points'] }}</td>
                <td>{{ $note['mention'] }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="moyenne-box">
        <table style="width:100%;">
            <tr>
                <td>
                    <strong>Moyenne Générale</strong><br>
                    <span style="font-size:11px; color:#666;">{{ $total_matieres }} matière(s) évaluée(s)</span>
                </td>
                <td style="text-align:right;">
                    <span class="moyenne">{{ $moyenne_generale }}/20</span><br>
                    <span style="color:{{ $ecole['couleur_primaire'] }}; font-weight:bold;">{{ $mention_generale }}</span>
                </td>
            </tr>
        </table>
    </div>

    @if(!empty($appreciation))
    <div class="titre-section" style="margin-top:16px;">APPRÉCIATION</div>
    <p>{{ $appreciation }}</p>
    @endif

    <table class="signature">
        <tr>
            <td>Le Professeur Principal</td>
            <td>Le Directeur</td>
        </tr>
    </table>

    <div class="footer">
        Bulletin généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>