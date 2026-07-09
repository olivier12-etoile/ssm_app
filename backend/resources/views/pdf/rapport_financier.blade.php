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
        }
        table.donnees tr:nth-child(even) {
            background-color: #f7f7f7;
        }
        .resume-box {
            margin-top: 16px;
            padding: 12px 16px;
            background-color: #f0f0f0;
            border-left: 6px solid {{ $ecole['couleur_primaire'] }};
            border-radius: 4px;
        }
        .resume-box .valeur {
            font-size: 16px;
            font-weight: bold;
            color: {{ $ecole['couleur_primaire'] }};
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

    <div class="titre-section">
        RAPPORT FINANCIER — {{ $annee_libelle }}{{ $mois ? ' — Mois ' . $mois : '' }}
    </div>

    <div class="resume-box">
        <table style="width:100%;">
            <tr>
                <td>
                    <strong>Total attendu</strong><br>
                    <span class="valeur">{{ number_format($total_global['total_attendu'], 0, ',', ' ') }} FCFA</span>
                </td>
                <td>
                    <strong>Total encaissé</strong><br>
                    <span class="valeur">{{ number_format($total_global['total_encaisse'], 0, ',', ' ') }} FCFA</span>
                </td>
                <td>
                    <strong>Total restant</strong><br>
                    <span class="valeur">{{ number_format($total_global['total_restant'], 0, ',', ' ') }} FCFA</span>
                </td>
            </tr>
        </table>
    </div>

    <div class="titre-section">Détail par classe</div>
    <table class="donnees">
        <thead>
            <tr>
                <th style="width: 26%;">Classe</th>
                <th style="width: 12%;">Nb élèves</th>
                <th style="width: 18%;">Attendu</th>
                <th style="width: 18%;">Encaissé</th>
                <th style="width: 14%;">Restant</th>
                <th style="width: 12%;">%</th>
            </tr>
        </thead>
        <tbody>
            @foreach($par_classe as $c)
            <tr>
                <td>{{ $c['classe_nom'] }}</td>
                <td>{{ $c['nombre_eleves'] }}</td>
                <td>{{ number_format($c['total_attendu'], 0, ',', ' ') }}</td>
                <td>{{ number_format($c['total_encaisse'], 0, ',', ' ') }}</td>
                <td>{{ number_format($c['total_restant'], 0, ',', ' ') }}</td>
                <td>{{ $c['total_attendu'] > 0 ? round($c['total_encaisse'] / $c['total_attendu'] * 100) : 0 }}%</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <div class="titre-section">Débiteurs</div>
    @if(count($debiteurs) === 0)
        <p>Aucun débiteur — tous les élèves sont à jour.</p>
    @else
        <table class="donnees">
            <thead>
                <tr>
                    <th style="width: 30%;">Élève</th>
                    <th style="width: 20%;">Classe</th>
                    <th style="width: 17%;">Dû</th>
                    <th style="width: 17%;">Payé</th>
                    <th style="width: 16%;">Restant</th>
                </tr>
            </thead>
            <tbody>
                @foreach($debiteurs as $d)
                <tr>
                    <td>{{ $d['nom'] }} {{ $d['prenom'] }}</td>
                    <td>{{ $d['classe_nom'] }}</td>
                    <td>{{ number_format($d['montant_du'], 0, ',', ' ') }}</td>
                    <td>{{ number_format($d['montant_paye'], 0, ',', ' ') }}</td>
                    <td>{{ number_format($d['montant_restant'], 0, ',', ' ') }} FCFA</td>
                </tr>
                @endforeach
            </tbody>
        </table>
    @endif

    <div class="footer">
        Rapport généré le {{ $genere_le }} via Smart School Manager (SSM)
    </div>

</body>
</html>
