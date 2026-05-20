-- ============================================================
--  police_system/server/sv_commands.lua
--  Commandes console et chat pour les superadmins / chefs
-- ============================================================

-- !setrank <nom joueur> <grade>
-- Réservé aux superadmins : définir manuellement un grade
concommand.Add("ps_setrank", function(caller, _, args)
    if IsValid(caller) and not caller:IsSuperAdmin() then
        caller:ChatPrint("[PS] Accès refusé.")
        return
    end

    if #args < 2 then
        local msg = "[PS] Usage: ps_setrank <steamid ou nom partiel> <grade>"
        if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
        return
    end

    local query = table.concat(args, " ", 1, #args - 1)
    local rank  = args[#args]

    if not PS.Config.Ranks[rank] then
        local msg = "[PS] Grade inconnu : " .. rank .. ". Grades disponibles :"
        for k, v in pairs(PS.Config.Ranks) do
            msg = msg .. "\n  " .. k .. " = " .. v.label
        end
        if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
        return
    end

    -- Cherche par steamid d'abord, puis par nom
    local target = nil
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == query or string.find(string.lower(ply:Name()), string.lower(query)) then
            target = ply
            break
        end
    end

    if not IsValid(target) then
        -- Joueur hors ligne : on met à jour directement en DB
        PS.DB.UpdateOfficerRank(query, rank)
        local msg = "[PS] Grade DB mis à jour pour SteamID " .. query .. " → " .. rank
        if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
        return
    end

    PS.Grades.SetRank(target, rank, caller)
    local msg = "[PS] " .. target:Name() .. " → " .. rank
    if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
end)

-- !giveperm <nom/steamid> <permission>
concommand.Add("ps_giveperm", function(caller, _, args)
    if IsValid(caller) and not caller:IsSuperAdmin() then
        caller:ChatPrint("[PS] Accès refusé.")
        return
    end
    if #args < 2 then
        local msg = "[PS] Usage: ps_giveperm <nom ou steamid> <permission>"
        if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
        return
    end
    local perm  = args[#args]
    local query = table.concat(args, " ", 1, #args - 1)
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == query or string.find(string.lower(ply:Name()), string.lower(query)) then
            PS.Grades.GivePermission(ply, perm, caller)
            return
        end
    end
    -- Hors ligne : modifier directement en DB
    local perms = PS.DB.GetOfficerPermissions(query)
    if not table.HasValue(perms, perm) then table.insert(perms, perm) end
    PS.DB.SetOfficerPermissions(query, perms)
    local msg = "[PS] Permission '" .. perm .. "' accordée en DB pour " .. query
    if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
end)

-- !revokeperm <nom/steamid> <permission>
concommand.Add("ps_revokeperm", function(caller, _, args)
    if IsValid(caller) and not caller:IsSuperAdmin() then
        caller:ChatPrint("[PS] Accès refusé.")
        return
    end
    if #args < 2 then return end
    local perm  = args[#args]
    local query = table.concat(args, " ", 1, #args - 1)
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == query or string.find(string.lower(ply:Name()), string.lower(query)) then
            PS.Grades.RevokePermission(ply, perm, caller)
            return
        end
    end
end)

-- !listranks — liste tous les grades
concommand.Add("ps_listranks", function(caller, _, _)
    local lines = {"[PS] Grades disponibles :"}
    for k, v in SortedPairsByMemberValue(PS.Config.Ranks, "rank") do
        local div = v.division and (" [" .. v.division .. "]") or ""
        table.insert(lines, string.format("  %-20s — %s%s (rang %d)", k, v.label, div, v.rank))
    end
    local msg = table.concat(lines, "\n")
    if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
end)

-- Commande chat : !setrank
hook.Add("PlayerSay", "PS_ChatCommands", function(ply, text)
    local args = string.Explode(" ", text)
    local cmd  = string.lower(args[1] or "")

    if cmd == "!setrank" then
        if not PS.Utils.IsChief(ply) and not ply:IsSuperAdmin() then return end
        if #args < 3 then
            ply:ChatPrint("[PS] Usage: !setrank <nom> <grade>")
            return ""
        end
        local rank   = args[#args]
        local name   = table.concat(args, " ", 2, #args - 1)
        for _, target in ipairs(player.GetAll()) do
            if string.find(string.lower(target:Name()), string.lower(name)) then
                PS.Grades.SetRank(target, rank, ply)
                return ""
            end
        end
        ply:ChatPrint("[PS] Joueur introuvable.")
        return ""
    end

    if cmd == "!giveperm" then
        if not PS.Utils.IsChief(ply) and not ply:IsSuperAdmin() then return end
        if #args < 3 then return end
        local perm = args[#args]
        local name = table.concat(args, " ", 2, #args - 1)
        for _, target in ipairs(player.GetAll()) do
            if string.find(string.lower(target:Name()), string.lower(name)) then
                PS.Grades.GivePermission(target, perm, ply)
                return ""
            end
        end
        return ""
    end
end)
