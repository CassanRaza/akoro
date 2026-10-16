<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Devoir;
use App\Models\Soumission;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Carbon;
use App\Services\QuestionGenerator;
use Illuminate\Support\Facades\DB;

class DevoirController extends Controller
{
    private const RELATIONS = [
        'parcours:id,nom',
        'lecon:id,titre',
        'lecons:id,titre',
        'createur:id,name',
    ];

    // ---------- Liste des devoirs (Admin) ----------
    public function index(Request $request)
    {
        $request->validate([
            'parcours_id' => ['nullable', 'integer'],
            'type'        => ['nullable', Rule::in(Devoir::TYPES)],
            'statut'      => ['nullable', Rule::in(Devoir::STATUTS)],
            'search'      => ['nullable', 'string', 'max:100'],
        ]);

        $etablissementId = $request->user()->etablissement_id;

        $query = Devoir::query()
            ->where('etablissement_id', $etablissementId)
            ->with(self::RELATIONS)
            ->withCount([
                'resultats as nb_resultats',
                'soumissions as nb_soumissions',
            ]);

        if ($parcoursId = $request->query('parcours_id')) {
            $query->where('parcours_id', $parcoursId);
        }

        if ($type = $request->query('type')) {
            $query->where('type', $type);
        }

        if ($statut = $request->query('statut')) {
            $query->where('statut', $statut);
        }

        if ($search = $request->query('search')) {
            $query->where('titre', 'like', "%{$search}%");
        }

        return $query->orderByDesc('created_at')->paginate(12);
    }

    // ---------- Détail d'un devoir ----------
    public function show(Request $request, Devoir $devoir)
    {
        $this->authorizeDevoir($request, $devoir);

        $devoir->load([
            'parcours:id,nom',
            'lecon:id,titre',
            'lecons:id,titre',
            'createur:id,name',
            'questions.choix',
            'resultats.user:id,name,photo',
            'soumissions.user:id,name,photo',
        ]);

        return $devoir;
    }

    // ---------- Création d'un devoir ----------
    public function store(Request $request)
    {
        $etablissementId = $request->user()->etablissement_id;

        $validated = $request->validate([
            'parcours_id'      => [
                'required',
                Rule::exists('parcours', 'id')->where('etablissement_id', $etablissementId),
            ],
            'lecon_ids'        => ['nullable', 'array'],
            'lecon_ids.*'      => [
                'integer',
                Rule::exists('lecons', 'id'),
            ],
            'type'             => ['required', Rule::in(Devoir::TYPES)],
            'titre'            => ['required', 'string', 'min:3', 'max:255'],
            'description'      => ['nullable', 'string', 'max:2000'],
            'date_debut'       => ['nullable', 'date', 'after_or_equal:now'],
            'duree_minutes'    => ['nullable', 'integer', 'min:5', 'max:180'],
            'date_limite'      => $request->input('type') === 'qcm'
                ? ['prohibited']
                : ['nullable', 'date', 'after:now'],
            'fichier_consigne' => ['nullable', 'file', 'mimes:pdf', 'max:10240'],
            'statut'           => ['nullable', Rule::in(Devoir::STATUTS)],
        ], $this->messages());

        // Vérifications selon le type
        if ($validated['type'] === 'qcm') {
            if (empty($validated['date_debut'])) {
                throw ValidationException::withMessages([
                    'date_debut' => ['La date et l’heure de début sont obligatoires pour un QCM programmé.'],
                ]);
            }
            if (empty($validated['duree_minutes'])) {
                throw ValidationException::withMessages([
                    'duree_minutes' => ['La durée est obligatoire pour un QCM.'],
                ]);
            }
            if (empty($validated['lecon_ids']) || count($validated['lecon_ids']) === 0) {
                throw ValidationException::withMessages([
                    'lecon_ids' => ['Sélectionnez au moins une leçon de référence pour le QCM.'],
                ]);
            }
        }

        if ($validated['type'] === 'rendu' && empty($validated['date_limite'])) {
            throw ValidationException::withMessages([
                'date_limite' => ['La date limite de rendu est obligatoire pour un devoir PDF.'],
            ]);
        }

        if ($validated['type'] === 'qcm') {
            $validated['date_limite'] = Carbon::parse($validated['date_debut'])
                ->addMinutes((int) $validated['duree_minutes']);
        }

        $cheminConsigne = null;
        if ($request->hasFile('fichier_consigne')) {
            $cheminConsigne = $request->file('fichier_consigne')
                ->store('devoirs/consignes', 'local');
        }

        $devoir = Devoir::create([
            'etablissement_id' => $etablissementId,
            'parcours_id'      => $validated['parcours_id'],
            'lecon_id'         => $validated['lecon_ids'][0] ?? null,
            'created_by'       => $request->user()->id,
            'type'             => $validated['type'],
            'titre'            => $validated['titre'],
            'description'      => $validated['description'] ?? null,
            'date_debut'       => $validated['date_debut'] ?? null,
            'duree_minutes'    => $validated['duree_minutes'] ?? null,
            'date_limite'      => $validated['date_limite'] ?? null,
            'fichier_consigne' => $cheminConsigne,
            'statut'           => $validated['statut'] ?? 'brouillon',
        ]);

        // Lier les leçons de référence (pour l'IA)
        if (! empty($validated['lecon_ids'])) {
            $devoir->lecons()->sync($validated['lecon_ids']);
        }

        return response()->json(
            $devoir->load([...self::RELATIONS, 'lecons:id,titre']),
            201
        );
    }

