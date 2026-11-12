<?php

namespace App\Services;

use App\Models\Devoir;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

class QuestionGenerator
{
    // Un QCM demande une réponse bien plus longue qu'un échange avec FAB'IA
    private const DELAI_IA_SECONDES = 60;

    private const LONGUEUR_MAX_CHOIX = 255;

    private string $generationSource = 'ia';

    public function __construct(
        private readonly LessonDocumentTextExtractor $documentTextExtractor,
        private readonly ClientIA $ia
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

        return $this->genererPourLecons($devoir->lecons, $nombre, $devoir->parcours?->nom);
    }

    /**
     * Génère des questions QCM (3 choix) à partir des documents de ces leçons
     * (devoir du formateur ou entraînement libre du bénéficiaire). Les ressources doivent être chargées.
     */
    public function genererPourLecons(Collection $lecons, int $nombre, ?string $parcours = null): array
    {
        $documents = $this->extraireDocuments($lecons);
        $contexte = $this->construireContexte($documents);

        $prompt = $this->construirePrompt($contexte, $nombre, $parcours);

        if (! $this->ia->disponible()) {
            throw new \RuntimeException(
                'Aucun service d’IA n’est configuré. Renseignez GEMINI_API_KEY dans akoro-api/.env, '
                .'ou saisissez les questions manuellement.'
            );
        }

        $messages = [
            ['role' => 'system', 'content' => 'Tu génères uniquement du JSON valide pour des QCM pédagogiques.'],
            ['role' => 'user', 'content' => $prompt],
        ];
        $maxTokens = max(8192, $nombre * 800);
        $erreur = null;

        // Une réponse mal formée est fréquente et ponctuelle : une seconde tentative suffit en général
        for ($essai = 1; $essai <= 2; $essai++) {
            $reponse = $this->ia->discuter($messages, $maxTokens, 0.7, self::DELAI_IA_SECONDES);

            if ($reponse === null) {
                throw new \RuntimeException(
                    'Le service d’IA est momentanément indisponible (connexion Internet ou quota atteint). '
                    .'Réessayez dans une minute ou saisissez les questions manuellement.'
                );
            }

            try {
                $questions = $this->parserReponse($reponse['texte'], $nombre);
                $this->generationSource = $reponse['fournisseur'];

                return $questions;
            } catch (\RuntimeException $e) {
                Log::warning('Génération de questions : réponse IA inexploitable', [
                    'essai' => $essai,
                    'fournisseur' => $reponse['fournisseur'],
                    'erreur' => $e->getMessage(),
                ]);
                $erreur = $e;
            }
        }

        throw $erreur;
    }

    private function extraireDocuments(Collection $lecons): array
    {
        $documents = [];
        $erreurLecture = null;
        $totalCharacters = 0;
        $maxDocumentCharacters = 30000;
        $maxTotalCharacters = 100000;

        foreach ($lecons as $lecon) {
            foreach ($lecon->ressources as $ressource) {
                if ($totalCharacters >= $maxTotalCharacters) {
                    break 2;
                }

                // Une image ou un scan joint à la leçon ne doit pas bloquer les autres documents
                try {
                    $text = $this->documentTextExtractor->extract($ressource);
                } catch (\RuntimeException $e) {
                    $erreurLecture ??= $e->getMessage();

                    continue;
                }

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
                $erreurLecture
                ?? 'Aucun fichier lisible n’est associé aux leçons de ce devoir. '
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
- Chaque choix de réponse fait moins de 200 caractères.
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

                if (mb_strlen(trim($c['texte'])) > self::LONGUEUR_MAX_CHOIX) {
                    throw new \RuntimeException('L’IA a renvoyé un choix trop long. Réessayez la génération.');
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