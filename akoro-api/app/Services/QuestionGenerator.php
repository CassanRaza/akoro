<?php

namespace App\Services;

use App\Models\Devoir;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class QuestionGenerator
{
    private string $generationSource = 'openai';

    public function __construct(
        private readonly LessonDocumentTextExtractor $documentTextExtractor
    ) {
    }

    public function generationSource(): string
    {
        return $this->generationSource;
    }

    /**
     * Génère des questions QCM (3 choix) à partir des leçons liées au devoir.
     */
    public function generer(Devoir $devoir, int $nombre = 5): array
    {
        $devoir->load(['lecons.ressources', 'parcours']);

        $documents = $this->extraireDocuments($devoir);
        $contexte = $this->construireContexte($documents);

        $prompt = $this->construirePrompt($contexte, $nombre, $devoir->parcours?->nom);

        if (! trim((string) config('services.openai.key'))) {
            $this->generationSource = 'local';
            return $this->genererLocalement($documents, $nombre);
        }

        try {
            $reponse = $this->appelerIA($prompt);
            $this->generationSource = 'openai';
            return $this->parserReponse($reponse, $nombre);
        } catch (\RuntimeException $e) {
            if ($e->getCode() !== 401) {
                throw $e;
            }

            Log::warning('OpenAI key rejected; generating questions from lesson content locally.');
            $this->generationSource = 'local';
            return $this->genererLocalement($documents, $nombre);
        }
    }

    private function extraireDocuments(Devoir $devoir): array
    {
        $documents = [];
        $totalCharacters = 0;
        $maxDocumentCharacters = 30000;
        $maxTotalCharacters = 100000;

        foreach ($devoir->lecons as $lecon) {
            foreach ($lecon->ressources as $ressource) {
                if ($totalCharacters >= $maxTotalCharacters) {
                    break 2;
                }

                $text = $this->documentTextExtractor->extract($ressource);
                $remainingCharacters = $maxTotalCharacters - $totalCharacters;
                $text = mb_substr(
                    $text,
                    0,
                    min($maxDocumentCharacters, $remainingCharacters)
                );
                if (trim($text) === '') {
                    continue;
                }

                $documents[] = [
                    'lecon' => $lecon->titre,
                    'nom' => $ressource->nom_fichier ?: $ressource->titre,
                    'texte' => $text,
                ];
                $totalCharacters += mb_strlen($text);
            }
        }

        if ($documents === []) {
            throw new \RuntimeException(
                'Aucun fichier lisible n’est associé aux leçons de ce devoir. '
                .'Ajoutez un document contenant du texte avant de générer les questions.'
            );
        }

        return $documents;
    }

    private function construireContexte(array $documents): string
    {
        $sections = [];
        foreach ($documents as $document) {
            $sections[] = "Leçon : {$document['lecon']}\n"
                ."Document : {$document['nom']}\n"
                ."Contenu extrait du fichier :\n{$document['texte']}";
        }

        return implode("\n\n---\n\n", $sections);
    }

    private function genererLocalement(array $documents, int $nombre): array
    {
        $faits = [];
        foreach ($documents as $document) {
            $phrases = preg_split(
                '/(?<=[.!?])\s+|\R+/u',
                $document['texte'],
                -1,
                PREG_SPLIT_NO_EMPTY
            );

            foreach ($phrases ?: [] as $phrase) {
                $phrase = trim(preg_replace('/^\s*[-•●▪\d.)]+\s*/u', '', $phrase) ?? '');
                if (mb_strlen($phrase) < 12) {
                    continue;
                }

                foreach (mb_str_split($phrase, 240) as $fragment) {
                    $fragment = trim($fragment);
                    if (mb_strlen($fragment) >= 12) {
                        $faits[] = ['lecon' => $document['lecon'], 'texte' => $fragment];
                    }
                }
            }
        }

        $faits = array_values(array_unique($faits, SORT_REGULAR));
        if ($faits === []) {
            throw new \RuntimeException(
                'Les documents liés ne contiennent pas assez de texte pour créer des questions.'
            );
        }
        if (count($faits) < $nombre) {
            throw new \RuntimeException(
                'Les leçons contiennent moins d’affirmations distinctes que le nombre de questions demandé. '
                .'Ajoutez du contenu ou réduisez le nombre de questions pour éviter les répétitions.'
            );
        }

        shuffle($faits);
        $questions = [];
        $templates = [
            'Dans « %1$s », que faut-il retenir à propos de %2$s ?',
            'Quel rôle joue %2$s dans le cours « %1$s » ?',
            'Quelle propriété caractérise %2$s dans « %1$s » ?',
            'Comment le cours « %1$s » définit-il %2$s ?',
            'Quelle fonction de %2$s est abordée dans « %1$s » ?',
            'Quel principe concernant %2$s présente le cours « %1$s » ?',
            'Quelle place est accordée à %2$s dans le thème « %1$s » ?',
            'Quelle caractéristique de %2$s faut-il connaître pour « %1$s » ?',
            'Quel fait important le cours « %1$s » rapporte-t-il sur %2$s ?',
            'Quelle relation entre %2$s et le thème « %1$s » est expliquée ?',
            'Que précise le cours « %1$s » au sujet de %2$s ?',
            'Quelle règle liée à %2$s est présentée dans « %1$s » ?',
            'Quel fonctionnement de %2$s est décrit dans « %1$s » ?',
            'Quelle notion de « %1$s » permet de comprendre %2$s ?',
            'Quel rôle le cours « %1$s » attribue-t-il à %2$s ?',
            'Quelle affirmation décrit correctement %2$s dans « %1$s » ?',
            'Quelle idée essentielle le cours « %1$s » associe-t-il à %2$s ?',
            'Quel aspect de %2$s est expliqué dans le thème « %1$s » ?',
            'Comment le contenu de « %1$s » présente-t-il %2$s ?',
            'Quel énoncé décrit précisément %2$s dans « %1$s » ?',
        ];

        for ($index = 0; $index < $nombre; $index++) {
            $fait = $faits[$index % count($faits)];
            $topic = trim($fait['lecon']) !== '' ? $fait['lecon'] : 'ce cours';
            $sujet = $this->extraireSujet($fait['texte']) ?? 'une notion importante';
            $wrongAnswers = [];
            $candidateFacts = $faits;
            shuffle($candidateFacts);
            foreach ($candidateFacts as $candidate) {
                if ($candidate['texte'] === $fait['texte']) {
                    continue;
                }

                $distractor = $this->negaterFait($candidate['texte']);
                if ($distractor !== null && $distractor !== $fait['texte']) {
                    $wrongAnswers[] = $distractor;
                }
                if (count($wrongAnswers) === 2) {
                    break;
                }
            }

            if (count($wrongAnswers) < 2) {
                foreach (['pas', 'jamais'] as $negation) {
                    $distractor = $this->negaterFait($fait['texte'], $negation);
                    if ($distractor !== null && ! in_array($distractor, $wrongAnswers, true)) {
                        $wrongAnswers[] = $distractor;
                    }
                    if (count($wrongAnswers) === 2) {
                        break;
                    }
                }
            }

            if (count($wrongAnswers) < 2) {
                throw new \RuntimeException(
                    'Le texte des leçons ne contient pas assez d’affirmations claires pour créer '
                    .'des choix de réponse crédibles et une seule bonne réponse.'
                );
            }

            $choix = [
                ['texte' => $fait['texte'], 'est_correct' => true],
                ['texte' => $wrongAnswers[0], 'est_correct' => false],
                ['texte' => $wrongAnswers[1], 'est_correct' => false],
            ];
            shuffle($choix);

            $questions[] = [
                'enonce' => sprintf($templates[$index % count($templates)], $topic, $sujet),
                'points' => 1,
                'choix' => $choix,
            ];
        }

        return $questions;
    }

    private function extraireSujet(string $texte): ?string
    {
        $verbes = [
            'étaient', 'étais', 'seraient', 'seront', 'serait', 'était',
            'sont', 'sera', 'est', 'peuvent', 'pouvait', 'pourrait',
            'doivent', 'devrait', 'permettent', 'permet', 'contiennent',
            'contient', 'comprennent', 'comprend', 'nécessitent', 'nécessite',
            'utilisent', 'utilise', 'incluent', 'inclut', 'correspondent',
            'correspond', 'organisent', 'organise', 'fonctionnent',
            'fonctionne', 'identifient', 'identifie', 'enregistrent',
            'enregistre', 'stockent', 'stocke', 'reçoivent', 'reçoit',
            'gèrent', 'gère', 'définissent', 'définit', 'représentent',
            'représente', 'servent', 'sert', 'créent', 'crée',
            'augmentent', 'augmente', 'diminuent', 'diminue',
            'peut', 'doit',
        ];
        $pattern = '/^(.{2,100}?)\s+(?:'.implode('|', array_map(
            static fn (string $verbe) => preg_quote($verbe, '/'),
            $verbes
        )).')\b/iu';

        if (! preg_match($pattern, $texte, $match)) {
            return null;
        }

        $sujet = trim($match[1], " \t\n\r\0\x0B,;:");
        $sujet = preg_replace_callback(
            '/^(Une|Un|Le|La|Les|Des|Du)\b/u',
            static fn (array $article) => mb_strtolower($article[1]),
            $sujet
        );

        return $sujet;
    }

    private function negaterFait(string $texte, string $negation = 'pas'): ?string
    {
        if (preg_match('/\b(?:ne|n[’\']|pas|jamais|aucun|aucune|sans)\b/iu', $texte)) {
            return null;
        }

        $formesVerbales = [
            'étaient', 'étais', 'seraient', 'seront', 'serait', 'était',
            'sont', 'sera', 'est', 'peuvent', 'pouvait', 'pourrait',
            'doivent', 'devrait', 'permettent', 'permet', 'contiennent',
            'contient', 'comprennent', 'comprend', 'nécessitent', 'nécessite',
            'utilisent', 'utilise', 'incluent', 'inclut', 'correspondent',
            'correspond', 'organisent', 'organise', 'fonctionnent',
            'fonctionne', 'identifient', 'identifie', 'enregistrent',
            'enregistre', 'stockent', 'stocke', 'reçoivent', 'reçoit',
            'gèrent', 'gère', 'définissent', 'définit', 'représentent',
            'représente', 'servent', 'sert', 'créent', 'crée',
            'augmentent', 'augmente', 'diminuent', 'diminue',
            'peut', 'doit',
        ];

        foreach ($formesVerbales as $verbe) {
            if (preg_match('/\b'.preg_quote($verbe, '/').'\b/iu', $texte, $match, PREG_OFFSET_CAPTURE)) {
                $position = $match[0][1];
                $forme = $match[0][0];
                $particule = preg_match('/^[aeiouyàâäéèêëîïôöùûü]/iu', $forme) ? 'n’' : 'ne ';
                $remplacement = $particule.$forme.($negation === 'jamais' ? ' jamais' : ' pas');
                $verbesEtre = ['étaient', 'étais', 'seraient', 'seront', 'serait', 'était', 'sont', 'sera', 'est'];
                if ($negation === 'pas' && ! in_array($verbe, $verbesEtre, true)) {
                    $remplacement = preg_replace('/\bpas (?:des|du|de la|un|une)\b/u', 'pas de', $remplacement) ?? $remplacement;
                }

                return substr_replace($texte, $remplacement, $position, strlen($forme));
            }
        }

        return null;
    }

    private function construirePrompt(string $contexte, int $nombre, ?string $parcours): string
    {
        $parcoursTxt = $parcours ? "du parcours « {$parcours} »" : '';

        return <<<PROMPT
Tu es un formateur pédagogique pour un FabLab. À partir du contenu des leçons ci-dessous {$parcoursTxt}, génère exactement {$nombre} questions de type QCM.

Règles strictes :
- Chaque question doit avoir exactement 3 choix de réponses.
- Exactement une réponse doit être correcte ; les deux autres doivent être fausses au regard des documents.
- Génère exactement {$nombre} questions, toutes distinctes et centrées sur des notions différentes.
- Pour chaque leçon, utilise son titre pour identifier le sujet à évaluer, puis vérifie chaque question et chaque réponse dans le contenu extrait de son fichier.
- Interroge la compréhension réelle : définition, rôle, fonctionnement, choix d'une méthode, relation de cause à effet, caractéristique ou application présentée dans le cours.
- Formule des énoncés précis qui désignent clairement la notion visée ; ne demande jamais simplement « quelle affirmation correspond au document ? » et ne répète pas un même gabarit.
- Les trois choix doivent être cohérents et plausibles pour la même question. Les deux distracteurs doivent pouvoir faire hésiter un apprenant, mais être clairement faux d’après le cours. Évite les négations artificielles et les options hors sujet.
- Les questions doivent être claires, adaptées à des débutants / intermédiaires.
- Base-toi exclusivement sur les notions, explications, exemples et faits réellement présents dans les fichiers.
- N’utilise jamais un titre de leçon ou de fichier comme s’il s’agissait du contenu pédagogique.
- Ne complète pas avec des connaissances extérieures aux documents.
- Répartis les questions entre les différents fichiers et notions quand plusieurs sources sont fournies.
- Réponds UNIQUEMENT en JSON valide, sans texte autour.

Format JSON attendu :
[
  {
    "enonce": "Texte de la question ?",
    "points": 1,
    "choix": [
      { "texte": "Réponse A", "est_correct": false },
      { "texte": "Réponse B", "est_correct": true },
      { "texte": "Réponse C", "est_correct": false }
    ]
  }
]

Contenu des leçons :
{$contexte}
PROMPT;
    }

    private function appelerIA(string $prompt): string
    {
        $apiKey = trim((string) config('services.openai.key'));
        $model = config('services.openai.model', 'gpt-4o-mini');

        if (! $apiKey) {
            throw new \RuntimeException(
                'La génération automatique nécessite une clé API OpenAI. '
                .'Configurez OPENAI_API_KEY dans le fichier .env de l’API.'
            );
        }

        try {
            $response = Http::withToken($apiKey)
                ->acceptJson()
                ->timeout(60)
                ->post('https://api.openai.com/v1/chat/completions', [
                    'model' => $model,
                    'messages' => [
                        ['role' => 'system', 'content' => 'Tu génères uniquement du JSON valide pour des QCM pédagogiques.'],
                        ['role' => 'user', 'content' => $prompt],
                    ],
                    'temperature' => 0.7,
                ]);
        } catch (ConnectionException $e) {
            Log::error('OpenAI question generation connection failed', [
                'exception' => $e::class,
            ]);

            throw new \RuntimeException(
                'Impossible de joindre OpenAI. Vérifiez la connexion Internet du serveur API et réessayez.'
            );
        }

        if (! $response->successful()) {
            $status = $response->status();
            $errorCode = $response->json('error.code');
            $errorType = $response->json('error.type');

            Log::error('OpenAI question generation failed', [
                'status' => $status,
                'error_code' => is_string($errorCode) ? $errorCode : null,
                'error_type' => is_string($errorType) ? $errorType : null,
            ]);

            if ($status === 401) {
                throw new \RuntimeException(
                    'La clé OpenAI configurée est refusée. Créez une nouvelle clé dans le tableau de bord OpenAI, '
                    .'renseignez-la dans akoro-api/.env (OPENAI_API_KEY), puis exécutez php artisan config:clear '
                    .'et redémarrez le serveur Laravel. Ne mettez jamais cette clé dans l’APK.',
                    401
                );
            }

            if ($status === 429) {
                if ($errorCode === 'insufficient_quota') {
                    throw new \RuntimeException(
                        'Le compte OpenAI n’a plus de crédit API disponible. Vérifiez la facturation et les limites '
                        .'du projet OpenAI.'
                    );
                }

                throw new \RuntimeException(
                    'OpenAI limite temporairement les demandes. Attendez un instant puis réessayez.'
                );
            }

            if ($status === 403) {
                throw new \RuntimeException(
                    'La clé OpenAI n’a pas accès à ce modèle ou à ce projet. Vérifiez les autorisations et le modèle '
                    .'configuré dans akoro-api/.env.'
                );
            }

            if ($status === 404) {
                throw new \RuntimeException(
                    'Le modèle OpenAI configuré est introuvable. Vérifiez OPENAI_MODEL dans akoro-api/.env.'
                );
            }

            if ($status === 400) {
                throw new \RuntimeException(
                    'OpenAI a refusé le format de la demande. Vérifiez le modèle configuré, puis réessayez.'
                );
            }

            throw new \RuntimeException(
                'Le service OpenAI a renvoyé une erreur (HTTP '.$status.'). Réessayez plus tard.'
            );
        }

        $contenu = $response->json('choices.0.message.content');
        if (! is_string($contenu) || trim($contenu) === '') {
            throw new \RuntimeException('OpenAI a renvoyé une réponse vide. Réessayez.');
        }

        return $contenu;
    }

    private function parserReponse(string $contenu, int $nombre): array
    {
        // Extraire le JSON même s’il y a du texte autour
        if (preg_match('/\[.*\]/s', $contenu, $matches)) {
            $contenu = $matches[0];
        }

        $data = json_decode($contenu, true);

        if (! is_array($data)) {
            throw new \RuntimeException('Réponse IA invalide (JSON attendu).');
        }

        if (count($data) < $nombre) {
            throw new \RuntimeException(
                'L’IA a renvoyé moins de questions que demandé. Réessayez la génération.'
            );
        }

        $questions = [];
        $enoncesVus = [];

        foreach (array_slice($data, 0, $nombre) as $q) {
            if (empty($q['enonce']) || empty($q['choix']) || ! is_array($q['choix'])) {
                throw new \RuntimeException('L’IA a renvoyé une question incomplète. Réessayez.');
            }

            if (count($q['choix']) !== 3) {
                throw new \RuntimeException(
                    'L’IA doit fournir exactement trois choix crédibles pour chaque question. Réessayez.'
                );
            }

            $choix = [];
            $nombreReponsesCorrectes = 0;
            foreach ($q['choix'] as $c) {
                if (! is_array($c) || ! isset($c['texte']) || ! is_string($c['texte']) || trim($c['texte']) === '') {
                    throw new \RuntimeException(
                        'L’IA a renvoyé un choix vide ou invalide. Réessayez.'
                    );
                }

                $estCorrect = filter_var($c['est_correct'] ?? false, FILTER_VALIDATE_BOOLEAN);
                $nombreReponsesCorrectes += $estCorrect ? 1 : 0;
                $choix[] = [
                    'texte' => trim($c['texte']),
                    'est_correct' => $estCorrect,
                ];
            }

            if ($nombreReponsesCorrectes !== 1) {
                throw new \RuntimeException(
                    'Chaque question doit avoir une seule réponse correcte. Réessayez la génération.'
                );
            }

            if (! is_string($q['enonce'])) {
                throw new \RuntimeException('L’IA a renvoyé un énoncé invalide. Réessayez.');
            }
            $enonce = trim($q['enonce']);
            if (mb_strlen($enonce) < 10) {
                throw new \RuntimeException('L’IA a renvoyé un énoncé trop court. Réessayez.');
            }
            $cleEnonce = mb_strtolower(preg_replace('/\s+/u', ' ', $enonce) ?? $enonce);
            if (isset($enoncesVus[$cleEnonce])) {
                throw new \RuntimeException(
                    'L’IA a répété une question. Relancez la génération pour obtenir des questions différentes.'
                );
            }
            $enoncesVus[$cleEnonce] = true;

            $questions[] = [
                'enonce' => $enonce,
                'points' => max(1, (int) ($q['points'] ?? 1)),
                'choix'  => $choix,
            ];
        }

        if (empty($questions)) {
            throw new \RuntimeException('L’IA n’a renvoyé aucune question exploitable.');
        }

        return $questions;
    }

}