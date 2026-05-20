-- ============================================================
--  police_system/server/sv_census.lua
--  Recensement civil + casier judiciaire + casier agent + appel
-- ============================================================

-- ------- Recensement -------

net.Receive("PS_CensusAdd", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    if not data or not data.firstname or not data.lastname then return end

    local age      = tonumber(data.age) or 0
    local birth    = data.birthdate or ""
    local steamid  = data.steamid or ""

    PS.DB.AddCensus(steamid, data.firstname, data.lastname, age, birth, ply:SteamID())

    net.Start("PS_CensusResults")
        net.WriteString(PS.Utils.ToJSON({ success = true }))
    net.Send(ply)
end)

net.Receive("PS_CensusSearch", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local query   = net.ReadString()
    local results = PS.DB.SearchCensus(query)
    net.Start("PS_CensusResults")
        net.WriteString(PS.Utils.ToJSON(results))
    net.Send(ply)
end)

-- Amende : la personne doit être près du policier
net.Receive("PS_CensusAmend", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local censusId = net.ReadUInt(32)
    local amount   = net.ReadUInt(32)

    local entry = PS.DB.GetCensusById(censusId)
    if not entry then return end

    -- Cherche le joueur en ligne par steamid
    for _, target in ipairs(player.GetAll()) do
        if target:SteamID() == entry.steamid then
            if PS.Utils.Distance(ply, target) <= PS.Config.InteractionRange then
                -- DarkRP : retire l'argent
                if target.addMoney then target:addMoney(-amount) end
                ply:ChatPrint("[PS] Amende de " .. amount .. "$ appliquée à " .. target:Name())
            else
                ply:ChatPrint("[PS] Le suspect est trop loin.")
            end
            return
        end
    end
    ply:ChatPrint("[PS] Le suspect n'est pas connecté ou trop loin.")
end)

-- Emprisonnement
net.Receive("PS_CensusImprison", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local censusId = net.ReadUInt(32)
    local duration = net.ReadUInt(16)  -- minutes

    local entry = PS.DB.GetCensusById(censusId)
    if not entry then return end

    for _, target in ipairs(player.GetAll()) do
        if target:SteamID() == entry.steamid then
            if PS.Utils.Distance(ply, target) <= PS.Config.InteractionRange then
                -- DarkRP jail
                if target.setDarkRPVar then
                    target:setDarkRPVar("arrested", true)
                    timer.Simple(duration * 60, function()
                        if IsValid(target) then
                            target:setDarkRPVar("arrested", false)
                        end
                    end)
                end
                ply:ChatPrint("[PS] " .. target:Name() .. " mis en prison pour " .. duration .. " minutes.")
            else
                ply:ChatPrint("[PS] Le suspect est trop loin.")
            end
            return
        end
    end
    ply:ChatPrint("[PS] Suspect introuvable ou trop loin.")
end)

-- ------- Casier judiciaire -------

net.Receive("PS_RecordAdd", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    if not data or not data.censusId then return end

    PS.DB.AddCriminalRecord(
        data.censusId, data.offense or "Autre",
        data.date_str or "", data.time_str or "",
        data.details or "", ply:SteamID()
    )
    net.Start("PS_RecordData")
        net.WriteString(PS.Utils.ToJSON({ success = true }))
    net.Send(ply)
end)

net.Receive("PS_RecordGet", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local censusId = net.ReadUInt(32)
    local records  = PS.DB.GetCriminalRecords(censusId)
    net.Start("PS_RecordData")
        net.WriteString(PS.Utils.ToJSON(records))
    net.Send(ply)
end)

-- Suppression : lieutenant+
-- Le client envoie l'id de l'entrée de casier
net.Receive("PS_RecordDelete", function(_, ply)
    if not PS.Utils.IsLieutenantPlus(ply) then
        ply:ChatPrint("[PS] Seuls les lieutenants et au-dessus peuvent supprimer une entrée.")
        return
    end
    local recordId = net.ReadUInt(32)
    PS.DB.DeleteCriminalRecord(recordId)
end)

-- ------- Casier agent -------

net.Receive("PS_AgentNoteAdd", function(_, ply)
    if not PS.Utils.IsSergeantPlus(ply) then
        ply:ChatPrint("[PS] Accès refusé.")
        return
    end
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    if not data or not data.officerSteamid then return end

    PS.DB.AddAgentNote(data.officerSteamid, data.note_type or "note", data.content or "", ply:SteamID())
    net.Start("PS_AgentNoteData")
        net.WriteString(PS.Utils.ToJSON({ success = true }))
    net.Send(ply)
end)

net.Receive("PS_AgentNoteGet", function(_, ply)
    if not PS.Utils.IsSergeantPlus(ply) then return end
    local steamid = net.ReadString()
    local notes   = PS.DB.GetAgentNotes(steamid)
    net.Start("PS_AgentNoteData")
        net.WriteString(PS.Utils.ToJSON(notes))
    net.Send(ply)
end)

-- ------- Appel (roll-call) -------

net.Receive("PS_RollCallRequest", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    -- Renvoie la liste de tous les officiers (en service ou non)
    local officers = PS.DB.GetAllOfficers()
    net.Start("PS_RollCallData")
        net.WriteString(PS.Utils.ToJSON(officers))
    net.Send(ply)
end)

net.Receive("PS_RollCallMark", function(_, ply)
    if not PS.Utils.IsLieutenantPlus(ply) then
        ply:ChatPrint("[PS] Seuls les lieutenants et au-dessus peuvent marquer une absence.")
        return
    end
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    if not data or not data.steamid then return end

    local targetSteamid = data.steamid
    local present       = data.present

    if not present then
        -- Bannit du service pendant 5 min
        local until_ts = os.time() + PS.Config.AbsenceBanDuration
        PS.DB.SetAbsentBan(targetSteamid, until_ts)

        -- Retire du job si en ligne
        for _, target in ipairs(player.GetAll()) do
            if target:SteamID() == targetSteamid then
                if target.setDarkRPVar then
                    target:changeJob(team.GetName(GAMEMODE.defaultTeam or 0) or "Civilian")
                end
                target:ChatPrint("[PS] Vous avez été marqué absent au dispatch. Vous ne pouvez pas reprendre le service pendant " .. math.ceil(PS.Config.AbsenceBanDuration / 60) .. " minutes.")
                break
            end
        end

        -- Note dans le casier agent
        PS.DB.AddAgentNote(
            targetSteamid,
            "absence",
            "Absent au dispatch — " .. PS.Utils.FormatTime(),
            ply:SteamID()
        )
    end
end)
