<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lecon;
use App\Models\Ressource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class FileController extends Controller
{
    // Types affichables directement dans le navigateur ; tout le reste est forcé en téléchargement
    private const AFFICHABLES = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif'];

    // Document d'une leçon (lien signé temporaire, voir Ressource::getUrlAttribute)
    public function ressource(Request $request, Ressource $ressource)
    {
        abort_unless(Storage::disk('local')->exists($ressource->chemin), 404);

        $extension = strtolower($ressource->type);
        $affichable = in_array($extension, self::AFFICHABLES, true) && ! $request->boolean('download');

        $headers = ['X-Content-Type-Options' => 'nosniff'];

        if ($extension === 'pdf') {
            $headers['Content-Type'] = 'application/pdf';
        } elseif (! $affichable) {
            $headers['Content-Type'] = 'application/octet-stream';
        }

        return Storage::disk('local')->response(
            $ressource->chemin,
            $ressource->nom_fichier,
            $headers,
            $affichable ? 'inline' : 'attachment'
        );
    }

    // Toute la leçon : le fichier seul s'il n'y en a qu'un, sinon une archive ZIP
    public function lecon(Lecon $lecon)
    {
        $ressources = $lecon->ressources()
            ->orderBy('created_at')
            ->get()
            ->filter(fn ($r) => Storage::disk('local')->exists($r->chemin))
            ->values();

        abort_if($ressources->isEmpty(), 404, 'Cette leçon ne contient aucun document.');

        if ($ressources->count() === 1) {
            $r = $ressources->first();
            return Storage::disk('local')->download($r->chemin, $r->nom_fichier);
        }

        abort_unless(class_exists(\ZipArchive::class), 500, "L'extension PHP zip n'est pas activée sur le serveur.");

        $zipPath = tempnam(sys_get_temp_dir(), 'lecon');
        $zip = new \ZipArchive();

        if ($zip->open($zipPath, \ZipArchive::CREATE | \ZipArchive::OVERWRITE) !== true) {
            abort(500, "Impossible de créer l'archive.");
        }

        foreach ($ressources as $i => $r) {
            $nomDansArchive = ($i + 1) . ' - ' . str_replace(['/', '\\'], '_', $r->nom_fichier);
            $zip->addFile(Storage::disk('local')->path($r->chemin), $nomDansArchive);
        }

        $zip->close();

        $nom = Str::slug($lecon->titre) ?: 'lecon';

        return response()->download($zipPath, $nom . '.zip')->deleteFileAfterSend(true);
    }

    // Photo d'un bénéficiaire (lien signé temporaire, voir User::getPhotoUrlAttribute)
    public function photo(User $user)
    {
        abort_unless($user->photo && Storage::disk('local')->exists($user->photo), 404);

        return Storage::disk('local')->response($user->photo);
    }
}