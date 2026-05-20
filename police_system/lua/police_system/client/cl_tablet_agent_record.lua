-- ============================================================
--  police_system/client/cl_tablet_agent_record.lua
--  Onglet Profil Agent — casier interne de l'agent
-- ============================================================

PS = PS or {}
PS.TabletAgentFile = {}

local agentNotes      = {}
local selectedOfficer = nil

net.Receive("PS_AgentNoteData", function()
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    if data.success then
        chat.AddText(Color(80,200,80), "[PS] ", Color(220,230,245), "Note ajoutée au profil de l'agent.")
        return
    end
    agentNotes = data
    if IsValid(PS.Tablet.ContentPanel) and PS.Tablet.ActiveTab == "agentfile" then
        PS.Tablet.RebuildContent()
    end
end)

function PS.TabletAgentFile.Build(parent)
    local W, H = parent:GetSize()
    local canView = PS.Utils.IsSergeantPlus(LocalPlayer())

    if not canView then
        local lbl = vgui.Create("DLabel", parent)
        lbl:Dock(FILL)
        lbl:SetText("Accès réservé aux Sergents et grades supérieurs.")
        lbl:SetTextColor(PS.Config.Colors.TextDim)
        lbl:SetContentAlignment(5)
        return
    end

    -- Panel gauche : liste des officiers (en service + hors service)
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetPos(8, 8)
    leftPanel:SetSize(220, H - 16)
    leftPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText("OFFICIERS", "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
    end

    local scroll = vgui.Create("DScrollPanel", leftPanel)
    scroll:SetPos(6, 30)
    scroll:SetSize(208, H - 42)

    local function BuildOfficerList(officers)
        scroll:Clear()
        for _, o in ipairs(officers or {}) do
            local btn = vgui.Create("DButton", scroll)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, 4)
            btn:SetTall(44)
            btn:SetText("")
            local of = o
            local rankInfo = PS.Config.Ranks[of.rank or "officer"]
            local rankLbl  = rankInfo and rankInfo.label or "Officier"
            btn.Paint = function(s, w, h)
                local isSelected = selectedOfficer and selectedOfficer.steamid == of.steamid
                local bg = isSelected and PS.Config.Colors.Accent or (s:IsHovered() and PS.Config.Colors.Header or Color(22,34,58,255))
                draw.RoundedBox(7, 0, 0, w, h, bg)
                draw.SimpleText(of.firstname .. " " .. string.upper(of.lastname), "DermaDefaultBold", 10, 6, PS.Config.Colors.Text)
                draw.SimpleText(rankLbl, "DermaDefault", 10, 24, PS.Config.Colors.TextDim)
            end
            btn.DoClick = function()
                selectedOfficer = of
                agentNotes = {}
                net.Start("PS_AgentNoteGet")
                    net.WriteString(of.steamid)
                net.SendToServer()
            end
        end
    end

    -- Charge la liste (depuis le roll-call data déjà récupéré ou via serveur)
    if rollCallData and #rollCallData > 0 then
        BuildOfficerList(rollCallData)
    else
        net.Start("PS_RollCallRequest") net.SendToServer()
        net.Receive("PS_RollCallData_AgentFile", function()
            local json = net.ReadString()
            BuildOfficerList(PS.Utils.FromJSON(json))
        end)
    end

    -- Panel droit : notes / avertissements
    local rightPanel = vgui.Create("DPanel", parent)
    rightPanel:SetPos(236, 8)
    rightPanel:SetSize(W - 244, H - 16)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        if not selectedOfficer then
            draw.SimpleText("Sélectionnez un officier", "DermaDefault", w/2, h/2, PS.Config.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Notes scroll
    local noteScroll = vgui.Create("DScrollPanel", rightPanel)
    noteScroll:SetPos(8, 30)
    noteScroll:SetSize(rightPanel:GetWide() - 16, rightPanel:GetTall() - 100)

    local function RefreshNotes()
        noteScroll:Clear()
        if not selectedOfficer then return end
        rightPanel.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
            draw.SimpleText("PROFIL — " .. selectedOfficer.firstname .. " " .. string.upper(selectedOfficer.lastname), "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
        end

        if #agentNotes == 0 then
            local lbl = vgui.Create("DLabel", noteScroll)
            lbl:Dock(FILL)
            lbl:SetText("Aucune note.")
            lbl:SetTextColor(PS.Config.Colors.TextDim)
            lbl:SetContentAlignment(5)
            return
        end
        for _, note in ipairs(agentNotes) do
            local row = vgui.Create("DPanel", noteScroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 5)
            row:SetTall(64)
            local n = note
            local isWarning = n.note_type == "warning"
            local isAbsence = n.note_type == "absence"
            row.Paint = function(s, w, h)
                draw.RoundedBox(7, 0, 0, w, h, Color(22,34,58,255))
                local barColor = isWarning and PS.Config.Colors.Warning
                               or (isAbsence and PS.Config.Colors.Danger
                               or PS.Config.Colors.Accent)
                draw.RoundedBoxEx(7, 0, 0, 5, h, barColor, true, false, true, false)
                local typeStr = isWarning and "AVERTISSEMENT" or (isAbsence and "ABSENCE" or "NOTE")
                draw.SimpleText(typeStr, "DermaDefaultBold", 14, 8, barColor)
                draw.SimpleText(PS.Utils.Truncate(n.content or "", 90), "DermaDefault", 14, 28, PS.Config.Colors.Text)
                draw.SimpleText("Par " .. (n.added_by or "?") .. " — " .. PS.Utils.FormatTime(tonumber(n.added_at)), "DermaDefault", 14, 46, PS.Config.Colors.TextDim)
            end
        end
    end

    -- Re-draw quand les notes arrivent
    local origReceive = net.Receive
    net.Receive("PS_AgentNoteData", function()
        local json = net.ReadString()
        local data = PS.Utils.FromJSON(json)
        if data.success then
            chat.AddText(Color(80,200,80), "[PS] ", Color(220,230,245), "Note ajoutée.")
            if selectedOfficer then
                net.Start("PS_AgentNoteGet") net.WriteString(selectedOfficer.steamid) net.SendToServer()
            end
            return
        end
        agentNotes = data
        RefreshNotes()
    end)

    RefreshNotes()

    -- Bouton ajouter note
    local addNoteBtn = vgui.Create("DButton", rightPanel)
    addNoteBtn:SetPos(8, rightPanel:GetTall() - 58)
    addNoteBtn:SetSize((rightPanel:GetWide() - 22) / 2, 36)
    addNoteBtn:SetText("+ Note")
    addNoteBtn:SetTextColor(Color(255,255,255))
    addNoteBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    addNoteBtn.DoClick = function()
        if not selectedOfficer then return end
        PS.TabletAgentFile.OpenNoteForm(selectedOfficer, "note", function() RefreshNotes() end)
    end

    local addWarnBtn = vgui.Create("DButton", rightPanel)
    addWarnBtn:SetPos(16 + (rightPanel:GetWide() - 22) / 2, rightPanel:GetTall() - 58)
    addWarnBtn:SetSize((rightPanel:GetWide() - 22) / 2, 36)
    addWarnBtn:SetText("⚠ Avertissement")
    addWarnBtn:SetTextColor(Color(255,255,255))
    addWarnBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(200,140,10) or PS.Config.Colors.Warning)
    end
    addWarnBtn.DoClick = function()
        if not selectedOfficer then return end
        PS.TabletAgentFile.OpenNoteForm(selectedOfficer, "warning", function() RefreshNotes() end)
    end
end

function PS.TabletAgentFile.OpenNoteForm(officer, noteType, onDone)
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 220)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, PS.Config.Colors.Background)
        local title = noteType == "warning" and "AVERTISSEMENT" or "NOUVELLE NOTE"
        local tc    = noteType == "warning" and PS.Config.Colors.Warning or PS.Config.Colors.Accent
        draw.SimpleText(title .. " — " .. officer.firstname .. " " .. string.upper(officer.lastname), "DermaDefaultBold", w/2, 18, tc, TEXT_ALIGN_CENTER)
    end

    local lbl = vgui.Create("DLabel", frame)
    lbl:SetPos(14, 40)
    lbl:SetSize(372, 18)
    lbl:SetText("Contenu :")
    lbl:SetTextColor(PS.Config.Colors.TextDim)

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(14, 60)
    entry:SetSize(372, 96)
    entry:SetMultiline(true)
    entry:SetPlaceholderText("Décrivez la note ou l'avertissement…")
    entry:SetTextColor(PS.Config.Colors.Text)
    entry.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, Color(30,44,70,255))
        s:DrawTextEntryText(PS.Config.Colors.Text, PS.Config.Colors.Accent, PS.Config.Colors.Text)
    end

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(14, 164)
    saveBtn:SetSize(372, 36)
    saveBtn:SetText("Enregistrer")
    saveBtn:SetTextColor(Color(255,255,255))
    local btnColor = noteType == "warning" and PS.Config.Colors.Warning or PS.Config.Colors.Accent
    saveBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(btnColor.r+20, btnColor.g+20, btnColor.b+20) or btnColor)
    end
    saveBtn.DoClick = function()
        local content = entry:GetValue()
        if content == "" then return end
        net.Start("PS_AgentNoteAdd")
            net.WriteString(PS.Utils.ToJSON({
                officerSteamid = officer.steamid,
                note_type      = noteType,
                content        = content,
            }))
        net.SendToServer()
        frame:Remove()
        if onDone then onDone() end
    end
end
