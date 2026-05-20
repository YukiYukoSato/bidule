-- ============================================================
--  police_system/config/sh_config.lua
--  Configuration générale du système de police
-- ============================================================

PS = PS or {}
PS.Config = {}

-- Touche d'ouverture de la tablette
PS.Config.TabletKey        = KEY_F6
-- Touche d'appel de détresse
PS.Config.DistressKey      = KEY_F7

-- Job DarkRP associé à la police (peut en mettre plusieurs)
PS.Config.PoliceJobs = {
    "police",
    "policeofficer",
    "officer",
    "cop",
}

-- Le niveau de grade minimum pour accéder aux armes lourdes
PS.Config.HeavyWeaponMinRank  = "lieutenant"
-- Le niveau de grade pour les snipers (unité spéciale uniquement)
PS.Config.SniperPermission    = "special_unit"

-- Durée de bannissement temporaire du job après absence (secondes)
PS.Config.AbsenceBanDuration  = 300  -- 5 minutes

-- Distance max pour amender / emprisonner un recensé (unités Hammer)
PS.Config.InteractionRange    = 300

-- Son joué lors d'une nouvelle alerte
PS.Config.AlertSound = "buttons/button15.wav"

-- Couleurs UI tablette
PS.Config.Colors = {
    Background  = Color( 15,  20,  35, 240 ),
    Header      = Color( 20,  30,  55, 255 ),
    Accent      = Color( 40, 120, 200, 255 ),
    AccentHover = Color( 55, 150, 230, 255 ),
    Text        = Color(220, 230, 245, 255 ),
    TextDim     = Color(150, 165, 185, 255 ),
    Success     = Color( 50, 180,  80, 255 ),
    Warning     = Color(220, 160,  30, 255 ),
    Danger      = Color(200,  50,  50, 255 ),
    PanelBg     = Color( 22,  30,  50, 255 ),
    PanelBorder = Color( 40,  60,  95, 255 ),
}

-- ============================================================
--  Grades / Rangs
--  Chaque grade a :
--    label    : nom affiché
--    rank     : index numérique (plus grand = plus haut gradé)
--    division : nil = Police générale, sinon division spéciale
--    heavy    : peut porter des armes lourdes
--    sniper   : peut porter un sniper
-- ============================================================
PS.Config.Ranks = {
    -- Police générale
    ["officer"]        = { label = "Officier",          rank = 1,  heavy = false, sniper = false },
    ["corporal"]       = { label = "Caporal",            rank = 2,  heavy = false, sniper = false },
    ["sergeant"]       = { label = "Sergent",            rank = 3,  heavy = false, sniper = false },
    ["lieutenant"]     = { label = "Lieutenant",         rank = 4,  heavy = true,  sniper = false },
    ["captain"]        = { label = "Capitaine",          rank = 5,  heavy = true,  sniper = false },
    ["commander"]      = { label = "Commandant",         rank = 6,  heavy = true,  sniper = false },
    ["chief"]          = { label = "Chef de la Police",  rank = 7,  heavy = true,  sniper = false },

    -- Unité Spéciale
    ["special_unit"]   = { label = "Unité Spéciale",     rank = 4,  heavy = true,  sniper = true,  division = "special" },
    ["special_leader"] = { label = "Chef Unité Spéciale",rank = 5,  heavy = true,  sniper = true,  division = "special" },

    -- K9
    ["k9_officer"]     = { label = "Officier K9",        rank = 2,  heavy = false, sniper = false, division = "k9" },
    ["k9_sergeant"]    = { label = "Sergent K9",         rank = 3,  heavy = false, sniper = false, division = "k9" },

    -- MCD (analyses)
    ["mcd_analyst"]    = { label = "Analyste MCD",       rank = 2,  heavy = false, sniper = false, division = "mcd" },
    ["mcd_chief"]      = { label = "Chef MCD",           rank = 3,  heavy = false, sniper = false, division = "mcd" },

    -- Crime (criminologie / analyses de balles)
    ["crime_agent"]    = { label = "Agent Crime",        rank = 2,  heavy = false, sniper = false, division = "crime" },
    ["crime_chief"]    = { label = "Chef Crime",         rank = 3,  heavy = false, sniper = false, division = "crime" },
}

-- Grade par défaut lors de la première prise de service
PS.Config.DefaultRank = "officer"

-- ============================================================
--  Catalogue armurier
-- ============================================================
PS.Config.ArmoryCatalog = {
    kevlar = {
        label = "Kevlar / Protection",
        items = {
            { label = "Gilet pare-balles léger",  weapon = nil, armor = 50,  price = 500  },
            { label = "Gilet pare-balles lourd",  weapon = nil, armor = 100, price = 1000 },
        }
    },
    handguns = {
        label = "Armes de poing",
        items = {
            { label = "Pistolet 9mm",  weapon = "weapon_pistol",   price = 800  },
            { label = "Pistolet .357", weapon = "weapon_357",      price = 1200 },
        }
    },
    heavy = {
        label = "Armes lourdes",
        minRank = "lieutenant",
        items = {
            { label = "MP5",        weapon = "weapon_smg1",        price = 2000 },
            { label = "Fusil à pompe", weapon = "weapon_shotgun",  price = 2500 },
            { label = "AR2",        weapon = "weapon_ar2",         price = 3000 },
        }
    },
    sniper = {
        label = "Sniper",
        permission = "sniper",
        items = {
            { label = "Fusil de sniper", weapon = "weapon_crossbow", price = 4000 },
        }
    },
}

-- ============================================================
--  Liste des infractions disponibles pour le casier judiciaire
-- ============================================================
PS.Config.Offenses = {
    "Agression simple",
    "Agression avec arme",
    "Homicide involontaire",
    "Homicide volontaire",
    "Vol à la tire",
    "Vol avec effraction",
    "Braquage",
    "Trafic de drogue",
    "Possession de drogue",
    "Port d'arme illégal",
    "Résistance à l'arrestation",
    "Évasion",
    "Corruption",
    "Rébellion",
    "Dégradation de biens publics",
    "Conduite en état d'ivresse",
    "Mise en danger de la vie d'autrui",
    "Association de malfaiteurs",
    "Recel",
    "Autre",
}
