<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Seance extends Model
{
    use HasFactory;

    // Préfixe du contenu du QR code (l'application refuse tout autre QR)
    public const PREFIXE_QR = 'AKORO-SEANCE:';

    // Lettres et chiffres sans ambiguïté (pas de 0/O, 1/I/L) pour le code saisi à la main
    private const ALPHABET_CODE = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    protected $fillable = [
        'parcours_id', 'lecon_id', 'date', 'heure_debut', 'heure_fin',
        'attendus', 'absences_generees_le', 'qr_token', 'code',
    ];

    // Le QR et son code ne sont JAMAIS envoyés dans les listes (les bénéficiaires lisent aussi les séances) :
    // ils ne sont affichés qu'à l'équipe, via GET /seances/{id}/qr
    protected $hidden = ['qr_token', 'code'];

    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
            'absences_generees_le' => 'datetime',
        ];
    }

    // QR généré automatiquement à la planification
    protected static function booted(): void
    {
        static::creating(function (Seance $s) {
            $s->qr_token ??= self::nouveauToken();
            $s->code ??= self::nouveauCode();
        });
    }

    public static function nouveauToken(): string
    {
        return Str::random(40);
    }

    public static function nouveauCode(): string
    {
        do {
            $code = '';
            for ($i = 0; $i < 6; $i++) {
                $code .= self::ALPHABET_CODE[random_int(0, strlen(self::ALPHABET_CODE) - 1)];
            }
        } while (self::where('code', $code)->exists());

        return $code;
    }

    /** Heure locale du FabLab (les séances sont saisies dans ce fuseau). */
    public static function maintenant(): Carbon
    {
        return now(config('akoro.fuseau', 'Indian/Antananarivo'));
    }

    public function contenuQr(): string
    {
        return self::PREFIXE_QR.$this->qr_token;
    }

    /** Créneau pendant lequel le QR est accepté : de [marge] min avant le début à [marge] min après la fin. */
    public function fenetrePointage(): array
    {
        $marge = (int) config('akoro.qr_marge_minutes', 30);
        $jour = $this->date->format('Y-m-d');

        $fuseau = config('akoro.fuseau', 'Indian/Antananarivo');

        return [
            Carbon::parse("{$jour} {$this->heure_debut}", $fuseau)->subMinutes($marge),
            Carbon::parse("{$jour} {$this->heure_fin}", $fuseau)->addMinutes($marge),
        ];
    }

    /** 'a_venir' | 'ouverte' | 'terminee' (pour le pointage). */
    public function etatPointage(?Carbon $maintenant = null): string
    {
        $maintenant ??= self::maintenant();
        [$ouverture, $fermeture] = $this->fenetrePointage();

        return $maintenant->lt($ouverture) ? 'a_venir' : ($maintenant->gt($fermeture) ? 'terminee' : 'ouverte');
    }

    public function parcours()
    {
        return $this->belongsTo(Parcours::class);
    }

    public function lecon()
    {
        return $this->belongsTo(Lecon::class);
    }

    public function absences()
    {
        return $this->hasMany(Absence::class);
    }

    public function presences()
    {
        return $this->hasMany(Presence::class);
    }
}
