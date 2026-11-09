<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    use HasFactory;

    // Délai pendant lequel l'auteur peut modifier son message (comme Messenger)
    public const DELAI_MODIFICATION_MINUTES = 15;

    // Réactions proposées dans l'interface
    public const REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];

    protected $fillable = [
        'conversation_id',
        'auteur_id',
        'reply_to_id',
        'contenu',
        'fichier',
        'modifie_le',
        'supprime_le',
    ];

    protected function casts(): array
    {
        return [
            'modifie_le' => 'datetime',
            'supprime_le' => 'datetime',
        ];
    }

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }

    public function auteur()
    {
        return $this->belongsTo(User::class, 'auteur_id');
    }

    public function replyTo()
    {
        return $this->belongsTo(Message::class, 'reply_to_id');
    }

    public function reactions()
    {
        return $this->hasMany(MessageReaction::class);
    }

    public function estSupprime(): bool
    {
        return $this->supprime_le !== null;
    }

    public function modifiablePar(User $user): bool
    {
        return $this->auteur_id === $user->id
            && ! $this->estSupprime()
            && $this->created_at->gt(now()->subMinutes(self::DELAI_MODIFICATION_MINUTES));
    }
}
