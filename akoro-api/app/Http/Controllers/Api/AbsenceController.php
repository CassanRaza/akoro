<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Seance;
use App\Services\AbsenceGenerator;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AbsenceController extends Controller
{
    private const RELATIONS = [
        'user:id,name,parcours_id,photo',
        'user.parcours:id,nom',
        'lecon:id,titre',
        'seance:id,heure_debut,heure_fin',
    ];

    // ---------- Côté admin ----------

    // Liste filtrable des absences de l'établissement + statistiques
    public function index(Request $request, AbsenceGenerator $generator)
    {
        $request->validate([
            'mois' => ['nullable', 'date_format:Y-m'],
            'statut' => ['nullable', Rule::in(Absence::STATUTS)],
            'parcours_id' => ['nullable', 'integer'],
            'search' => ['nullable', 'string', 'max:100'],
        ]);

        $etablissementId = $request->user()->etablissement_id;

        // Crée les absences des séances terminées avant d'afficher (sans dépendre du planificateur)
        $generator->generer($etablissementId);

        $base = Absence::query()
            ->whereHas('user', fn ($q) => $q->where('etablissement_id', $etablissementId));

        $this->appliquerFiltres($base, $request);

        $liste = (clone $base)
            ->when($request->query('statut'), fn ($q, $statut) => $q->where('statut', $statut))
            ->with(self::RELATIONS)
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->paginate(10);

        return [
            'stats' => $this->statistiques($base, $request, $etablissementId),
            'absences' => $liste,
        ];
    }

    // Valider, refuser ou rouvrir une justification
    public function update(Request $request, Absence $absence)
    {
        $this->authorizeAbsence($request, $absence);
        $this->nettoyerMotif($request);

        $validated = $request->validate([
            'statut' => ['required', Rule::in(['non_justifiee', 'justifiee', 'refusee'])],
            'motif' => ['nullable', 'string', 'min:3', 'max:255'],
        ], $this->messages());

        $motif = $validated['motif'] ?? $absence->motif;

        if ($validated['statut'] === 'justifiee' && ! $motif) {
            throw ValidationException::withMessages([
                'motif' => ['Un motif est nécessaire pour justifier une absence.'],
            ]);
        }

        $absence->update([
            'statut' => $validated['statut'],
            'motif' => $motif,
        ]);

        return $absence->load(self::RELATIONS);
    }

    // Annuler une absence (erreur de pointage, panne du lecteur...)
    public function destroy(Request $request, Absence $absence)
    {
        $this->authorizeAbsence($request, $absence);

        $absence->delete();

        return response()->json(['message' => 'Absence annulée.']);
    }

    // ---------- Côté bénéficiaire (mobile) ----------

    public function mesAbsences(Request $request, AbsenceGenerator $generator)
    {
        $generator->generer($request->user()->etablissement_id);

        return Absence::where('user_id', $request->user()->id)
            ->with(['lecon:id,titre', 'seance:id,heure_debut,heure_fin'])
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->get();
    }

    // Le bénéficiaire envoie un motif : l'absence passe à "à valider"
    public function justifier(Request $request, Absence $absence)
    {
        abort_unless($absence->user_id === $request->user()->id, 403, 'Cette absence ne vous concerne pas.');
        abort_unless(
            in_array($absence->statut, ['non_justifiee', 'refusee'], true),
            422,
            'Cette absence ne peut plus être modifiée.'
        );

        $this->nettoyerMotif($request);

        $validated = $request->validate([
            'motif' => ['bail', 'required', 'string', 'min:3', 'max:255'],
        ], $this->messages());

        $absence->update([
            'motif' => $validated['motif'],
            'statut' => 'a_valider',
        ]);

        return $absence->fresh()->load(['lecon:id,titre', 'seance:id,heure_debut,heure_fin']);
    }

    // ---------- Outils ----------

    private function appliquerFiltres($query, Request $request): void
    {
        if ($mois = $request->query('mois')) {
            [$debut, $fin] = $this->bornesDuMois($mois);
            $query->whereBetween('date', [$debut, $fin]);
        }

        if ($parcoursId = $request->query('parcours_id')) {
            $query->whereHas('user', fn ($q) => $q->where('parcours_id', $parcoursId));
        }

        if ($search = $request->query('search')) {
            $query->whereHas('user', function ($q) use ($search) {
                $q->where(function ($w) use ($search) {
                    $w->where('name', 'like', "%{$search}%")->orWhere('email', 'like', "%{$search}%");
                });
            });
        }
    }

    private function statistiques($base, Request $request, int $etablissementId): array
    {
        $total = (clone $base)->count();

        // Taux d'absentéisme = absences / bénéficiaires attendus aux séances traitées
        $seances = Seance::query()
            ->whereNotNull('absences_generees_le')
            ->whereHas('parcours', fn ($q) => $q->where('etablissement_id', $etablissementId));

        if ($mois = $request->query('mois')) {
            [$debut, $fin] = $this->bornesDuMois($mois);
            $seances->whereBetween('date', [$debut, $fin]);
        }

        if ($parcoursId = $request->query('parcours_id')) {
            $seances->where('parcours_id', $parcoursId);
        }

        $attendus = (int) $seances->sum('attendus');
        $taux = ($attendus > 0 && ! $request->query('search'))
            ? round($total / $attendus * 100, 1)
            : null;

        return [
            'total' => $total,
            'non_justifiees' => (clone $base)->where('statut', 'non_justifiee')->count(),
            'a_valider' => (clone $base)->where('statut', 'a_valider')->count(),
            'taux' => $taux,
        ];
    }

    private function bornesDuMois(string $mois): array
    {
        $debut = Carbon::createFromFormat('Y-m-d', $mois . '-01')->startOfMonth();

        return [$debut->toDateString(), $debut->copy()->endOfMonth()->toDateString()];
    }

    private function nettoyerMotif(Request $request): void
    {
        if (is_string($request->input('motif'))) {
            $request->merge(['motif' => preg_replace('/\s+/u', ' ', trim($request->input('motif')))]);
        }
    }

    private function authorizeAbsence(Request $request, Absence $absence): void
    {
        if ($absence->user->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Cette absence n'appartient pas à votre établissement.");
        }
    }

    private function messages(): array
    {
        return [
            'statut.required' => 'Le statut est obligatoire.',
            'statut.in' => 'Statut invalide.',
            'motif.required' => 'Le motif est obligatoire.',
            'motif.min' => 'Le motif est trop court (3 caractères minimum).',
            'motif.max' => 'Le motif est trop long (255 caractères maximum).',
        ];
    }
}