    // ---------- Mise à jour d'un devoir ----------
    public function update(Request $request, Devoir $devoir)
    {
        $this->authorizeDevoir($request, $devoir);

        $validated = $request->validate([
            'titre'            => ['sometimes', 'string', 'min:3', 'max:255'],
            'description'      => ['nullable', 'string', 'max:2000'],
            'date_debut'       => $devoir->type === 'qcm'
                ? ['sometimes', 'required', 'date']
                : ['nullable', 'date'],
            'duree_minutes'    => $devoir->type === 'qcm'
                ? ['sometimes', 'required', 'integer', 'min:5', 'max:180']
                : ['nullable', 'integer', 'min:5', 'max:180'],
            'date_limite'      => $devoir->type === 'qcm'
                ? ['prohibited']
                : ['sometimes', 'required', 'date'],
            'statut'           => ['sometimes', Rule::in(Devoir::STATUTS)],
            'lecon_ids'        => ['nullable', 'array'],
            'lecon_ids.*'      => ['integer', Rule::exists('lecons', 'id')],
            'fichier_consigne' => ['nullable', 'file', 'mimes:pdf', 'max:10240'],
        ], $this->messages());

        if ($devoir->type === 'qcm') {
            $dateDebut = $validated['date_debut'] ?? $devoir->date_debut;
            $dureeMinutes = $validated['duree_minutes'] ?? $devoir->duree_minutes;
            if (! $dateDebut || ! $dureeMinutes) {
                throw ValidationException::withMessages([
                    'date_debut' => ['La date de début et la durée sont obligatoires pour calculer la fin du QCM.'],
                ]);
            }
            $validated['date_limite'] = Carbon::parse($dateDebut)->addMinutes((int) $dureeMinutes);
        }

        if ($request->hasFile('fichier_consigne')) {
            if ($devoir->fichier_consigne) {
                Storage::disk('local')->delete($devoir->fichier_consigne);
            }
            $validated['fichier_consigne'] = $request->file('fichier_consigne')
                ->store('devoirs/consignes', 'local');
        }

        // Mettre à jour lecon_id principal si de nouvelles leçons sont envoyées
        if (array_key_exists('lecon_ids', $validated) && ! empty($validated['lecon_ids'])) {
            $validated['lecon_id'] = $validated['lecon_ids'][0];
            $devoir->lecons()->sync($validated['lecon_ids']);
            unset($validated['lecon_ids']);
        }

        $devoir->update($validated);

        return $devoir->load([...self::RELATIONS, 'lecons:id,titre']);
    }

    // ---------- Suppression ----------
    public function destroy(Request $request, Devoir $devoir)
    {
        $this->authorizeDevoir($request, $devoir);

        if ($devoir->fichier_consigne) {
            Storage::disk('local')->delete($devoir->fichier_consigne);
        }

        $devoir->delete();

        return response()->json(['message' => 'Devoir supprimé.']);
    }

