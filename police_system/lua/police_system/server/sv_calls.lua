-- ============================================================
--  police_system/server/sv_calls.lua
--  Gestion des appels / interventions + alertes tirs
-- ============================================================

PS = PS or {}
PS.Calls = {}

-- Broadcast tous les appels actifs + terminés récents
function PS.Calls.BroadcastCalls()
    local active   = PS.DB.GetActiveCalls()
    local finished = PS.DB.GetFinishedCalls()
    local json = PS.Utils.ToJSON({ active = active, finished = finished })
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and PS.Utils.IsPolice(ply) then
            net.Start("PS_CallList")
                net.WriteString(json)
            net.Send(ply)
        end
    end
end

-- Crée un appel et notifie tous les policiers
function PS.Calls.CreateAlert(callType, pos, description, srcPly)
    local id = PS.DB.CreateCall(callType, pos, description)
    PS.Calls.BroadcastCalls()

    -- Son d'alerte + message
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and PS.Utils.IsPolice(ply) then
            net.Start("PS_GunshotAlert")
                net.WriteUInt(id, 32)
                net.WriteString(callType)
                net.WriteVector(pos)
                net.WriteString(description)
            net.Send(ply)
        end
    end
    return id
end

-- Détection de tir d'arme à feu
hook.Add("EntityFireBullets", "PS_GunshotDetect", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    -- On ignore les policiers qui tirent
    if PS.Utils.IsPolice(ent) then return end
    -- Limite : pas plus d'un appel par joueur toutes les 15 secondes
    local key = "PS_Shot_" .. ent:SteamID()
    if PS.Calls[key] and PS.Calls[key] > CurTime() then return end
    PS.Calls[key] = CurTime() + 15

    local pos = ent:GetPos()
    PS.Calls.CreateAlert("gunshot", pos, "Coups de feu signalés — tireur : " .. ent:Name(), ent)
end)

-- En route pour un appel
net.Receive("PS_CallEnRoute", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local callId   = net.ReadUInt(32)
    local patrolId = net.ReadUInt(32)
    -- Récupère l'appel, ajoute la patrouille à la liste
    local rows = sql.Query("SELECT * FROM ps_calls WHERE id = " .. callId)
    if not rows or not rows[1] then return end
    local call = rows[1]
    local patrols = PS.Utils.FromJSON(call.patrols)
    if not table.HasValue(patrols, patrolId) then
        table.insert(patrols, patrolId)
    end
    PS.DB.UpdateCall(callId, { status = "en_route", patrols = patrols })
    PS.Calls.BroadcastCalls()

    -- Envoie les coords de l'appel aux membres de la patrouille
    local patrolRows = sql.Query("SELECT * FROM ps_patrols WHERE id = " .. patrolId)
    if patrolRows and patrolRows[1] then
        local members = PS.Utils.FromJSON(patrolRows[1].members)
        for _, uid in ipairs(members) do
            local member = Player(uid)
            if IsValid(member) then
                net.Start("PS_PatrolAssignCall")
                    net.WriteUInt(callId, 32)
                    net.WriteFloat(tonumber(call.position_x))
                    net.WriteFloat(tonumber(call.position_y))
                    net.WriteFloat(tonumber(call.position_z))
                net.Send(member)
            end
        end
    end
end)

-- Appel terminé
net.Receive("PS_CallFinish", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local callId = net.ReadUInt(32)
    PS.DB.UpdateCall(callId, { status = "finished", finished_at = tostring(os.time()) })
    PS.Calls.BroadcastCalls()
end)

-- Mise à jour d'un appel (statut général)
net.Receive("PS_CallUpdate", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local callId = net.ReadUInt(32)
    local json   = net.ReadString()
    local data   = PS.Utils.FromJSON(json)
    PS.DB.UpdateCall(callId, data)
    PS.Calls.BroadcastCalls()
end)

-- Demande liste
net.Receive("PS_CallList", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local active   = PS.DB.GetActiveCalls()
    local finished = PS.DB.GetFinishedCalls()
    net.Start("PS_CallList")
        net.WriteString(PS.Utils.ToJSON({ active = active, finished = finished }))
    net.Send(ply)
end)

-- Appel de détresse (F7)
net.Receive("PS_Distress", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local pos = ply:GetPos()
    PS.DB.AddDistress(ply:SteamID(), pos)

    -- Notifie tous les policiers
    local distress = PS.DB.GetActiveDistress()
    local json = PS.Utils.ToJSON(distress)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and PS.Utils.IsPolice(p) then
            net.Start("PS_DistressList")
                net.WriteString(json)
            net.Send(p)
        end
    end
end)

-- Annulation appel de détresse
net.Receive("PS_DistressClear", function(_, ply)
    PS.DB.ClearDistress(ply:SteamID())
    local distress = PS.DB.GetActiveDistress()
    local json = PS.Utils.ToJSON(distress)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and PS.Utils.IsPolice(p) then
            net.Start("PS_DistressList")
                net.WriteString(json)
            net.Send(p)
        end
    end
end)
