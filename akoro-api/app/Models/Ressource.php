<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\URL;

class Ressource extends Model
{
    use HasFactory;

    protected $fillable = ['lecon_id', 'titre', 'type', 'chemin', 'nom_fichier', 'taille'];

    // Le chemin interne du fichier n'est jamais envoyé au navigateur
    protected $hidden = ['chemin'];

    // Ajoute automatiquement "url" (ouverture) et "download_url" (téléchargement) dans le JSON
    protected $appends = ['url', 'download_url'];

    public function lecon()
    {
        return $this->belongsTo(Lecon::class);
    }

    public function getUrlAttribute(): string
    {
        return URL::temporarySignedRoute('files.ressource', now()->addHour(), ['ressource' => $this->id]);
    }

    public function getDownloadUrlAttribute(): string
    {
        return URL::temporarySignedRoute(
            'files.ressource',
            now()->addHour(),
            ['ressource' => $this->id, 'download' => 1]
        );
    }
}