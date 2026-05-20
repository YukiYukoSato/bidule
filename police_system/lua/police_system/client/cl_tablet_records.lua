-- ============================================================
--  police_system/client/cl_tablet_records.lua
--  Casier judiciaire — visualisation et ajout d'infractions
-- ============================================================

PS = PS or {}
PS.TabletRecords = {}

local currentRecords = {}
local currentCensus  = nil

function PS.TabletRecords.Build(parent)
    local W, H = parent:GetSize()

    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(8, 8)
    panel:SetSize(W - 16, H - 16)
    panel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText("CASIERS JUDICIAIRES", "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
        draw.SimpleText("Utilisez l'onglet Recensement pour sélectionner une personne.", "DermaDefault", w/2, h/2, PS.Config.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Ouvre le casier d'un recensé (appelé depuis cl_tablet_census)
function PS.TabletRecords.OpenForCensus(entry)
    currentCensus = entry
    currentRecords = {}

    net.Start("PS_RecordGet")
        net.WriteUInt(tonumber(entry.id), 32)
    net.SendToServer()

    -- Réception des données
    local listenKey = "PS_RecordData_once"
    net.Receive("PS_RecordData", function()
        local json = net.ReadString()
        local data = PS.Utils.FromJSON(json)
        if data.success then
            chat.AddText(Color(80,200,80), "[PS] ", Color(220,230,245), "Entrée ajoutée au casier.")
            -- Rafraîchit
            if currentCensus then
                net.Start("PS_RecordGet")
                    net.WriteUInt(tonumber(currentCensus.id), 32)
                net.SendToServer()
            end
            return
        end
        currentRecords = data
        PS.TabletRecords.OpenWindow(entry)
    end)
end

function PS.TabletRecords.OpenWindow(entry)
    if IsValid(PS._RecordFrame) then PS._RecordFrame:Remove() end

    local frame = vgui.Create("DFrame")
    PS._RecordFrame = frame
    frame:SetSize(620, 500)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, PS.Config.Colors.Background)
        draw.SimpleText("Casier judiciaire — " .. entry.firstname .. " " .. string.upper(entry.lastname), "DermaDefaultBold", w/2, 18, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(PS.Config.Colors.PanelBorder)
        surface.DrawRect(0, 36, w, 1)
    end

    -- Close
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(frame:GetWide() - 36, 8)
    closeBtn:SetSize(28, 28)
    closeBtn:SetText("✕")
    closeBtn:SetTextColor(PS.Config.Colors.TextDim)
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then draw.RoundedBox(6, 0, 0, w, h, PS.Config.Colors.Danger) end
    end
    closeBtn.DoClick = function() frame:Remove() end

    -- Scroll des entrées
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, 44)
    scroll:SetSize(frame:GetWide() - 20, frame:GetTall() - 110)

    local function BuildRecordList()
        scroll:Clear()
        if #currentRecords == 0 then
            local lbl = vgui.Create("DLabel", scroll)
            lbl:Dock(FILL)
            lbl:SetText("Aucune infraction enregistrée.")
            lbl:SetTextColor(PS.Config.Colors.TextDim)
            lbl:SetContentAlignment(5)
            return
        end
        for _, rec in ipairs(currentRecords) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 6)
            row:SetTall(70)
            local r = rec

            row.Paint = function(s, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(22,34,58,255))
                draw.RoundedBoxEx(8, 0, 0, 5, h, PS.Config.Colors.Danger, true, false, true, false)
                draw.SimpleText(r.offense or "Infraction", "DermaDefaultBold", 16, 8, PS.Config.Colors.Danger)
                draw.SimpleText((r.date_str or "") .. " à " .. (r.time_str or ""), "DermaDefault", 16, 26, PS.Config.Colors.TextDim)
                draw.SimpleText(PS.Utils.Truncate(r.details or "", 80), "DermaDefault", 16, 44, PS.Config.Colors.Text)
                draw.SimpleText("Par : " .. (r.added_by or "?"), "DermaDefault", w - 10, 8, PS.Config.Colors.TextDim, TEXT_ALIGN_RIGHT)
            end

            -- Suppression (lieutenant+)
            local rankKey = LocalPlayer():GetNWString("PS_Rank", "officer")
            if PS.Utils.RankGTE(rankKey, "lieutenant") then
                row:SetCursor("hand")
                row.OnMousePressed = function(_, key)
                    if key ~= MOUSE_RIGHT then return end
                    local menu = DermaMenu()
                    menu:AddOption("Supprimer cette entrée", function()
                        net.Start("PS_RecordDelete")
                            net.WriteUInt(tonumber(r.id), 32)
                        net.SendToServer()
                        -- Retire localement
                        for i = #currentRecords, 1, -1 do
                            if currentRecords[i].id == r.id then
                                table.remove(currentRecords, i)
                            end
                        end
                        BuildRecordList()
                    end)
                    menu:Open()
                end
            end
        end
    end

    BuildRecordList()

    -- Bouton ajouter infraction
    local addBtn = vgui.Create("DButton", frame)
    addBtn:SetPos(10, frame:GetTall() - 58)
    addBtn:SetSize(frame:GetWide() - 20, 36)
    addBtn:SetText("+ Ajouter une infraction")
    addBtn:SetTextColor(Color(255,255,255))
    addBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and PS.Config.Colors.AccentHover or PS.Config.Colors.Accent)
    end
    addBtn.DoClick = function()
        PS.TabletRecords.OpenAddRecord(entry, function()
            BuildRecordList()
        end)
    end
