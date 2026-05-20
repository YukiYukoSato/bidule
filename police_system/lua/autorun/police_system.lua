-- ============================================================
--  police_system/autorun/police_system.lua
--  Point d'entrée principal — charge tous les fichiers dans le
--  bon ordre (shared → server → client)
-- ============================================================

-- Table globale de l'addon
PS = PS or {}

local BASE = "police_system/"

-- Fonction utilitaire : inclut un fichier côté approprié
local function Include(path)
    local full = BASE .. path
    if SERVER then
        if string.sub(path, 1, 3) == "cl_" then
            AddCSLuaFile(full)
        else
            include(full)
        end
    elseif CLIENT then
        include(full)
    end
end

local function IncludeShared(path)
    local full = BASE .. path
    if SERVER then AddCSLuaFile(full) end
    include(full)
end

local function IncludeServer(path)
    if SERVER then include(BASE .. path) end
end

local function IncludeClient(path)
    local full = BASE .. path
    if SERVER then
        AddCSLuaFile(full)
    else
        include(full)
    end
end

-- -------------------------------------------------------
--  1. Config & Shared
-- -------------------------------------------------------
IncludeShared("config/sh_config.lua")
IncludeShared("shared/sh_utils.lua")
IncludeShared("shared/sh_net.lua")

-- -------------------------------------------------------
--  2. Serveur
-- -------------------------------------------------------
IncludeServer("server/sv_database.lua")
IncludeServer("server/sv_grades.lua")
IncludeServer("server/sv_dispatch.lua")
IncludeServer("server/sv_calls.lua")
IncludeServer("server/sv_census.lua")
IncludeServer("server/sv_commands.lua")

-- -------------------------------------------------------
--  3. Client
-- -------------------------------------------------------
IncludeClient("client/cl_armorer_menu.lua")
IncludeClient("client/cl_tablet.lua")
IncludeClient("client/cl_tablet_map.lua")
IncludeClient("client/cl_tablet_dispatch.lua")
IncludeClient("client/cl_tablet_census.lua")
IncludeClient("client/cl_tablet_records.lua")
IncludeClient("client/cl_tablet_rollcall.lua")
IncludeClient("client/cl_tablet_agent_record.lua")
IncludeClient("client/cl_distress.lua")

-- -------------------------------------------------------
--  4. Initialisation DB (serveur uniquement)
-- -------------------------------------------------------
if SERVER then
    hook.Add("Initialize", "PS_DBInit", function()
        PS.DB.Init()
    end)

    -- Quand un joueur rejoint : restaure ses données
    hook.Add("PlayerInitialSpawn", "PS_RestoreOfficer", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end
            local steamid = ply:SteamID()
            local officer = PS.DB.GetOfficer(steamid)
            if officer then
                ply:SetNWString("PS_Rank",  officer.rank or PS.Config.DefaultRank)
                ply:SetNWString("PS_Perms", officer.permissions or "[]")
                -- Restaure le ban d'absence si actif
                local ban = tonumber(officer.absent_ban or 0)
                if ban > os.time() then
                    ply:SetNWBool("PS_AbsentBanned", true)
                end
            end
        end)
    end)
end
