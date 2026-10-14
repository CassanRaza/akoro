<?php

namespace App\Support;

use Illuminate\Http\Request;

class Rules
{
    /** Nettoie les champs avant validation : espaces en trop retirés, email en minuscules et sans espace. */
    public static function clean(Request $request): void
    {
        $clean = [];

        foreach (['nom', 'titre', 'adresse', 'telephone'] as $field) {
            if (is_string($request->input($field))) {
                $clean[$field] = preg_replace('/\s+/u', ' ', trim($request->input($field)));
            }
        }

        if (is_string($request->input('email'))) {
            $clean['email'] = mb_strtolower(preg_replace('/\s+/u', '', $request->input('email')));
        }

        if ($clean) {
            $request->merge($clean);
        }
    }

    /** Nom et prénoms d'une personne : lettres, espaces simples, tirets et apostrophes uniquement. */
    public static function nomPersonne(): array
    {
        return ['bail', 'required', 'string', 'min:2', 'max:100', 'regex:/^\p{L}+(?:[ \'’\-]\p{L}+)*$/u'];
    }

    /** Libellé (nom de parcours, titre de leçon) : lettres, chiffres, espaces simples, tirets, apostrophes, & . ( ) */
    public static function libelle(): array
    {
        return ['bail', 'required', 'string', 'min:2', 'max:100', 'regex:/^[\p{L}\p{N}][\p{L}\p{N} \'’\-&.()]*$/u'];
    }

