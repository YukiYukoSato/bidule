-- ============================================================
--  police_system/client/cl_tablet_dispatch.lua
--  Onglet Dispatch — patrouilles, appels, appels de détresse
-- ============================================================

PS = PS or {}
PS.TabletDispatch = {}

local STATUSES = {
    { key = "available",    label = "Disponible",    color = Color(50,180,80)   },
    { key = "unavailable",  label = "Indisponible",  color = Color(180,50,50)   },
    { key = "procedure",    label = "En procédure",  color = Color(200,120,20)  },
    { key = "station",      label = "Au poste",      color = Color(80,80,200)   },
    { key = "break",        label = "En pause",      color = Color(150,150,50)  },
}

local function StatusColor(key)
    for _, s in ipairs(STATUSES) do
        if s.key == key then return s.color end
    end
    return Color(120,120,120)
end

local function StatusLabel(key)
    for _, s in ipairs(STATUSES) do
        if s.key == key then return s.label end
    end
    return key or "?"
end

function PS.TabletDispatch.Build(parent)
    local W, H = parent:GetSize()

    -- Panneau gauche : patrouilles
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetPos(8, 8)
    leftPanel:SetSize(math.floor(W * 0.45) - 12, H - 16)
    leftPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText("PATROUILLES", "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
    end

    -- Scroll des patrouilles
    local scroll = vgui.Create("DScrollPanel", leftPanel)
    scroll:SetPos(6, 30)
    scroll:SetSize(leftPanel:GetWide() - 12, H - 100)

    local function RefreshPatrols()
        scroll:Clear()
        for _, patrol in ipairs(PS.Tablet.Data.patrols or {}) do
            local members = PS.Utils.FromJSON(patrol.members or "[]")
            local rowH = 70 + #members * 16
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 6)
            row:SetTall(rowH)
            local sc = StatusColor(patrol.status)
            local pname = patrol.patrol_name or "?"
            local vehicle = patrol.vehicle or ""
            local statusLbl = StatusLabel(patrol.status)
            local membersSnap = members  -- capture

            row.Paint = function(s, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(25, 38, 62, 255))
                -- Bande colorée statut
                draw.RoundedBoxEx(8, 0, 0, 6, h, sc, true, false, true, false)
                -- Nom patrouille
                draw.SimpleText(pname, "DermaDefaultBold", 16, 10, PS.Config.Colors.Text)
                draw.SimpleText(statusLbl, "DermaDefault", 16, 28, sc)
                if vehicle ~= "" then
                    draw.SimpleText("Vehicule: " .. vehicle, "DermaDefault", 16, 46, PS.Config.Colors.TextDim)
                end
                -- Membres
                for mi, m in ipairs(membersSnap) do
                    draw.SimpleText("• " .. tostring(m), "DermaDefault", w - 130, 8 + (mi-1)*16, PS.Config.Colors.TextDim)
                end
            end

            -- Menu contextuel clic droit
            row:SetCursor("hand")
            row.OnMousePressed = function(s, key)
                if key ~= MOUSE_RIGHT then return end
                local menu = DermaMenu()
                -- Sous-menu statut
                local subStatus = menu:AddSubMenu("Changer le statut")
                for _, st in ipairs(STATUSES) do
                    subStatus:AddOption(st.label, function()
                        net.Start("PS_PatrolUpdate")
                            net.WriteUInt(tonumber(patrol.id), 32)
                            net.WriteString(PS.Utils.ToJSON({ status = st.key }))
                        net.SendToServer()
                        timer.Simple(0.3, function() net.Start("PS_PatrolList") net.SendToServer() end)
                    end)
                end
                menu:AddOption("Supprimer la patrouille", function()
                    net.Start("PS_PatrolDelete")
                        net.WriteUInt(tonumber(patrol.id), 32)
                    net.SendToServer()
                    timer.Simple(0.3, function() net.Start("PS_PatrolList") net.SendToServer() end)
                end)
                menu:Open()
            end
        end
    end

    RefreshPatrols()

    -- Bouton créer patrouille
    local createBtn = vgui.Create("DButton", leftPanel)
    createBtn:SetPos(6, H - 92)
    createBtn:SetSize(leftPanel:GetWide() - 12, 36)
    createBtn:SetText("+ Nouvelle Patrouille")
    createBtn:SetTextColor(Color(255,255,255))
    createBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    createBtn.DoClick = function()
        PS.TabletDispatch.OpenCreatePatrol()
    end

    -- Panneau droit : appels actifs / terminés
    local rightPanel = vgui.Create("DPanel", parent)
    rightPanel:SetPos(math.floor(W * 0.45) + 4, 8)
    rightPanel:SetSize(W - math.floor(W * 0.45) - 12, H - 16)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText("APPELS", "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
    end

    -- Tabs appels actifs / terminés
    local activeTab = true
    local callScrollActive  = vgui.Create("DScrollPanel", rightPanel)
    callScrollActive:SetPos(6, 30)
    callScrollActive:SetSize(rightPanel:GetWide() - 12, rightPanel:GetTall() - 80)

    local callScrollFinished = vgui.Create("DScrollPanel", rightPanel)
    callScrollFinished:SetPos(6, 30)
    callScrollFinished:SetSize(rightPanel:GetWide() - 12, rightPanel:GetTall() - 80)
    callScrollFinished:SetVisible(false)

    local tabActive = vgui.Create("DButton", rightPanel)
    tabActive:SetPos(6, rightPanel:GetTall() - 46)
    tabActive:SetSize((rightPanel:GetWide() - 18) / 2, 36)
    tabActive:SetText("Actifs")
    tabActive:SetTextColor(Color(255,255,255))
    tabActive.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, activeTab and PS.Config.Colors.Accent or Color(30,45,70,255))
    end
    tabActive.DoClick = function()
        activeTab = true
        callScrollActive:SetVisible(true)
        callScrollFinished:SetVisible(false)
    end

    local tabFinished = vgui.Create("DButton", rightPanel)
    tabFinished:SetPos((rightPanel:GetWide() - 18)/2 + 12, rightPanel:GetTall() - 46)
    tabFinished:SetSize((rightPanel:GetWide() - 18) / 2, 36)
    tabFinished:SetText("Terminés")
    tabFinished:SetTextColor(Color(255,255,255))
    tabFinished.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, not activeTab and PS.Config.Colors.Accent or Color(30,45,70,255))
    end
    tabFinished.DoClick = function()
        activeTab = false
        callScrollActive:SetVisible(false)
        callScrollFinished:SetVisible(true)
    end

    local function BuildCallList(panel, callList, isActive)
        panel:Clear()
        if #callList == 0 then
            local lbl = vgui.Create("DLabel", panel)
            lbl:Dock(FILL)
            lbl:SetText("Aucun appel.")
            lbl:SetTextColor(PS.Config.Colors.TextDim)
            lbl:SetContentAlignment(5)
            return
        end
        for _, call in ipairs(callList) do
            local row = vgui.Create("DPanel", panel)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 5)
            row:SetTall(72)
            local ctype = call.call_type or "?"
            local desc  = call.description or ""
            local status = call.status or "pending"
            local ts    = tonumber(call.created_at) or 0
            local timeStr = PS.Utils.FormatTime(ts)
            local patrols = PS.Utils.FromJSON(call.patrols or "[]")
            local callId  = tonumber(call.id)

            row.Paint = function(s, w, h)
                local bg = s:IsHovered() and Color(35,52,85,255) or Color(22,34,58,255)
                draw.RoundedBox(8, 0, 0, w, h, bg)
                local typeColor = ctype == "gunshot" and PS.Config.Colors.Danger or PS.Config.Colors.Warning
                draw.RoundedBox(4, 6, 8, 6, h - 16, typeColor)
                draw.SimpleText(string.upper(ctype), "DermaDefaultBold", 20, 10, typeColor)
                draw.SimpleText(PS.Utils.Truncate(desc, 50), "DermaDefault", 20, 28, PS.Config.Colors.TextDim)
                draw.SimpleText(timeStr, "DermaDefault", 20, 46, PS.Config.Colors.TextDim)
                draw.SimpleText("#" .. tostring(patrols and #patrols or 0) .. " patrouilles", "DermaDefault", w - 8, 10, PS.Config.Colors.Accent, TEXT_ALIGN_RIGHT)
                if status == "en_route" then
                    draw.SimpleText("EN ROUTE", "DermaDefault", w - 8, 28, PS.Config.Colors.Success, TEXT_ALIGN_RIGHT)
                end
            end

            if isActive then
                row:SetCursor("hand")
                row.OnMousePressed = function(s, key)
                    if key ~= MOUSE_LEFT then return end
                    local menu = DermaMenu()
                    menu:AddOption("En route", function()
                        -- Cherche notre patrouille
                        local myPatrol = nil
                        local mySteam  = LocalPlayer():SteamID()
                        for _, p in ipairs(PS.Tablet.Data.patrols or {}) do
                            local members = PS.Utils.FromJSON(p.members or "[]")
                            for _, m in ipairs(members) do
                                if tostring(m) == mySteam then
                                    myPatrol = tonumber(p.id)
                                    break
                                end
                            end
                            if myPatrol then break end
                        end
                        if not myPatrol then
                            chat.AddText(Color(220,80,80), "[PS] ", Color(220,230,245), "Vous n'êtes dans aucune patrouille.")
                            return
                        end
                        net.Start("PS_CallEnRoute")
                            net.WriteUInt(callId, 32)
                            net.WriteUInt(myPatrol, 32)
                        net.SendToServer()
                    end)
                    menu:AddOption("Terminé", function()
                        net.Start("PS_CallFinish")
                            net.WriteUInt(callId, 32)
                        net.SendToServer()
                    end)
                    menu:Open()
                end
            else
                -- Appels terminés : affiche position et heure au clic
                row:SetCursor("hand")
                row.OnMousePressed = function(s, key)
                    if key ~= MOUSE_LEFT then return end
                    local infoFrame = vgui.Create("DFrame")
                    infoFrame:SetSize(340, 180)
                    infoFrame:Center()
                    infoFrame:SetTitle("Détail de l'intervention #" .. callId)
                    infoFrame:MakePopup()
                    infoFrame.Paint = function(_, w, h)
                        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.Background)
                    end
                    local yl = 36
                    local function Row(k, v)
                        local lbl = vgui.Create("DLabel", infoFrame)
                        lbl:SetPos(14, yl)
                        lbl:SetSize(320, 20)
                        lbl:SetText(k .. " : " .. tostring(v))
                        lbl:SetTextColor(PS.Config.Colors.Text)
                        yl = yl + 22
                    end
                    Row("Type",     ctype)
                    Row("Heure",    timeStr)
                    Row("Détail",   PS.Utils.Truncate(desc, 60))
                    Row("Position", string.format("%.0f / %.0f", tonumber(call.position_x) or 0, tonumber(call.position_y) or 0))
                    local finTs = tonumber(call.finished_at) or 0
                    Row("Terminé le", finTs > 0 and PS.Utils.FormatTime(finTs) or "?")
                end
            end
        end
    end

    BuildCallList(callScrollActive,  PS.Tablet.Data.calls.active   or {}, true)
    BuildCallList(callScrollFinished, PS.Tablet.Data.calls.finished or {}, false)
end

-- Fenêtre de création de patrouille
function PS.TabletDispatch.OpenCreatePatrol()
    local frame = vgui.Create("DFrame")
    frame:SetSize(420, 320)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, PS.Config.Colors.Background)
        draw.SimpleText("NOUVELLE PATROUILLE", "DermaDefaultBold", w/2, 20, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
    end

    local y = 42
    local function Label(txt)
        local l = vgui.Create("DLabel", frame)
        l:SetPos(14, y)
        l:SetSize(392, 18)
        l:SetText(txt)
        l:SetTextColor(PS.Config.Colors.TextDim)
        y = y + 20
        return l
    end
    local function TextInput(placeholder)
        local ti = vgui.Create("DTextEntry", frame)
        ti:SetPos(14, y)
        ti:SetSize(392, 30)
        ti:SetPlaceholderText(placeholder)
        ti:SetTextColor(PS.Config.Colors.Text)
        ti.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(30,44,70,255))
            s:DrawTextEntryText(PS.Config.Colors.Text, PS.Config.Colors.Accent, PS.Config.Colors.Text)
        end
        y = y + 36
        return ti
    end

    Label("Membres (SteamIDs ou UserIDs séparés par virgule) :")
    local membersEntry = TextInput("ex: 76561198000000000, 76561198000000001")
    Label("Véhicule :")
    local vehicleEntry = TextInput("ex: Police Crown Victoria")

    y = y + 8
    local createBtn = vgui.Create("DButton", frame)
    createBtn:SetPos(14, y)
    createBtn:SetSize(392, 36)
    createBtn:SetText("Créer la patrouille")
    createBtn:SetTextColor(Color(255,255,255))
    createBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    createBtn.DoClick = function()
        local membersRaw = membersEntry:GetValue()
        local vehicle    = vehicleEntry:GetValue()
        local parts = string.Explode(",", membersRaw)
        local members = {}
        for _, p in ipairs(parts) do
            local trimmed = string.Trim(p)
            if trimmed ~= "" then table.insert(members, trimmed) end
        end
        if #members < 1 then
            chat.AddText(Color(220,80,80), "[PS] ", Color(220,230,245), "Entrez au moins un membre.")
            return
        end
        net.Start("PS_PatrolCreate")
            net.WriteString(PS.Utils.ToJSON({ members = members, vehicle = vehicle }))
        net.SendToServer()
        frame:Remove()
        timer.Simple(0.4, function() net.Start("PS_PatrolList") net.SendToServer() end)
    end
end
