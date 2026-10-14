<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\URL;

class Lecon extends Model
{
    use HasFactory;

    protected $fillable = ['parcours_id', 'titre', 'description', 'ordre'];

    // Ajoute automatiquement "download_url" (lien signé temporaire) dans le JSON
    protected $appends = ['download_url'];

    public function parcours()
    {
        return $this->belongsTo(Parcours::class);
    }

    public function ressources()
    {
        return $this->hasMany(Ressource::class);
    }

    public function absences()
    {
        return $this->hasMany(Absence::class);
    }

    public function getDownloadUrlAttribute(): string
    {
        return URL::temporarySignedRoute('files.lecon', now()->addHour(), ['lecon' => $this->id]);
    }
}