<?php

namespace App\Support;

class Roles
{
    public const BENEFICIAIRE = 'beneficiaire';
    public const FORMATEUR = 'formateur';
    public const GERANT = 'gerant';
    public const FABMANAGER = 'fabmanager';
    public const ADMIN_GLOBAL = 'admin_global';

    // Tous les rôles d'administration
    public const ADMINS = ['formateur', 'gerant', 'fabmanager', 'admin_global'];

    // Rôles attribuables à un nouvel admin (le Super Admin est créé à la main)
    public const CHOISISSABLES = ['formateur', 'gerant', 'fabmanager'];

    // Rôles qui accèdent au tableau de bord et aux fiches détaillées des bénéficiaires
    public const COMPLETS = ['fabmanager', 'admin_global'];
}