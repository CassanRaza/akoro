<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Laravel\Sanctum\HasApiTokens;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\URL;

#[Fillable(['name', 'email', 'telephone', 'adresse', 'password', 'etablissement_id', 'parcours_id', 'role', 'actif', 'photo'])]
#[Hidden(['password', 'remember_token', 'photo'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    // Ajoute automatiquement "photo_url" (lien signé temporaire) dans le JSON
    protected $appends = ['photo_url'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'actif' => 'boolean',
        ];
    }

    public function parcours()
    {
        return $this->belongsTo(Parcours::class);
    }

    public function absences()
    {
        return $this->hasMany(Absence::class);
    }

    public function presences()
    {
        return $this->hasMany(Presence::class);
    }

    public function conversations()
{
    return $this->belongsToMany(Conversation::class)
        ->withPivot('last_read_at')
        ->withTimestamps();
}

public function messages()
{
    return $this->hasMany(Message::class, 'auteur_id');
}
    // Le chemin interne de la photo n'est jamais exposé : seulement un lien valable 1 h
    public function getPhotoUrlAttribute(): ?string
    {
        if (! $this->photo) {
            return null;
        }

        return URL::temporarySignedRoute('files.photo', now()->addHour(), ['user' => $this->id]);
    }
}