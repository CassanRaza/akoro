<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Devoir;
use App\Models\Soumission;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;

/**
 * Devoirs à rendre (type « rendu ») côté bénéficiaire (application mobile) :
 * consulter la consigne, déposer ou remplacer son fichier jusqu'à la date limite, voir sa note.
 */
class DevoirRenduController extends Controller
{
    private const EXTENSIONS = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

    // ---------- Liste des devoirs à rendre de mon parcours ----------
    public function index(Request $request)
    {
        $user = $request->user();
        if (! $user->parcours_id) {
            return [];
        }

        $devoirs = Devoir::query()
            ->where('type', 'rendu')
            ->where('parcours_id', $user->parcours_id)
            ->whereIn('statut', ['programme', 'en_cours', 'termine'])
            ->with(['lecon:id,titre', 'lecons:id,titre'])
            ->orderByRaw('date_limite IS NULL, date_limite')
            ->get();

        $soumissions = Soumission::where('user_id', $user->id)
            ->whereIn('devoir_id', $devoirs->pluck('id'))
            ->get()
            ->keyBy('devoir_id');

        return $devoirs->map(fn (Devoir $d) => $this->resume($d, $soumissions[$d->id] ?? null))->values();
    }

    // ---------- Détail : consigne + mon rendu ----------
    public function show(Request $request, Devoir $devoir)
    {
        $user = $request->user();
        $this->autoriser($user, $devoir);
        $devoir->load(['lecon:id,titre', 'lecons:id,titre']);

        $soumission = Soumission::where('devoir_id', $devoir->id)->where('user_id', $user->id)->first();

        return $this->resume($devoir, $soumission, detail: true);
    }

    // ---------- Déposer (ou remplacer) mon fichier ----------
    public function deposer(Request $request, Devoir $devoir)
    {
        $user = $request->user();
        $this->autoriser($user, $devoir);

        $soumission = Soumission::where('devoir_id', $devoir->id)->where('user_id', $user->id)->first();

        abort_if($soumission?->statut === 'corrige', 422, 'Ce devoir a déjà été corrigé : il ne peut plus être modifié.');
        abort_if($this->ferme($devoir), 422, 'La date limite est passée : le dépôt est fermé.');

        $request->validate([
            'fichier' => [
                'bail', 'required', 'file', 'max:10240',
                function (string $attribute, mixed $value, \Closure $fail) {
                    $extension = strtolower($value->getClientOriginalExtension());
                    if (! in_array($extension, self::EXTENSIONS, true)) {
                        $fail('Format non accepté : envoyez un PDF ou une photo (JPG, PNG, WEBP).');
                        return;
                    }
                    if ($extension === 'pdf' && $value->getMimeType() !== 'application/pdf') {
                        $fail('Ce fichier n’est pas un PDF valide.');
                    }
                },
            ],
        ], [
            'fichier.required' => 'Choisissez un fichier à envoyer.',
            'fichier.file' => 'Le fichier envoyé est invalide.',
            'fichier.max' => 'Le fichier est trop volumineux (10 Mo maximum).',
            'fichier.uploaded' => 'Le fichier n’a pas pu être envoyé (trop volumineux pour le serveur).',
        ]);

        $fichier = $request->file('fichier');
        $chemin = $fichier->store('devoirs/rendus', 'local');

        // Un nouveau dépôt remplace l'ancien fichier
        if ($soumission?->fichier) {
            Storage::disk('local')->delete($soumission->fichier);
        }

        $soumission = Soumission::updateOrCreate(
            ['devoir_id' => $devoir->id, 'user_id' => $user->id],
            [
                'fichier' => $chemin,
                'nom_fichier' => mb_substr(basename($fichier->getClientOriginalName()), 0, 200),
                'statut' => 'rendu',
                'date_soumission' => now(),
            ]
        );

        $devoir->load(['lecon:id,titre', 'lecons:id,titre']);

        return $this->resume($devoir, $soumission, detail: true);
    }

    // ---------- Outils ----------

    private function autoriser(User $user, Devoir $devoir): void
    {
        abort_unless(
            $devoir->type === 'rendu'
                && $devoir->parcours_id === $user->parcours_id
                && in_array($devoir->statut, ['programme', 'en_cours', 'termine'], true),
            403,
            'Ce devoir ne fait pas partie de votre parcours.'
        );
    }

    private function ferme(Devoir $d): bool
    {
        return $d->statut === 'termine' || ($d->date_limite && $d->date_limite->isPast());
    }

    /** a_rendre | rendu | corrige | manque */
    private function etat(Devoir $d, ?Soumission $s): string
    {
        return match (true) {
            $s?->statut === 'corrige' => 'corrige',
            $s?->statut === 'rendu' => 'rendu',
            $this->ferme($d) => 'manque',
            default => 'a_rendre',
        };
    }

    private function resume(Devoir $d, ?Soumission $s, bool $detail = false): array
    {
        $etat = $this->etat($d, $s);
        $donnees = [
            'id' => $d->id,
            'titre' => $d->titre,
            'formation' => $d->lecon?->titre ?? $d->lecons->first()?->titre,
            'date_limite' => $d->date_limite?->toIso8601String(),
            'etat' => $etat,
            'peut_deposer' => $etat !== 'corrige' && ! $this->ferme($d),
            'a_consigne' => (bool) $d->fichier_consigne,
            'soumission' => $s && $s->statut !== 'en_attente' ? [
                'nom_fichier' => $s->nom_fichier,
                'date_soumission' => $s->date_soumission?->toIso8601String(),
                'note' => $s->statut === 'corrige' && $s->note !== null ? (float) $s->note : null,
                'commentaire' => $s->statut === 'corrige' ? $s->commentaire : null,
            ] : null,
        ];

        if (! $detail) {
            return $donnees;
        }

        // Liens relatifs signés : l'application les complète avec l'adresse du serveur qu'elle utilise
        return [
            ...$donnees,
            'description' => $d->description,
            'consigne_url' => $d->fichier_consigne
                ? URL::temporarySignedRoute('files.consigne.mobile', now()->addHours(2), ['devoir' => $d->id], absolute: false)
                : null,
            'fichier_url' => $s?->fichier
                ? URL::temporarySignedRoute('files.soumission.mobile', now()->addHours(2), ['soumission' => $s->id], absolute: false)
                : null,
        ];
    }
}