end

-- Formulaire d'ajout d'infraction
function PS.TabletRecords.OpenAddRecord(entry, onDone)
    local frame = vgui.Create("DFrame")
    frame:SetSize(440, 380)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, PS.Config.Colors.Background)
        draw.SimpleText("NOUVELLE INFRACTION", "DermaDefaultBold", w/2, 18, PS.Config.Colors.Danger, TEXT_ALIGN_CENTER)
    end

    local y = 40

    -- Sélection infraction
    local lbl1 = vgui.Create("DLabel", frame)
    lbl1:SetPos(14, y)
    lbl1:SetSize(412, 18)
    lbl1:SetText("Infraction :")
    lbl1:SetTextColor(PS.Config.Colors.TextDim)
    y = y + 20

    local combo = vgui.Create("DComboBox", frame)
    combo:SetPos(14, y)
    combo:SetSize(412, 30)
    combo:SetValue("Sélectionner une infraction")
    combo:SetTextColor(PS.Config.Colors.Text)
    combo.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30,44,70,255))
    end
    for _, offense in ipairs(PS.Config.Offenses) do
        combo:AddChoice(offense)
    end
    y = y + 36

    local function FieldRow(label, placeholder, def)
        local l = vgui.Create("DLabel", frame)
        l:SetPos(14, y)
        l:SetSize(412, 18)
        l:SetText(label)
        l:SetTextColor(PS.Config.Colors.TextDim)
        y = y + 20
        local ti = vgui.Create("DTextEntry", frame)
        ti:SetPos(14, y)
        ti:SetSize(412, 30)
        ti:SetPlaceholderText(placeholder)
        ti:SetValue(def or "")
        ti:SetTextColor(PS.Config.Colors.Text)
        ti.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(30,44,70,255))
            s:DrawTextEntryText(PS.Config.Colors.Text, PS.Config.Colors.Accent, PS.Config.Colors.Text)
        end
        y = y + 36
        return ti
    end

    local dateEntry    = FieldRow("Date :", "JJ/MM/AAAA", os.date("%d/%m/%Y"))
    local timeEntry    = FieldRow("Heure :", "HH:MM",     os.date("%H:%M"))
    local detailsEntry = FieldRow("Détails :", "Description de l'infraction…", "")

    local addBtn = vgui.Create("DButton", frame)
    addBtn:SetPos(14, y + 4)
    addBtn:SetSize(412, 36)
    addBtn:SetText("Enregistrer l'infraction")
    addBtn:SetTextColor(Color(255,255,255))
    addBtn.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(190,40,40) or PS.Config.Colors.Danger)
    end
    addBtn.DoClick = function()
        local offense, _ = combo:GetSelected()
        if not offense or offense == "Sélectionner une infraction" then
            chat.AddText(Color(220,80,80), "[PS] ", Color(220,230,245), "Sélectionnez une infraction.")
            return
        end
        net.Start("PS_RecordAdd")
            net.WriteString(PS.Utils.ToJSON({
                censusId = tonumber(entry.id),
                offense  = offense,
                date_str = dateEntry:GetValue(),
                time_str = timeEntry:GetValue(),
                details  = detailsEntry:GetValue(),
            }))
        net.SendToServer()
        frame:Remove()
        if onDone then onDone() end
    end
end
