<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Résultats — {{ $devoir->titre }}</title>
    <style>
        body { font-family: DejaVu Sans, Arial, sans-serif; font-size: 13px; color: #111; margin: 24px; }
        h1 { font-size: 18px; margin-bottom: 4px; }
        .meta { color: #555; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ccc; padding: 8px 10px; text-align: left; }
        th { background: #f3f4f6; }
        tr:nth-child(even) { background: #fafafa; }
        .actions { margin-top: 24px; }
        @media print {
            .no-print { display: none; }
            body { margin: 0; }
        }
    </style>
</head>
<body>
    <h1>Résultats — {{ $devoir->titre }}</h1>
    <div class="meta">
        Type : {{ $devoir->type === 'qcm' ? 'QCM' : 'Rendu PDF' }}
        · Parcours : {{ $devoir->parcours?->nom ?? '—' }}
        · Généré le {{ now()->format('d/m/Y H:i') }}
    </div>

    <table>
        <thead>
            <tr>
                <th>Nom et prénom</th>
                <th>Note /20</th>
                @if($devoir->type === 'qcm')
                    <th>Score</th>
                    <th>%</th>
                @endif
                <th>Statut</th>
            </tr>
        </thead>
        <tbody>
            @forelse($resultats as $row)
                <tr>
                    <td>{{ $row['nom'] }}</td>
                    <td>{{ $row['note'] !== null ? $row['note'] : '—' }}</td>
                    @if($devoir->type === 'qcm')
                        <td>{{ $row['score'] }} / {{ $row['score_max'] }}</td>
                        <td>{{ $row['pourcentage'] !== null ? $row['pourcentage'].' %' : '—' }}</td>
                    @endif
                    <td>{{ $row['statut'] }}</td>
                </tr>
            @empty
                <tr><td colspan="5">Aucun résultat pour le moment.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="actions no-print">
        <button onclick="window.print()">Imprimer / Enregistrer en PDF</button>
    </div>

    <script>
        window.addEventListener('load', () => setTimeout(() => window.print(), 300));
    </script>
</body>
</html>