    /** Email : doit contenir @ et un domaine avec un point, sans espace. */
    public static function email(bool $unique = false): array
    {
        $rules = ['bail', 'required', 'string', 'max:255', 'email:rfc', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/'];

        if ($unique) {
            $rules[] = 'unique:users,email';
        }

        return $rules;
    }

    /** Téléphone : chiffres et espaces, + possible au début, entre 9 et 15 chiffres. */
    public static function telephone(): array
    {
        return [
            'bail',
            'required',
            'string',
            'max:20',
            'regex:/^\+?\d[\d ]*\d$/',
            function (string $attribute, mixed $value, \Closure $fail) {
                $chiffres = strlen(preg_replace('/\D/', '', $value));

                if ($chiffres < 9 || $chiffres > 15) {
                    $fail('Le numéro de téléphone doit contenir entre 9 et 15 chiffres.');
                }
            },
        ];
    }

    /** Adresse : lettres, chiffres, espaces et , . - ' / ( ) uniquement. */
    public static function adresse(): array
    {
        return ['bail', 'required', 'string', 'min:5', 'max:150', 'regex:/^[\p{L}\p{N}][\p{L}\p{N} ,.\'’\-\/()°]*$/u'];
    }

    /** Photo de profil facultative : JPG, PNG ou WEBP, 2 Mo maximum. */
    public static function photo(): array
    {
        return ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'];
    }

    /** Mot de passe : 8 à 64 caractères, au moins une lettre et un chiffre, sans espace. */
    public static function password(bool $confirm = false): array
    {
        $rules = ['bail', 'required', 'string', 'min:8', 'max:64', 'regex:/^(?=.*\p{L})(?=.*\p{N})\S+$/u'];

        if ($confirm) {
            $rules[] = 'confirmed';
        }

        return $rules;
    }

    /** Extensions autorisées pour les documents d'une leçon. */
    public static function extensionsFichier(): array
    {
        return [
            'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt',
            'ppt', 'pptx', 'odp',
            'xls', 'xlsx', 'ods', 'csv',
            'jpg', 'jpeg', 'png', 'webp', 'gif',
            'zip',
            'stl', 'dxf', 'svg', 'ino',
        ];
    }

    /** Document de leçon : extension autorisée, 20 Mo maximum, un PDF doit être un vrai PDF. */
    public static function fichier(): array
    {
        return [
            'bail',
            'required',
            'file',
            'max:20480',
            function (string $attribute, mixed $value, \Closure $fail) {
                $extension = strtolower($value->getClientOriginalExtension());

                if (! in_array($extension, self::extensionsFichier(), true)) {
                    $fail('Format non autorisé. Formats acceptés : Word, PowerPoint, Excel, PDF, images, ZIP, STL, DXF, SVG, INO.');
                    return;
                }

                if ($extension === 'pdf' && $value->getMimeType() !== 'application/pdf') {
                    $fail("Ce fichier n'est pas un PDF valide.");
                }
            },
        ];
    }

    /** Messages d'erreur en français (personnes, contacts, email, mot de passe, photo). */
    public static function messages(): array
    {
        return [
            'nom.required' => 'Le nom et prénoms sont obligatoires.',
            'nom.min' => 'Le nom est trop court (2 caractères minimum).',
            'nom.max' => 'Le nom est trop long (100 caractères maximum).',
            'nom.regex' => 'Le nom ne doit contenir que des lettres, espaces, tirets ou apostrophes (pas de chiffres ni de symboles comme ; , : @).',

            'email.required' => "L'adresse email est obligatoire.",
            'email.email' => "L'adresse email n'est pas valide (elle doit contenir @).",
            'email.regex' => "L'adresse email n'est pas valide (exemple : nom@domaine.mg).",
            'email.max' => "L'adresse email est trop longue.",
            'email.unique' => 'Cette adresse email est déjà utilisée.',

            'telephone.required' => 'Le numéro de téléphone est obligatoire.',
            'telephone.max' => 'Le numéro de téléphone est trop long.',
            'telephone.regex' => 'Le numéro de téléphone ne doit contenir que des chiffres, des espaces et un + au début.',

            'adresse.required' => "L'adresse est obligatoire.",
            'adresse.min' => "L'adresse est trop courte (5 caractères minimum).",
            'adresse.max' => "L'adresse est trop longue (150 caractères maximum).",
            'adresse.regex' => "L'adresse contient des caractères non autorisés (lettres, chiffres, espaces et , . - ' / ( ) seulement).",

            'role.required' => 'Veuillez choisir un rôle.',
            'role.in' => 'Rôle invalide.',

            'password.required' => 'Le mot de passe est obligatoire.',
            'password.min' => 'Le mot de passe doit contenir au moins 8 caractères.',
            'password.max' => 'Le mot de passe est trop long (64 caractères maximum).',
            'password.regex' => 'Le mot de passe doit contenir au moins une lettre et un chiffre, sans espace.',
            'password.confirmed' => 'La confirmation ne correspond pas au mot de passe.',

            'photo.required' => 'Veuillez choisir une photo.',
            'photo.image' => 'Le fichier doit être une image.',
            'photo.mimes' => 'Formats acceptés : JPG, PNG ou WEBP.',
            'photo.max' => 'La photo est trop volumineuse (2 Mo maximum).',
            'photo.uploaded' => "La photo n'a pas pu être envoyée (trop volumineuse pour le serveur).",

            'etablissement_id.required' => 'Veuillez choisir un établissement.',
            'etablissement_id.exists' => 'Établissement introuvable.',
            'parcours_id.required' => 'Veuillez choisir un parcours.',
            'parcours_id.exists' => "Ce parcours n'existe pas dans cet établissement.",
        ];
    }

    /** Messages d'erreur en français (parcours). */
    public static function messagesLibelle(): array
    {
        return [
            'nom.required' => 'Le nom du parcours est obligatoire.',
            'nom.min' => 'Le nom du parcours est trop court (2 caractères minimum).',
            'nom.max' => 'Le nom du parcours est trop long (100 caractères maximum).',
            'nom.regex' => 'Le nom du parcours contient des caractères non autorisés (seuls les lettres, chiffres, espaces, tirets, apostrophes, & . ( ) sont acceptés).',
            'nom.unique' => 'Un parcours porte déjà ce nom.',
            'description.max' => 'La description est trop longue (500 caractères maximum).',
        ];
    }

    /** Messages d'erreur en français (leçons). */
    public static function messagesTitre(): array
    {
        return [
            'titre.required' => 'Le titre de la leçon est obligatoire.',
            'titre.min' => 'Le titre de la leçon est trop court (2 caractères minimum).',
            'titre.max' => 'Le titre de la leçon est trop long (100 caractères maximum).',
            'titre.regex' => 'Le titre de la leçon contient des caractères non autorisés (seuls les lettres, chiffres, espaces, tirets, apostrophes, & . ( ) sont acceptés).',
            'titre.unique' => 'Une leçon porte déjà ce titre dans ce parcours.',
            'description.max' => 'La description est trop longue (1000 caractères maximum).',
        ];
    }

    /** Messages d'erreur en français (envoi de fichiers). */
    public static function messagesFichier(): array
    {
        return [
            'fichier.required' => 'Veuillez choisir un fichier.',
            'fichier.file' => 'Le fichier envoyé est invalide.',
            'fichier.max' => 'Le fichier est trop volumineux (20 Mo maximum).',
            'fichier.uploaded' => "Le fichier n'a pas pu être envoyé (trop volumineux pour le serveur).",
        ];
    }

    /** Messages d'erreur en français (séances). */
    public static function messagesSeance(): array
    {
        return [
            'lecon_id.exists' => "Cette leçon n'appartient pas à ce parcours.",
            'date.required' => 'La date est obligatoire.',
            'date.date_format' => 'Date invalide.',
            'date.after_or_equal' => 'La date ne peut pas être dans le passé.',
            'heure_debut.required' => "L'heure de début est obligatoire.",
            'heure_debut.date_format' => "Heure de début invalide (format HH:MM).",
            'heure_fin.required' => "L'heure de fin est obligatoire.",
            'heure_fin.date_format' => "Heure de fin invalide (format HH:MM).",
            'heure_fin.after' => "L'heure de fin doit être après l'heure de début.",
        ];
    }
}