    // ---------- Ajouter des questions à un QCM ----------
    public function storeQuestions(Request $request, Devoir $devoir)
    {
        $this->authorizeDevoir($request, $devoir);

        abort_unless($devoir->type === 'qcm', 422, 'Seuls les devoirs de type QCM peuvent avoir des questions.');

        $validated = $request->validate([
            'questions'                       => ['required', 'array', 'min:5', 'max:20'],
            'questions.*.enonce'              => ['required', 'string', 'min:5'],
            'questions.*.points'              => ['nullable', 'integer', 'min:1', 'max:20'],
            'questions.*.choix'               => ['required', 'array', 'size:3'],
            'questions.*.choix.*'             => ['required', 'array'],
            'questions.*.choix.*.texte'       => ['required', 'string', 'min:1'],
            'questions.*.choix.*.est_correct' => ['required', 'boolean'],
        ]);

        foreach ($validated['questions'] as $index => $questionData) {
            $correctAnswers = count(array_filter(
                $questionData['choix'],
                static fn (array $choice) => filter_var(
                    $choice['est_correct'],
                    FILTER_VALIDATE_BOOLEAN
                )
            ));
            if ($correctAnswers !== 1) {
                throw ValidationException::withMessages([
                    "questions.{$index}.choix" => [
                        'Chaque question doit avoir exactement une bonne réponse.',
                    ],
                ]);
            }
        }

        DB::transaction(function () use ($devoir, $validated): void {
            $nextOrder = ((int) $devoir->questions()->max('ordre')) + 1;

            foreach ($validated['questions'] as $qData) {
                $question = $devoir->questions()->create([
                    'enonce' => $qData['enonce'],
                    'ordre'  => $nextOrder++,
                    'points' => $qData['points'] ?? 1,
                ]);

                foreach ($qData['choix'] as $cIndex => $cData) {
                    $question->choix()->create([
                        'texte'       => $cData['texte'],
                        'est_correct' => filter_var($cData['est_correct'], FILTER_VALIDATE_BOOLEAN),
                        'ordre'       => $cIndex + 1,
                    ]);
                }
            }
        });

        return $devoir->load('questions.choix');
    }

    // ---------- Correction manuelle d'une soumission (type rendu) ----------
    public function corrigerSoumission(Request $request, Soumission $soumission)
    {
        $this->authorizeDevoir($request, $soumission->devoir);

        $validated = $request->validate([
            'note'        => ['required', 'numeric', 'min:0', 'max:20'],
            'commentaire' => ['nullable', 'string', 'max:1000'],
        ]);

        $soumission->update([
            'note'        => $validated['note'],
            'commentaire' => $validated['commentaire'] ?? null,
            'statut'      => 'corrige',
        ]);

        return $soumission->load('user:id,name,photo');
    }

    // ---------- Helpers ----------
    private function authorizeDevoir(Request $request, Devoir $devoir): void
    {
        if ($devoir->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Ce devoir n'appartient pas à votre établissement.");
        }
    }

    private function messages(): array
    {
        return [
            'parcours_id.required'      => 'Le parcours est obligatoire.',
            'type.required'             => 'Le type de devoir est obligatoire.',
            'type.in'                   => 'Type invalide (qcm ou rendu).',
            'titre.required'            => 'Le titre est obligatoire.',
            'titre.min'                 => 'Le titre est trop court.',
            'date_debut.after_or_equal' => 'La date de début doit être dans le futur.',
            'date_limite.after'         => 'La date limite doit être dans le futur.',
            'fichier_consigne.mimes'    => 'Le fichier doit être un PDF.',
            'fichier_consigne.max'      => 'Le fichier ne doit pas dépasser 10 Mo.',
            'lecon_ids.required'        => 'Sélectionnez au moins une leçon de référence.',
        ];
    }
        // ---------- Génération automatique par IA ----------
public function genererQuestions(Request $request, Devoir $devoir, QuestionGenerator $generator)
{
    $this->authorizeDevoir($request, $devoir);

    abort_unless($devoir->type === 'qcm', 422, 'La génération IA est réservée aux devoirs de type QCM.');

    $validated = $request->validate([
        'nombre' => ['nullable', 'integer', 'min:1', 'max:20'],
    ]);

    $nombre = $validated['nombre'] ?? 5;

    try {
        $questions = $generator->generer($devoir, $nombre);
    } catch (\Throwable $e) {
        throw ValidationException::withMessages([
            'ia' => [$e->getMessage()],
        ]);
    }

    // Enregistrer le lot de questions sans laisser de création partielle.
    DB::transaction(function () use ($devoir, $questions): void {
        $nextOrder = ((int) $devoir->questions()->max('ordre')) + 1;

        foreach ($questions as $qData) {
            $question = $devoir->questions()->create([
                'enonce' => $qData['enonce'],
                'ordre'  => $nextOrder++,
                'points' => $qData['points'] ?? 1,
            ]);

            foreach (array_slice($qData['choix'], 0, 3) as $cIndex => $cData) {
                $question->choix()->create([
                    'texte'       => $cData['texte'],
                    'est_correct' => (bool) $cData['est_correct'],
                    'ordre'       => $cIndex + 1,
                ]);
            }
        }
    });

    return $devoir->load('questions.choix')->setAttribute(
        'generation_source',
        $generator->generationSource()
    );
}
}