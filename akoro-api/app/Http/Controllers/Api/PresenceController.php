<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Presence;
use Carbon\Carbon;
use Illuminate\Http\Request;

class PresenceController extends Controller
{
    // Pointage du jour du bénéficiaire connecté (null s'il n'a pas encore pointé)
    public function aujourdhui(Request $request)
    {
        return response()->json([
            'presence' => Presence::where('user_id', $request->user()->id)
                ->whereDate('date', now()->toDateString())
                ->first(),
        ]);
    }

    // 1er appel du jour = arrivée, 2e appel (10 min plus tard au minimum) = départ
    public function pointer(Request $request)
    {
        $user = $request->user();
        $maintenant = now();
        $jour = $maintenant->toDateString();

        $presence = Presence::where('user_id', $user->id)->whereDate('date', $jour)->first();

        if (! $presence) {
            $presence = Presence::create([
                'user_id' => $user->id,
                'date' => $jour,
                'heure_arrivee' => $maintenant->format('H:i:s'),
                'mode' => 'biometrique',
            ]);

            return response()->json(['action' => 'arrivee', 'presence' => $presence], 201);
        }

        if ($presence->heure_depart) {
            return response()->json([
                'message' => 'Votre présence du jour est déjà complète (arrivée et départ enregistrés).',
            ], 422);
        }

        $arrivee = Carbon::parse($jour . ' ' . $presence->heure_arrivee);

        if ($maintenant->lt($arrivee->copy()->addMinutes(10))) {
            return response()->json([
                'message' => "Votre arrivée vient d'être enregistrée. Le départ pourra l'être dans quelques minutes.",
            ], 422);
        }

        $presence->update(['heure_depart' => $maintenant->format('H:i:s')]);

        return response()->json(['action' => 'depart', 'presence' => $presence->fresh()]);
    }
}