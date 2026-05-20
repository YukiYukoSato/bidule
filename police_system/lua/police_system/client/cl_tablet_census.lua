-- ============================================================
--  police_system/client/cl_tablet_census.lua
--  Onglet Recensement — enregistrer, rechercher, amender, emprisonner
-- ============================================================

PS = PS or {}
PS.TabletCensus = {}

local censusResults   = {}
local selectedCensus  = nil

function PS.TabletCensus.Build(parent)
    local W, H = parent:GetSize()

    -- Panneau gauche : recherche + résultats
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetPos(8, 8)
    leftPanel:SetSize(math.floor(W * 0.42) - 8, H - 16)
    leftPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText("RECHERCHE", "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
    end

    -- Barre de recherche
    local searchBar = vgui.Create("DTextEntry", leftPanel)
    searchBar:SetPos(8, 30)
    searchBar:SetSize(leftPanel:GetWide() - 16, 32)
    searchBar:SetPlaceholderText("Rechercher par nom, prénom, SteamID…")
    searchBar:SetTextColor(PS.Config.Colors.Text)
    searchBar.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, Color(30,44,70,255))
        s:DrawTextEntryText(PS.Config.Colors.Text, PS.Config.Colors.Accent, PS.Config.Colors.Text)
    end
    searchBar.OnEnter = function(s)
        net.Start("PS_CensusSearch")
            net.WriteString(s:GetValue())
        net.SendToServer()
    end

    -- Scroll résultats
    local resultsScroll = vgui.Create("DScrollPanel", leftPanel)
    resultsScroll:SetPos(8, 70)
    resultsScroll:SetSize(leftPanel:GetWide() - 16, H - 170)

    local function RefreshResults()
        resultsScroll:Clear()
        if #censusResults == 0 then
            local lbl = vgui.Create("DLabel", resultsScroll)
            lbl:Dock(FILL)
            lbl:SetText("Aucun résultat.")
            lbl:SetTextColor(PS.Config.Colors.TextDim)
            lbl:SetContentAlignment(5)
            return
        end
        for _, entry in ipairs(censusResults) do
            local row = vgui.Create("DButton", resultsScroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 4)
            row:SetTall(48)
            row:SetText("")
            local e = entry
            row.Paint = function(s, w, h)
                local isSelected = selectedCensus and selectedCensus.id == e.id
                local bg = isSelected and PS.Config.Colors.Accent
                           or (s:IsHovered() and PS.Config.Colors.Header or Color(22,34,58,255))
                draw.RoundedBox(7, 0, 0, w, h, bg)
                draw.SimpleText(e.firstname .. " " .. string.upper(e.lastname), "DermaDefaultBold", 10, 8, PS.Config.Colors.Text)
                draw.SimpleText("Né le " .. (e.birthdate or "?") .. " — " .. (e.age or "?") .. " ans", "DermaDefault", 10, 28, PS.Config.Colors.TextDim)
            end
            row.DoClick = function()
                selectedCensus = e
                PS.TabletCensus.ShowDetail(parent, W, H)
            end
        end
    end

    -- Bouton nouveau recensement
    local addBtn = vgui.Create("DButton", leftPanel)
    addBtn:SetPos(8, H - 74)
    addBtn:SetSize(leftPanel:GetWide() - 16, 36)
    addBtn:SetText("+ Recenser une personne")
    addBtn:SetTextColor(Color(255,255,255))
    addBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    addBtn.DoClick = function()
        PS.TabletCensus.OpenAddForm()
    end

    -- Réception résultats
    net.Receive("PS_CensusResults", function()
        local json = net.ReadString()
        local data = PS.Utils.FromJSON(json)
        -- Si c'est un message de succès simple
        if data.success then
            chat.AddText(Color(80,200,80), "[PS] ", Color(220,230,245), "Personne recensée avec succès.")
            return
        end
        censusResults = data
        RefreshResults()
    end)

    RefreshResults()

    -- Panneau droit : détail du recensé sélectionné
    PS.TabletCensus.DetailHolder = vgui.Create("DPanel", parent)
    PS.TabletCensus.DetailHolder:SetPos(math.floor(W * 0.42) + 4, 8)
    PS.TabletCensus.DetailHolder:SetSize(W - math.floor(W * 0.42) - 12, H - 16)
    PS.TabletCensus.DetailHolder.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        if not selectedCensus then
            draw.SimpleText("Sélectionnez une personne", "DermaDefault", w/2, h/2, PS.Config.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PS.TabletCensus.ShowDetail(parent, W, H)
    if not IsValid(PS.TabletCensus.DetailHolder) then return end
    PS.TabletCensus.DetailHolder:Clear()

    local entry = selectedCensus
    if not entry then return end
    local panel = PS.TabletCensus.DetailHolder
    local pw, ph = panel:GetSize()

    -- Infos de base
    panel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText(entry.firstname .. " " .. string.upper(entry.lastname), "DermaLarge", w/2, 20, PS.Config.Colors.Text, TEXT_ALIGN_CENTER)
        draw.SimpleText("Né(e) le " .. (entry.birthdate or "?") .. " — " .. (entry.age or "?") .. " ans", "DermaDefault", w/2, 48, PS.Config.Colors.TextDim, TEXT_ALIGN_CENTER)
        draw.SimpleText("SteamID: " .. (entry.steamid or "N/A"), "DermaDefault", w/2, 66, PS.Config.Colors.TextDim, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(PS.Config.Colors.PanelBorder)
        surface.DrawRect(14, 84, w - 28, 1)
    end

    local y = 92
    local btnW = (pw - 36) / 3

    -- Amende
    local amendBtn = vgui.Create("DButton", panel)
    amendBtn:SetPos(12, y)
    amendBtn:SetSize(btnW, 34)
    amendBtn:SetText("Amende")
    amendBtn:SetTextColor(Color(255,255,255))
    amendBtn.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, s:IsHovered() and Color(200,160,20) or PS.Config.Colors.Warning)
    end
    amendBtn.DoClick = function()
        Derma_StringRequest("Amende", "Montant de l'amende :", "1000", function(val)
            local amount = tonumber(val)
            if not amount or amount <= 0 then return end
            net.Start("PS_CensusAmend")
                net.WriteUInt(tonumber(entry.id), 32)
                net.WriteUInt(amount, 32)
            net.SendToServer()
        end)
    end

    -- Prison
    local prisonBtn = vgui.Create("DButton", panel)
    prisonBtn:SetPos(12 + btnW + 6, y)
    prisonBtn:SetSize(btnW, 34)
    prisonBtn:SetText("Emprisonner")
    prisonBtn:SetTextColor(Color(255,255,255))
    prisonBtn.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, s:IsHovered() and Color(190,40,40) or PS.Config.Colors.Danger)
    end
    prisonBtn.DoClick = function()
        Derma_StringRequest("Prison", "Durée (minutes) :", "5", function(val)
            local duration = tonumber(val)
            if not duration or duration <= 0 then return end
            net.Start("PS_CensusImprison")
                net.WriteUInt(tonumber(entry.id), 32)
                net.WriteUInt(duration, 16)
            net.SendToServer()
        end)
    end

    -- Casier judiciaire
    local recordBtn = vgui.Create("DButton", panel)
    recordBtn:SetPos(12 + (btnW + 6) * 2, y)
    recordBtn:SetSize(btnW, 34)
    recordBtn:SetText("Casier")
    recordBtn:SetTextColor(Color(255,255,255))
    recordBtn.Paint = function(s, w, h)
        draw.RoundedBox(7, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    recordBtn.DoClick = function()
        PS.TabletRecords.OpenForCensus(entry)
    end
end

-- Formulaire d'ajout de personne
function PS.TabletCensus.OpenAddForm()
    local frame = vgui.Create("DFrame")
    frame:SetSize(420, 320)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, PS.Config.Colors.Background)
        draw.SimpleText("RECENSEMENT", "DermaDefaultBold", w/2, 20, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
    end

    local y = 42
    local function FieldRow(label, placeholder)
        local lbl = vgui.Create("DLabel", frame)
        lbl:SetPos(14, y)
        lbl:SetSize(392, 18)
        lbl:SetText(label)
        lbl:SetTextColor(PS.Config.Colors.TextDim)
        y = y + 20
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

    local firstnameEntry = FieldRow("Prénom :", "Jean")
    local lastnameEntry  = FieldRow("Nom :", "DUPONT")
    local ageEntry       = FieldRow("Âge :", "30")
    local birthEntry     = FieldRow("Date de naissance (JJ/MM/AAAA) :", "01/01/1990")

    local addBtn = vgui.Create("DButton", frame)
    addBtn:SetPos(14, y + 4)
    addBtn:SetSize(392, 36)
    addBtn:SetText("Enregistrer")
    addBtn:SetTextColor(Color(255,255,255))
    addBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    addBtn.DoClick = function()
        local fn = firstnameEntry:GetValue()
        local ln = lastnameEntry:GetValue()
        local ag = ageEntry:GetValue()
        local bd = birthEntry:GetValue()
        if fn == "" or ln == "" then
            chat.AddText(Color(220,80,80), "[PS] ", Color(220,230,245), "Prénom et nom requis.")
            return
        end
        net.Start("PS_CensusAdd")
            net.WriteString(PS.Utils.ToJSON({
                firstname = fn,
                lastname  = ln,
                age       = tonumber(ag) or 0,
                birthdate = bd,
                steamid   = "",
            }))
        net.SendToServer()
        frame:Remove()
    end
end
