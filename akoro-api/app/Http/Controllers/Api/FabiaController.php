<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ConnaissanceAssistant;
use App\Models\FabiaEchange;
use App\Services\FabiaAssistant;
use App\Support\Roles;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class FabiaController extends Controller
{
    // Suggestions rapides affichées à l'ouverture de FAB'IA (comme sur la maquette)
    private const SUGGESTIONS = [
        'beneficiaire' => [
            'Mon parcours',
            'Équipements disponibles',
            'Quels sont mes prochaines séances ?',
            'Comment justifier une absence ?',
            'C’est quoi le FabLab Hay Tao ?',
        ],
        'admin' => [
            'Présente le FabLab en quelques lignes',
            'Équipements disponibles',
            'Rédige un message pour annoncer une séance',
            'Quelles informations restent à compléter ?',
            'Comment fonctionne le pointage par QR code ?',
        ],
    ];

    public function __construct(private FabiaAssistant $fabia)
    {
    }

    // ---------- Conversation avec FAB'IA ----------

    public function historique(Request $request)
    {
        $user = $request->user();

        return [
            'echanges' => FabiaEchange::where('user_id', $user->id)
                ->where('masque', false)
                ->latest()
                ->limit(40)
                ->get(['id', 'question', 'reponse', 'source', 'created_at'])
                ->reverse()
                ->values(),
            'suggestions' => self::SUGGESTIONS[$user->role === Roles::BENEFICIAIRE ? 'beneficiaire' : 'admin'],
        ];
    }

    public function poser(Request $request)
    {
        $validated = $request->validate([
            'question' => ['required', 'string', 'min:2', 'max:2000'],
        ], [
            'question.required' => 'Écrivez votre question.',
            'question.max' => 'La question est trop longue (2000 caractères maximum).',
        ]);

        $user = $request->user();
        $question = trim(strip_tags($validated['question']));
        $resultat = $this->fabia->repondre($user, $question);

        $echange = FabiaEchange::create([
            'user_id' => $user->id,
            'etablissement_id' => $user->etablissement_id,
            'question' => $question,
            'reponse' => $resultat['reponse'],
            'categorie' => $resultat['categorie'],
            'source' => $resultat['source'],
            'langue' => $resultat['langue'],
        ]);

        return $echange->only(['id', 'question', 'reponse', 'source', 'created_at']);
    }

    // « Nouvelle discussion » : l'historique est masqué pour l'utilisateur, conservé pour les statistiques
    public function effacer(Request $request)
    {
        FabiaEchange::where('user_id', $request->user()->id)->update(['masque' => true]);

        return response()->noContent();
    }

    // ---------- Statistiques (tableau de bord) ----------

    public static function statistiques(int $etabId, string $debut): array
    {
        $base = FabiaEchange::where('etablissement_id', $etabId);

        // Questions fréquentes : regroupées sur le texte normalisé
        $frequentes = (clone $base)
            ->where('created_at', '>=', now()->subDays(90))
            ->get(['question', 'categorie'])
            ->groupBy(fn ($e) => Str::of($e->question)->lower()->ascii()->replaceMatches('/[^a-z0-9 ]/', '')->squish()->toString())
            ->map(fn ($lot) => ['question' => $lot->first()->question, 'total' => $lot->count(), 'categorie' => $lot->first()->categorie])
            ->sortByDesc('total')
            ->take(5)
            ->values();

        return [
            'questions_total' => (clone $base)->count(),
            'questions_periode' => (clone $base)->where('created_at', '>=', $debut)->count(),
            'utilisateurs_periode' => (clone $base)->where('created_at', '>=', $debut)->distinct('user_id')->count('user_id'),
            'hors_ligne_periode' => (clone $base)->where('created_at', '>=', $debut)->where('source', 'local')->count(),
            'frequentes' => $frequentes,
            'par_categorie' => (clone $base)->where('created_at', '>=', $debut)->whereNotNull('categorie')
                ->groupBy('categorie')->pluck(DB::raw('COUNT(*) as total'), 'categorie')
                ->map(fn ($total, $cat) => ['categorie' => ConnaissanceAssistant::CATEGORIES[$cat] ?? $cat, 'total' => (int) $total])
                ->values(),
            'a_completer' => ConnaissanceAssistant::pourEtablissement($etabId)->where('actif', true)->where('a_valider', true)->count(),
        ];
    }

    // ---------- Base de connaissances (FabManager / Super Admin) ----------

    public function connaissances(Request $request)
    {
        $etabId = $request->user()->etablissement_id;

        return [
            'categories' => collect(ConnaissanceAssistant::CATEGORIES)->map(fn ($label, $code) => ['code' => $code, 'label' => $label])->values(),
            'connaissances' => ConnaissanceAssistant::pourEtablissement($etabId)
                ->orderByRaw('FIELD(categorie, '.collect(array_keys(ConnaissanceAssistant::CATEGORIES))->map(fn ($c) => "'{$c}'")->implode(',').')')
                ->orderBy('ordre')
                ->get(),
            'statistiques' => $etabId ? self::statistiques($etabId, now()->subDays(30)->toDateString()) : null,
        ];
    }

    public function creerConnaissance(Request $request)
    {
        $data = $this->validerConnaissance($request);
        $data['etablissement_id'] = $request->user()->etablissement_id;
        $data['ordre'] = (int) ConnaissanceAssistant::pourEtablissement($data['etablissement_id'])->max('ordre') + 1;

        return response()->json(ConnaissanceAssistant::create($data), 201);
    }

    public function modifierConnaissance(Request $request, ConnaissanceAssistant $connaissance)
    {
        $this->autoriser($request, $connaissance);
        $connaissance->update($this->validerConnaissance($request));

        return $connaissance->fresh();
    }

    public function supprimerConnaissance(Request $request, ConnaissanceAssistant $connaissance)
    {
        $this->autoriser($request, $connaissance);
        $connaissance->delete();

        return response()->noContent();
    }

    private function validerConnaissance(Request $request): array
    {
        return $request->validate([
            'categorie' => ['required', Rule::in(array_keys(ConnaissanceAssistant::CATEGORIES))],
            'titre' => ['required', 'string', 'min:3', 'max:255'],
            'contenu' => ['required', 'string', 'min:3', 'max:5000'],
            'questions_types' => ['nullable', 'string', 'max:500'],
            'mots_cles' => ['nullable', 'string', 'max:500'],
            'a_valider' => ['sometimes', 'boolean'],
            'actif' => ['sometimes', 'boolean'],
        ], [
            'titre.required' => 'Le titre est obligatoire.',
            'contenu.required' => 'Le contenu est obligatoire.',
            'categorie.in' => 'Catégorie inconnue.',
        ]);
    }

    private function autoriser(Request $request, ConnaissanceAssistant $connaissance): void
    {
        $user = $request->user();
        $commune = $connaissance->etablissement_id === null;

        abort_unless(
            ($commune && $user->role === Roles::ADMIN_GLOBAL) || $connaissance->etablissement_id === $user->etablissement_id,
            403,
            'Cette fiche appartient à un autre établissement.'
        );
    }
}
