-- ============================================================
--  police_system/server/sv_dispatch.lua
--  Gestion des patrouilles et du dispatch
-- ============================================================

PS = PS or {}
PS.Dispatch = {}

-- Compteurs par type de patrouille pour nommer automatiquement
local patrolCounters = { lincoln = 0, adam = 0, tango = 0 }

-- Recharge les compteurs depuis la DB au démarrage
hook.Add("Initialize", "PS_Dispatch_Init", function()
    local rows = sql.Query("SELECT patrol_type, MAX(CAST(SUBSTR(patrol_name, INSTR(patrol_name,'-')+1) AS INTEGER)) as max_num FROM ps_patrols GROUP BY patrol_type") or {}
    for _, row in ipairs(rows) do
        local t = string.lower(row.patrol_type)
        patrolCounters[t] = tonumber(row.max_num) or 0
    end
end)

-- Génère le prochain nom de patrouille
local typePrefix = { lincoln = "Lincoln", adam = "Adam", tango = "Tango" }
local function NextPatrolName(ptype)
    patrolCounters[ptype] = (patrolCounters[ptype] or 0) + 1
    return string.format("%s-%02d", typePrefix[ptype] or ptype, patrolCounters[ptype])
end

-- Détermine le type selon le nombre de membres
local function PatrolTypeFromCount(count)
    if count == 1 then return "lincoln"
    elseif count == 2 then return "adam"
    else return "tango" end
end

-- Broadcast la liste des patrouilles aux policiers
function PS.Dispatch.BroadcastPatrols()
    local rows = PS.DB.GetAllPatrols()
    local json = PS.Utils.ToJSON(rows)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and PS.Utils.IsPolice(ply) then
            net.Start("PS_PatrolList")
                net.WriteString(json)
            net.Send(ply)
        end
    end
end

-- Création de patrouille
net.Receive("PS_PatrolCreate", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local json    = net.ReadString()
    local data    = PS.Utils.FromJSON(json)
    if not data or not data.members then return end

    local count   = #data.members
    if count < 1 then return end
    local ptype   = PatrolTypeFromCount(count)
    local pname   = NextPatrolName(ptype)
    local vehicle = data.vehicle or ""

    local id = PS.DB.CreatePatrol(ptype, pname, data.members, vehicle)
    PS.Dispatch.BroadcastPatrols()
end)

-- Mise à jour de statut / assignation
net.Receive("PS_PatrolUpdate", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local id   = net.ReadUInt(32)
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    PS.DB.UpdatePatrol(id, data)
    PS.Dispatch.BroadcastPatrols()
end)

-- Suppression de patrouille
net.Receive("PS_PatrolDelete", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local id = net.ReadUInt(32)
    PS.DB.DeletePatrol(id)
    PS.Dispatch.BroadcastPatrols()
end)

-- Demande de liste
net.Receive("PS_PatrolList", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local rows = PS.DB.GetAllPatrols()
    net.Start("PS_PatrolList")
        net.WriteString(PS.Utils.ToJSON(rows))
    net.Send(ply)
end)
