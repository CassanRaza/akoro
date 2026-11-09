<?php

namespace Database\Seeders;

use App\Models\ConnaissanceAssistant;
use App\Models\Etablissement;
use Illuminate\Database\Seeder;

/**
 * Base de connaissances initiale de FAB'IA (cahier des charges + maquettes).
 * Ré-exécutable sans doublon : php artisan db:seed --class=ConnaissanceAssistantSeeder
 * Les fiches « a_valider » doivent être confirmées ou complétées par le FabManager.
 */
class ConnaissanceAssistantSeeder extends Seeder
{
    public function run(): void
    {
        $etab = Etablissement::where('nom', 'like', '%Hay Tao%')->first() ?? Etablissement::first();
        $etabId = $etab?->id;

        foreach ($this->fiches() as $i => $fiche) {
            ConnaissanceAssistant::updateOrCreate(
                ['etablissement_id' => $etabId, 'categorie' => $fiche['categorie'], 'titre' => $fiche['titre']],
                [
                    'contenu' => $fiche['contenu'],
                    'questions_types' => $fiche['questions'] ?? null,
                    'mots_cles' => $fiche['mots_cles'] ?? null,
                    'a_valider' => $fiche['a_valider'] ?? false,
                    'actif' => true,
                    'ordre' => $i + 1,
                ]
            );
        }
    }

