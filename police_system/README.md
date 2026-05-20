# Police System — Addon Garry's Mod

Addon complet pour les serveurs de roleplay policier sous Garry's Mod (compatible DarkRP et frameworks similaires).

---

## Fonctionnalités

### 🔫 Armurier PNJ (`npc_armorer`)
- PNJ invincible spawnable en jeu (`ps_spawnarmorer` en console — superadmin uniquement)
- Dialogue en `USE` (touche `E`) : accessible uniquement aux policiers
- 4 catégories d'articles :
  | Catégorie | Accès |
  |---|---|
  | Kevlar / Protection | Tous les policiers |
  | Armes de poing | Tous les policiers |
  | Armes lourdes | Lieutenant et au-dessus |
  | Sniper | Unité Spéciale uniquement |
- Prise en compte du portefeuille DarkRP (retire l'argent automatiquement)

---

### 🪪 Système de grades
Les grades sont définis dans `lua/police_system/config/sh_config.lua`.

| Clé | Nom | Rang | Armes lourdes | Sniper |
|---|---|---|---|---|
| `officer` | Officier | 1 | ✗ | ✗ |
| `corporal` | Caporal | 2 | ✗ | ✗ |
| `sergeant` | Sergent | 3 | ✗ | ✗ |
| `lieutenant` | Lieutenant | 4 | ✓ | ✗ |
| `captain` | Capitaine | 5 | ✓ | ✗ |
| `commander` | Commandant | 6 | ✓ | ✗ |
| `chief` | Chef de la Police | 7 | ✓ | ✗ |
| `special_unit` | Unité Spéciale | 4 | ✓ | ✓ |
| `special_leader` | Chef Unité Spéciale | 5 | ✓ | ✓ |
| `k9_officer` | Officier K9 | 2 | ✗ | ✗ |
| `k9_sergeant` | Sergent K9 | 3 | ✗ | ✗ |
| `mcd_analyst` | Analyste MCD | 2 | ✗ | ✗ |
| `mcd_chief` | Chef MCD | 3 | ✗ | ✗ |
| `crime_agent` | Agent Crime | 2 | ✗ | ✗ |
| `crime_chief` | Chef Crime | 3 | ✗ | ✗ |

---

### 📱 Tablette Police (touche `F6`)
Interface entièrement personnalisée avec animations, curseur interactif et transitions.

#### Onglets disponibles

| Onglet | Description |
|---|---|
| **🗺 Carte** | Minimap en direct : blips de tous les officiers en service, appels actifs, SOS, appel assigné à votre patrouille |
| **📡 Dispatch** | Gestion des patrouilles (Lincoln / Adam / Tango), statuts, liste des appels actifs/terminés |
| **📋 Recensement** | Enregistrer / rechercher des personnes, amender ou emprisonner (DarkRP), ouvrir le casier |
| **🗂 Casiers** | Casier judiciaire par personne avec infractions, date, heure et détails |
| **📞 Appel** | Liste de tous les officiers avec leur statut, marquage présent/absent (lieutenant+) |
| **👮 Profil Agent** | Casier interne de l'agent : notes et avertissements (sergent+) |

#### Prise / fin de service
Depuis l'onglet **Carte**, un bouton **"Prendre le service / Quitter le service"** gère la visibilité sur la minimap et restaure le grade précédent.

---

### 📡 Dispatch — Patrouilles

| Nombre de membres | Nom de type | Numérotation |
|---|---|---|
| 1 | Lincoln | Lincoln-01, Lincoln-02… |
| 2 | Adam | Adam-01, Adam-02… |
| 3+ | Tango | Tango-01, Tango-02… |

Chaque patrouille peut avoir les statuts : **Disponible**, **Indisponible**, **En procédure**, **Au poste**, **En pause**.

Quand une patrouille est assignée à un appel (bouton **"En route"**), tous les membres voient :
- Un bleu sur la minimap avec flèche
- Un **indicateur 3D** dans le monde indiquant la distance à l'intervention en mètres

---

### 🚨 Détresse (touche `F7`)
- Envoie un SOS visible sur la carte de tous les collègues
- Indicateur 3D visible en tournant la caméra (distance en mètres)
- Appuyer à nouveau annule le SOS

---

### 🔫 Alerte coups de feu automatique
Dès qu'un **civil** (non-policier) tire avec une arme à feu, une alerte est générée :
- Son d'alerte (`buttons/button15.wav`) sur toutes les tablettes policières
- Blip rouge sur la carte
- Indicateur 3D dans le monde
- L'alerte est cooldownée à 15 secondes par joueur

---

### 🗃 Base de données (SQLite)
Les tables suivantes sont créées automatiquement au premier démarrage :

| Table | Contenu |
|---|---|
| `ps_officers` | Profil des officiers (grade, permissions, ban) |
| `ps_patrols` | Patrouilles actives |
| `ps_calls` | Appels / interventions |
| `ps_census` | Personnes recensées |
| `ps_criminal_records` | Casiers judiciaires |
| `ps_agent_notes` | Notes / avertissements agents |
| `ps_distress` | Appels de détresse actifs |

---

## Installation

1. Placer le dossier `police_system/` dans `garrysmod/addons/`
2. Redémarrer le serveur
3. Configurer les jobs dans `lua/police_system/config/sh_config.lua` (tableau `PS.Config.PoliceJobs`)

---

## Commandes

| Commande | Accès | Description |
|---|---|---|
| `ps_setrank <nom> <grade>` | SuperAdmin + console | Définit le grade d'un joueur (en ligne ou hors ligne via SteamID) |
| `ps_giveperm <nom> <permission>` | SuperAdmin + console | Donne une permission spéciale |
| `ps_revokeperm <nom> <permission>` | SuperAdmin + console | Retire une permission |
| `ps_listranks` | SuperAdmin + console | Liste tous les grades disponibles |
| `ps_spawnarmorer` | SuperAdmin | Spawn l'armurier devant soi |
| `!setrank <nom> <grade>` | Chef de la Police (chat) | Change le grade d'un agent en service |
| `!giveperm <nom> <permission>` | Chef de la Police (chat) | Donne une permission |

---

## Touches

| Touche | Action |
|---|---|
| `F6` | Ouvrir / fermer la tablette |
| `F7` | Envoyer / annuler un appel de détresse |
| `E` | Interagir avec l'armurier |

*(Configurable dans `sh_config.lua` : `PS.Config.TabletKey` et `PS.Config.DistressKey`)*

---

## Permissions spéciales

Les permissions se stockent en JSON dans `ps_officers.permissions`.

| Permission | Usage |
|---|---|
| `sniper` | Accès aux snipers à l'armurier |
| Tout autre string | Extensible pour vos propres systèmes |

---

## Configuration rapide

Fichier `lua/police_system/config/sh_config.lua` :

```lua
-- Noms des jobs DarkRP reconnus comme policiers
PS.Config.PoliceJobs = { "police", "officer", "cop" }

-- Durée du ban d'absence (secondes)
PS.Config.AbsenceBanDuration = 300

-- Distance pour amender / emprisonner (unités Hammer)
PS.Config.InteractionRange = 300
```

---

## Structure des fichiers

```
police_system/
├── addon.txt
└── lua/
    ├── autorun/
    │   └── police_system.lua           ← Chargeur principal
    ├── entities/
    │   └── npc_armorer/
    │       ├── shared.lua
    │       ├── init.lua                ← Serveur
    │       └── cl_init.lua             ← Client
    └── police_system/
        ├── config/
        │   └── sh_config.lua           ← ✏️ CONFIGURER ICI
        ├── shared/
        │   ├── sh_utils.lua
        │   └── sh_net.lua
        ├── server/
        │   ├── sv_database.lua
        │   ├── sv_grades.lua
        │   ├── sv_dispatch.lua
        │   ├── sv_calls.lua
        │   ├── sv_census.lua
        │   └── sv_commands.lua
        └── client/
            ├── cl_armorer_menu.lua
            ├── cl_tablet.lua
            ├── cl_tablet_map.lua
            ├── cl_tablet_dispatch.lua
            ├── cl_tablet_census.lua
            ├── cl_tablet_records.lua
            ├── cl_tablet_rollcall.lua
            ├── cl_tablet_agent_record.lua
            └── cl_distress.lua
```
