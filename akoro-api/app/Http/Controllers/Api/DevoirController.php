<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Devoir;
use App\Models\Parcours;
use App\Models\Question;
use App\Models\Choix;
use App\Models\Soumission;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DevoirController extends Controller
{
    private const RELATIONS = [
        'parcours:id,nom',
        'lecon:id,titre',
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

        $devoirs = $query->orderByDesc('created_at')->paginate(12);

        return $devoirs;
    }

    // ---------- Détail d'un devoir ----------
    public function show(Request $request, Devoir $devoir)
    {
        $this->authorizeDevoir($request, $devoir);

        $devoir->load([
            'parcours:id,nom',
            'lecon:id,titre',
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
            'parcours_id'     => [
                'required',
                Rule::exists('parcours', 'id')->where('etablissement_id', $etablissementId),
            ],
            'lecon_id'        => [
                'nullable',
                Rule::exists('lecons', 'id'),
            ],
            'type'            => ['required', Rule::in(Devoir::TYPES)],
            'titre'           => ['required', 'string', 'min:3', 'max:255'],
            'description'     => ['nullable', 'string', 'max:2000'],
            'date_debut'      => ['nullable', 'date', 'after_or_equal:now'],
            'duree_minutes'   => ['nullable', 'integer', 'min:5', 'max:180'],
            'date_limite'     => ['nullable', 'date', 'after:now'],
            'fichier_consigne'=> ['nullable', 'file', 'mimes:pdf', 'max:10240'], // 10 Mo
            'statut'          => ['nullable', Rule::in(Devoir::STATUTS)],
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
        }

        if ($validated['type'] === 'rendu' && empty($validated['date_limite'])) {
            throw ValidationException::withMessages([
                'date_limite' => ['La date limite de rendu est obligatoire pour un devoir PDF.'],
            ]);
        }

        $cheminConsigne = null;
        if ($request->hasFile('fichier_consigne')) {
            $cheminConsigne = $request->file('fichier_consigne')
                ->store('devoirs/consignes', 'local');
        }

        $devoir = Devoir::create([
            ...$validated,
            'etablissement_id' => $etablissementId,
            'created_by'       => $request->user()->id,
            'fichier_consigne' => $cheminConsigne,
            'statut'           => $validated['statut'] ?? 'brouillon',
        ]);

        return response()->json($devoir->load(self::RELATIONS), 201);
    }

    // ---------- Mise à jour d'un devoir ----------
    public function update(Request $request, Devoir $devoir)
    {
        $this->authorizeDevoir($request, $devoir);

        $validated = $request->validate([
            'titre'           => ['sometimes', 'string', 'min:3', 'max:255'],
            'description'     => ['nullable', 'string', 'max:2000'],
            'date_debut'      => ['nullable', 'date'],
            'duree_minutes'   => ['nullable', 'integer', 'min:5', 'max:180'],
            'date_limite'     => ['nullable', 'date'],
            'statut'          => ['sometimes', Rule::in(Devoir::STATUTS)],
            'fichier_consigne'=> ['nullable', 'file', 'mimes:pdf', 'max:10240'],
        ], $this->messages());

        if ($request->hasFile('fichier_consigne')) {
            if ($devoir->fichier_consigne) {
                Storage::disk('local')->delete($devoir->fichier_consigne);
            }
            $validated['fichier_consigne'] = $request->file('fichier_consigne')
                ->store('devoirs/consignes', 'local');
        }

        $devoir->update($validated);

        return $devoir->load(self::RELATIONS);
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
            'questions'                 => ['required', 'array', 'min:1'],
            'questions.*.enonce'        => ['required', 'string', 'min:5'],
            'questions.*.points'        => ['nullable', 'integer', 'min:1', 'max:20'],
            'questions.*.choix'         => ['required', 'array', 'min:2'],
            'questions.*.choix.*.texte' => ['required', 'string', 'min:1'],
            'questions.*.choix.*.est_correct' => ['required', 'boolean'],
        ]);

        foreach ($validated['questions'] as $index => $qData) {
            $question = $devoir->questions()->create([
                'enonce' => $qData['enonce'],
                'ordre'  => $index + 1,
                'points' => $qData['points'] ?? 1,
            ]);

            foreach ($qData['choix'] as $cIndex => $cData) {
                $question->choix()->create([
                    'texte'       => $cData['texte'],
                    'est_correct' => $cData['est_correct'],
                    'ordre'       => $cIndex + 1,
                ]);
            }
        }

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
            'parcours_id.required'   => 'Le parcours est obligatoire.',
            'type.required'          => 'Le type de devoir est obligatoire.',
            'type.in'                => 'Type invalide (qcm ou rendu).',
            'titre.required'         => 'Le titre est obligatoire.',
            'titre.min'              => 'Le titre est trop court.',
            'date_debut.after_or_equal' => 'La date de début doit être dans le futur.',
            'date_limite.after'      => 'La date limite doit être dans le futur.',
            'fichier_consigne.mimes' => 'Le fichier doit être un PDF.',
            'fichier_consigne.max'   => 'Le fichier ne doit pas dépasser 10 Mo.',
        ];
    }
}