    private function fiches(): array
    {
        return [
            // 1. Présentation du FabLab
            [
                'categorie' => 'presentation',
                'titre' => 'Le FabLab Solidaire Hay Tao',
                'questions' => 'C’est quoi le FabLab Hay Tao ? | Qui a créé le FabLab ? | Quelle est la mission du FabLab ?',
                'mots_cles' => 'fablab, hay tao, présentation, mission, partenaires, orange, auf, université',
                'contenu' => "Nom : FabLab Solidaire Hay Tao Fianarantsoa.\n"
                    ."Partenaires : Orange Solidarité Madagascar, l’AUF (Agence universitaire de la Francophonie) et l’Université de Fianarantsoa. "
                    ."L’Université a lancé la construction du bâtiment ; l’AUF a aidé à choisir et acquérir les machines et le mobilier.\n"
                    ."Mission : remobiliser, former au numérique et aider à l’insertion, notamment les jeunes qui ont interrompu leurs études. "
                    ."Le FabLab accompagne des projets de fabrication numérique, fait du mentorat et met l’atelier à disposition des entreprises locales pour fabriquer des prototypes.",
            ],
            [
                'categorie' => 'presentation',
                'titre' => 'Historique du FabLab',
                'questions' => 'Depuis quand le FabLab existe ? | Quand a-t-il ouvert ? | Combien de jeunes ont été retenus ?',
                'mots_cles' => 'historique, date, ouverture, openlab, création, candidatures, construction',
                'contenu' => "• Construction : de juin 2024 à mi-février 2025.\n"
                    ."• Février 2025 : sélection et formation de 3 formateurs et d’un FabManager.\n"
                    ."• 11 février 2025 : ouverture officielle avec un OpenLab, 124 visiteurs.\n"
                    ."• 17 avril 2025 : appel à candidatures, 132 candidatures reçues et 32 jeunes retenus pour une formation de 6 mois.",
            ],

            // 2. Localisation et accès
            [
                'categorie' => 'localisation',
                'titre' => 'Adresse du FabLab',
                'questions' => 'Où se trouve le FabLab ? | Quelle est l’adresse ?',
                'mots_cles' => 'adresse, où, lieu, localisation, accès, trouve, trouver, situe, situé, venir, aller, aiza, toerana, where, e-atiala, andrainjato, parc, plan',
                'a_valider' => true,
                'contenu' => "Lieu : parc e-atiala, Andrainjato, Fianarantsoa.\n"
                    ."À confirmer : le cahier des charges donne deux formulations du lieu ; la formulation exacte doit être validée par le FabManager. "
                    ."Indications d’accès (transport, repères) : non renseignées pour le moment.",
            ],

            // 3. Espaces
            [
                'categorie' => 'espaces',
                'titre' => 'Les espaces du FabLab',
                'questions' => 'Il y a quoi dans le FabLab ? | Où se fait la couture ? | Quelle est la surface ?',
                'mots_cles' => 'espace, salle, surface, m², couture, formation, machines, bureau, électronique, stockage, local technique',
                'contenu' => "Surface : 96,91 m².\n"
                    ."Espaces : espace de formation, espace couture, espace machines, bureau du FabManager, espace de conception électronique, espace de stockage et local technique.",
            ],

            // 4. Équipements
            [
                'categorie' => 'equipements',
                'titre' => 'Équipements disponibles',
                'questions' => 'Quelles machines sont disponibles ? | Est-ce qu’il y a une imprimante 3D ? | Il y a une découpeuse laser ?',
                'mots_cles' => 'machine, équipement, matériel, imprimante 3d, résine, filament, laser, cnc, couture, butterfly, broderie',
                'contenu' => "Machines disponibles :\n"
                    ."• découpeuse laser ;\n• CNC 4 axes ;\n• imprimante 3D résine ;\n• imprimante 3D à filament ;\n"
                    ."• machine à coudre Butterfly ;\n• machines de broderie numérique.",
            ],
            [
                'categorie' => 'equipements',
                'titre' => 'Utilisation et réservation des machines',
                'questions' => 'Comment réserver une machine ? | Faut-il une formation pour utiliser la découpeuse laser ? | Quelles sont les consignes de sécurité ?',
                'mots_cles' => 'réserver, réservation, utilisation, sécurité, consignes, formation machine, conditions',
                'a_valider' => true,
                'contenu' => "À compléter par le FabManager : conditions d’utilisation, modalités de réservation, consignes de sécurité et formation requise avant d’utiliser chaque machine. "
                    ."En attendant, il faut demander au FabManager via l’onglet Discussion avant toute utilisation.",
            ],

            // 5. Parcours
            [
                'categorie' => 'parcours',
                'titre' => 'Les parcours de formation',
                'questions' => 'Quels parcours existent ? | Combien de temps dure la formation ? | Combien de places ?',
                'mots_cles' => 'parcours, formation, filière, couture, artisanat numérique, électronique, programmation, durée, places, candidatures',
                'contenu' => "Parcours proposés : Couture, Artisanat numérique, Petite électronique et programmation.\n"
                    ."Durée de la formation : 6 mois.\n"
                    ."Places (appel 2025) : Couture 7 places pour 47 candidatures ; Artisanat numérique 15 places pour 37 candidatures ; Électronique 10 places pour 48 candidatures.\n"
                    ."Point fort : le parcours Couture est une particularité du FabLab, grâce à ses équipements textiles numériques (machine à coudre Butterfly, broderie numérique).",
            ],
            [
                'categorie' => 'parcours',
                'titre' => 'Contenu détaillé de chaque parcours',
                'questions' => 'C’est quoi mon parcours ? | Qui est mon formateur ? | Quels sont les objectifs ?',
                'mots_cles' => 'mon parcours, objectifs, contenu, programme, formateur, responsable',
                'a_valider' => true,
                'contenu' => "À compléter par parcours : objectifs, contenu et formateur responsable. "
                    ."Pour « Mon parcours », FAB’IA s’appuie sur le parcours enregistré dans le profil de l’utilisateur et sur les leçons et séances publiées dans AKORO.",
            ],

            // 6. Horaires
            [
                'categorie' => 'horaires',
                'titre' => 'Horaires d’ouverture et des parcours',
                'questions' => 'Quels sont les horaires de mon parcours ? | Le FabLab est ouvert le samedi ? | Quand sont les vacances ?',
                'mots_cles' => 'horaire, heure, ouvert, fermé, samedi, dimanche, vacances, planning, emploi du temps, séance',
                'a_valider' => true,
                'contenu' => "Les horaires officiels ne sont pas encore communiqués (les valeurs de la maquette sont fictives). "
                    ."Le FabManager doit fournir les horaires par parcours, les jours de fermeture et les périodes de vacances.\n"
                    ."En attendant, le planning précis de chaque parcours est celui des séances publiées dans AKORO.",
            ],

            // 7. Règlement et présence
            [
                'categorie' => 'reglement',
                'titre' => 'Pointage par QR code',
                'questions' => 'Comment je pointe ? | Comment enregistrer mon arrivée ? | Comment enregistrer mon départ ? | Où trouver le QR code ?',
                'mots_cles' => 'pointer, pointage, qr, code, scanner, scan, arrivée, départ, présence',
                'contenu' => "Le pointage se fait en scannant le QR code de la séance, affiché par le formateur pendant la séance. "
                    ."Dans l’application : Accueil → Présence → « Scanner le QR de la séance ». "
                    ."Le premier scan de la journée enregistre l’arrivée ; le second, au moins 10 minutes plus tard, enregistre le départ. "
                    ."Le QR est accepté de 30 minutes avant le début à 30 minutes après la fin de la séance, uniquement pour votre parcours. "
                    ."Si la caméra ne fonctionne pas, saisissez le code à 6 caractères affiché sous le QR. "
                    ."Sans scan pendant une séance, vous êtes marqué absent.",
            ],
            [
                'categorie' => 'reglement',
                'titre' => 'Absences et justificatifs',
                'questions' => 'Que faire si je suis absent ? | Comment justifier une absence ?',
                'mots_cles' => 'absence, absent, justifier, justificatif, motif, retard, validation',
                'contenu' => "Une absence est enregistrée automatiquement quand un bénéficiaire attendu ne pointe pas pendant une séance. "
                    ."Elle se justifie depuis l’application AKORO (rubrique des absences) en indiquant un motif ; l’administration valide ou refuse ensuite la justification. "
                    ."Une justification refusée peut être corrigée et renvoyée.",
            ],
            [
                'categorie' => 'reglement',
                'titre' => 'Règlement intérieur',
                'questions' => 'Quel est le règlement ? | Combien de retard est toléré ? | Que se passe-t-il si je suis souvent absent ?',
                'mots_cles' => 'règlement, règles, retard, tolérance, sanction, conséquences',
                'a_valider' => true,
                'contenu' => "À compléter par le FabManager : règlement intérieur, tolérance de retard et conséquences des absences.",
            ],

            // 8. Application AKORO
            [
                'categorie' => 'application',
                'titre' => 'Utiliser l’application AKORO',
                'questions' => 'Comment passer un quiz ? | Comment voir ma progression ? | Comment changer mon mot de passe ?',
                'mots_cles' => 'application, akoro, onglet, accueil, formations, discussion, assistant, quiz, profil, mot de passe, notifications',
                'contenu' => "L’application comporte 4 onglets : Accueil, Formations, Discussion et Assistant (FAB’IA).\n"
                    ."• Les quiz sont accessibles à la fin d’une leçon.\n"
                    ."• Discussion : conversation privée, groupe du parcours et groupe « Général FabLab ».\n"
                    ."• Profil : changement de mot de passe et réglage des notifications.",
            ],

            // 9. Contacts et services
            [
                'categorie' => 'contacts',
                'titre' => 'Contacter le FabManager',
                'questions' => 'Qui est le FabManager ? | Comment contacter le FabManager ?',
                'mots_cles' => 'fabmanager, contact, contacter, responsable, admin, joindre',
                'contenu' => "Le FabManager se contacte via l’onglet Discussion, en conversation privée : il est identifié par le badge « Admin ».",
            ],
            [
                'categorie' => 'contacts',
                'titre' => 'Services aux entreprises et coordonnées',
                'questions' => 'Comment réserver une machine pour un projet ? | Le FabLab fait du prototypage ? | Quel est le téléphone ? | Quels sont les tarifs ?',
                'mots_cles' => 'entreprise, prototype, prototypage, projet, tarif, prix, téléphone, email, service',
                'a_valider' => true,
                'contenu' => "Le FabLab met son atelier à disposition des entreprises locales pour fabriquer des prototypes et accompagne des projets de fabrication numérique.\n"
                    ."À compléter : téléphone, email, détail des services aux entreprises et tarifs éventuels.",
            ],
        ];
    }
}
