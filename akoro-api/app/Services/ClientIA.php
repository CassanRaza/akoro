<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Client IA commun (format « chat completions », compatible OpenAI).
 *
 * Essaie les fournisseurs configurés dans l'ordre (config/services.php → ia.fournisseurs) :
 * Google Gemini (niveau gratuit) en premier, puis son modèle léger, puis OpenAI si une clé est fournie.
 * Un fournisseur dont la clé est refusée ou le quota épuisé est mis de côté quelques minutes,
 * pour ne pas faire attendre l'utilisateur à chaque question.
 */
class ClientIA
{
    /**
     * @param  array<int, array{role:string, content:string}>  $messages
     * @return array{texte:string, fournisseur:string, modele:string}|null  null si aucune IA n'a répondu
     */
    public function discuter(array $messages, int $maxTokens = 2048, float $temperature = 0.4, int $delai = 20): ?array
    {
        foreach ($this->fournisseurs() as $f) {
            $texte = $this->appeler($f, $messages, $maxTokens, $temperature, $delai);
            if ($texte !== null) {
                return ['texte' => $texte, 'fournisseur' => $f['nom'], 'modele' => $f['modele']];
            }
        }

        return null;
    }

    public function disponible(): bool
    {
        return $this->fournisseurs() !== [];
    }

    /** Fournisseurs utilisables (clé renseignée et pas mise de côté récemment). */
    private function fournisseurs(): array
    {
        $configures = collect(config('services.ia.fournisseurs', []))
            ->map(fn ($f) => array_merge($f, ['cle' => trim((string) ($f['cle'] ?? ''))]))
            ->filter(fn ($f) => $f['cle'] !== '' && ! empty($f['modele']))
            ->values();

        $libres = $configures->reject(fn ($f) => Cache::has($this->cleCache($f)))->values();

        // Tous en pause (surcharge passagère) : on retente quand même ceux qui ne sont pas « refusés »
        // plutôt que de basculer directement en mode hors ligne.
        return ($libres->isNotEmpty() ? $libres : $configures->reject(fn ($f) => Cache::get($this->cleCache($f)) === 'refuse'))
            ->values()
            ->all();
    }

    private function appeler(array $f, array $messages, int $maxTokens, float $temperature, int $delai): ?string
    {
        $corps = [
            'model' => $f['modele'],
            'messages' => $messages,
            'temperature' => $temperature,
            // Les modèles Gemini 3 « réfléchissent » avant de répondre : la réflexion compte dans ce plafond,
            // d'où une marge large pour ne jamais couper une réponse en plein milieu.
            'max_tokens' => $maxTokens,
        ];
        if (! empty($f['reflexion'])) {
            $corps['reasoning_effort'] = $f['reflexion'];
        }

        $reponse = null;
        for ($essai = 1; $essai <= 2; $essai++) {
            try {
                $reponse = Http::withToken($f['cle'])
                    ->acceptJson()
                    ->connectTimeout(8)
                    ->timeout($delai)
                    ->post(rtrim($f['url'], '/').'/chat/completions', $corps);
            } catch (ConnectionException $e) {
                Log::warning("IA : {$f['nom']} injoignable", ['erreur' => $e->getMessage()]);
                Cache::put($this->cleCache($f), 'pause', now()->addSeconds(30));

                return null;
            }
            // Modèle momentanément surchargé : une seconde tentative rapide réussit souvent
            if ($essai === 1 && in_array($reponse->status(), [500, 503], true)) {
                usleep(1_500_000);

                continue;
            }
            break;
        }

        if (! $reponse->successful()) {
            $statut = $reponse->status();
            Log::warning("IA : réponse {$f['nom']} ({$f['modele']}) en erreur", ['status' => $statut, 'body' => Str::limit($reponse->body(), 300)]);

            // Clé invalide, crédit ou quota épuisé, modèle inconnu : on passe au suivant sans réessayer tout de suite
            $code = (string) data_get($reponse->json(), 'error.code', data_get($reponse->json(), '0.error.code', ''));
            if (in_array($statut, [401, 403, 404], true) || $code === 'insufficient_quota') {
                Cache::put($this->cleCache($f), 'refuse', now()->addMinutes(10));
            } elseif ($statut === 429) {
                // Quota par minute du niveau gratuit atteint
                Cache::put($this->cleCache($f), 'pause', now()->addMinute());
            } elseif ($statut >= 500) {
                // Modèle surchargé (fréquent sur le niveau gratuit) : courte pause
                Cache::put($this->cleCache($f), 'pause', now()->addSeconds(30));
            }

            return null;
        }

        $texte = trim((string) data_get($reponse->json(), 'choices.0.message.content', ''));

        return $texte === '' ? null : $texte;
    }

    private function cleCache(array $f): string
    {
        return 'ia_indisponible_'.md5($f['nom'].$f['modele'].$f['cle']);
    }
}
