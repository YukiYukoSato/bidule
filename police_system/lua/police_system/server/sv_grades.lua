-- ============================================================
--  police_system/server/sv_grades.lua
--  Gestion des grades / rangs côté serveur
-- ============================================================

PS = PS or {}
PS.Grades = {}

-- Met à jour le grade d'un joueur (en ligne)
function PS.Grades.SetRank(ply, rank, setter)
    if not PS.Config.Ranks[rank] then
        if IsValid(setter) then
            setter:ChatPrint("[PS] Grade inconnu : " .. rank)
        end
        return false
    end

    local steamid = ply:SteamID()
    PS.DB.UpdateOfficerRank(steamid, rank)
    ply:SetNWString("PS_Rank", rank)

    -- Notifie le joueur
    net.Start("PS_GradeUpdated")
        net.WriteString(rank)
    net.Send(ply)

    -- Log
    local setterName = IsValid(setter) and setter:Name() or "Console"
    local rankInfo = PS.Config.Ranks[rank]
    print(string.format("[PS] %s → grade %s (par %s)", ply:Name(), rankInfo.label, setterName))
    return true
end

-- Donne une permission spéciale à un joueur
function PS.Grades.GivePermission(target, permission, giver)
    local steamid = target:SteamID()
    local perms = PS.DB.GetOfficerPermissions(steamid)
    if not table.HasValue(perms, permission) then
        table.insert(perms, permission)
        PS.DB.SetOfficerPermissions(steamid, perms)
    end
    target:SetNWString("PS_Perms", PS.Utils.ToJSON(perms))
    if IsValid(giver) then
        giver:ChatPrint("[PS] Permission '" .. permission .. "' accordée à " .. target:Name())
    end
end

-- Retire une permission
function PS.Grades.RevokePermission(target, permission, revoker)
    local steamid = target:SteamID()
    local perms = PS.DB.GetOfficerPermissions(steamid)
    for i = #perms, 1, -1 do
        if perms[i] == permission then table.remove(perms, i) end
    end
    PS.DB.SetOfficerPermissions(steamid, perms)
    target:SetNWString("PS_Perms", PS.Utils.ToJSON(perms))
end

-- Appelé quand un policier prend son service
function PS.Grades.OnDuty(ply)
    local steamid = ply:SteamID()

    -- Vérifier le ban d'absence
    local officer = PS.DB.GetOfficer(steamid)
    if officer and tonumber(officer.absent_ban or 0) > os.time() then
        local remaining = math.ceil(tonumber(officer.absent_ban) - os.time())
        ply:ChatPrint(string.format("[PS] Vous êtes banni du service pendant encore %d secondes (absence injustifiée).", remaining))
        return false
    end

    -- Créer le profil si inexistant
    if not officer then
        local parts = string.Explode(" ", ply:Name())
        local fname  = parts[1] or "Inconnu"
        local lname  = table.concat(parts, " ", 2) or ""
        PS.DB.CreateOfficer(steamid, fname, lname)
        officer = PS.DB.GetOfficer(steamid)
    end

    PS.DB.UpdateOfficerDuty(steamid, true)
    ply:SetNWString("PS_Rank", officer.rank or PS.Config.DefaultRank)
    ply:SetNWString("PS_Perms", officer.permissions or "[]")
    ply:SetNWBool("PS_OnDuty", true)

    -- Met à jour tous les clients pour les blips
    PS.Grades.BroadcastOfficerList()
    return true
end

-- Appelé quand un policier quitte son service
function PS.Grades.OffDuty(ply)
    local steamid = ply:SteamID()
    PS.DB.UpdateOfficerDuty(steamid, false)
    PS.DB.ClearDistress(steamid)
    ply:SetNWBool("PS_OnDuty", false)
    PS.Grades.BroadcastOfficerList()
end

-- Broadcast la liste des officiers en service à tous les policiers
function PS.Grades.BroadcastOfficerList()
    local list = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetNWBool("PS_OnDuty", false) then
            local pos = ply:GetPos()
            table.insert(list, {
                steamid   = ply:SteamID(),
                name      = ply:Name(),
                rank      = ply:GetNWString("PS_Rank", PS.Config.DefaultRank),
                pos_x     = pos.x,
                pos_y     = pos.y,
                pos_z     = pos.z,
                userid    = ply:UserID(),
            })
        end
    end

    local json = PS.Utils.ToJSON(list)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and PS.Utils.IsPolice(ply) then
            net.Start("PS_OfficersList")
                net.WriteString(json)
            net.Send(ply)
        end
    end
end

-- Réception : demande de mise en service
net.Receive("PS_OnDuty", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    PS.Grades.OnDuty(ply)
end)

net.Receive("PS_OffDuty", function(_, ply)
    PS.Grades.OffDuty(ply)
end)

-- Réception : demande de données personnelles
net.Receive("PS_GetMyData", function(_, ply)
    local steamid = ply:SteamID()
    local officer = PS.DB.GetOfficer(steamid)
    if not officer then
        -- Crée un profil vide basé sur le nom du joueur
        local parts = string.Explode(" ", ply:Name())
        local fname  = parts[1] or "Inconnu"
        local lname  = table.concat(parts, " ", 2) or ""
        PS.DB.CreateOfficer(steamid, fname, lname)
        officer = PS.DB.GetOfficer(steamid)
    end
    net.Start("PS_MyData")
        net.WriteString(PS.Utils.ToJSON(officer))
    net.Send(ply)
end)

-- Réception : un chef change le grade d'un agent
net.Receive("PS_SetGrade", function(_, ply)
    if not PS.Utils.IsChief(ply) and not ply:IsSuperAdmin() then
        return
    end
    local targetUID = net.ReadUInt(16)
    local rank      = net.ReadString()
    local target    = Player(targetUID)
    if not IsValid(target) then return end
    PS.Grades.SetRank(target, rank, ply)
end)

-- Réception : donner permission spéciale
net.Receive("PS_AdminGivePermission", function(_, ply)
    if not PS.Utils.IsChief(ply) and not ply:IsSuperAdmin() then return end
    local targetUID  = net.ReadUInt(16)
    local permission = net.ReadString()
    local target     = Player(targetUID)
    if not IsValid(target) then return end
    PS.Grades.GivePermission(target, permission, ply)
end)

-- Màj périodique des blips toutes les 3 secondes
timer.Create("PS_BlipsUpdate", 3, 0, function()
    PS.Grades.BroadcastOfficerList()
end)

-- Quand un joueur quitte
hook.Add("PlayerDisconnected", "PS_OffDutyOnDisconnect", function(ply)
    if IsValid(ply) then
        PS.Grades.OffDuty(ply)
    end
end)
