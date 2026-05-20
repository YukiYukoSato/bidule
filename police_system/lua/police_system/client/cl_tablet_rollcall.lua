-- ============================================================
--  police_system/client/cl_tablet_rollcall.lua
--  Onglet Appel — liste des officiers, marquer présent/absent
-- ============================================================

PS = PS or {}
PS.TabletRollcall = {}

local rollCallData = {}

net.Receive("PS_RollCallData", function()
    local json = net.ReadString()
    rollCallData = PS.Utils.FromJSON(json)
    -- Partage avec l'onglet agent file
    PS.Tablet.Data = PS.Tablet.Data or {}
    PS.Tablet.Data.rollcallOfficers = rollCallData
    if IsValid(PS.Tablet.ContentPanel) and PS.Tablet.ActiveTab == "rollcall" then
        PS.Tablet.RebuildContent()
    end
end)

function PS.TabletRollcall.Build(parent)
    local W, H = parent:GetSize()
    local canMark = PS.Utils.IsLieutenantPlus(LocalPlayer())

    -- Header
    local headerPanel = vgui.Create("DPanel", parent)
    headerPanel:SetPos(8, 8)
    headerPanel:SetSize(W - 16, 44)
    headerPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.Header)
        draw.SimpleText("APPEL — LISTE DES OFFICIERS", "DermaDefaultBold", w/2, h/2, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if canMark then
            draw.SimpleText("Clic droit pour marquer présent/absent", "DermaDefault", w - 14, h/2, PS.Config.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- Scroll
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetPos(8, 60)
    scroll:SetSize(W - 16, H - 70)

    if #rollCallData == 0 then
        net.Start("PS_RollCallRequest") net.SendToServer()
        local lbl = vgui.Create("DLabel", scroll)
        lbl:Dock(FILL)
        lbl:SetText("Chargement…")
        lbl:SetTextColor(PS.Config.Colors.TextDim)
        lbl:SetContentAlignment(5)
        return
    end

    for _, officer in ipairs(rollCallData) do
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(54)
        local o = officer
        local rankInfo = PS.Config.Ranks[o.rank or "officer"]
        local rankLabel = rankInfo and rankInfo.label or "Officier"
        local onDuty    = tonumber(o.on_duty or 0) == 1
        local banned    = tonumber(o.absent_ban or 0) > os.time()

        row.Paint = function(s, w, h)
            local bg = s:IsHovered() and Color(32,46,74,255) or Color(22,34,58,255)
            draw.RoundedBox(7, 0, 0, w, h, bg)
            local statusColor = onDuty and PS.Config.Colors.Success or PS.Config.Colors.TextDim
            if banned then statusColor = PS.Config.Colors.Danger end
            draw.RoundedBox(4, 6, 8, 5, h - 16, statusColor)
            draw.SimpleText(o.firstname .. " " .. string.upper(o.lastname), "DermaDefaultBold", 18, 8, PS.Config.Colors.Text)
            draw.SimpleText(rankLabel, "DermaDefault", 18, 28, PS.Config.Colors.TextDim)
            local statusLbl = onDuty and "En service" or (banned and "BANNI (absence)" or "Hors service")
            draw.SimpleText(statusLbl, "DermaDefault", w - 14, 18, statusColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        if canMark then
            row:SetCursor("hand")
            row.OnMousePressed = function(s, key)
                if key ~= MOUSE_RIGHT then return end
                local menu = DermaMenu()
                menu:AddOption("Marquer Présent", function()
                    net.Start("PS_RollCallMark")
                        net.WriteString(PS.Utils.ToJSON({ steamid = o.steamid, present = true }))
                    net.SendToServer()
                end)
                menu:AddOption("Marquer Absent", function()
                    Derma_Query(
                        "Marquer " .. o.firstname .. " " .. o.lastname .. " comme absent ?\nCela le retirera du service pendant " .. math.ceil(PS.Config.AbsenceBanDuration/60) .. " minutes.",
                        "Confirmation",
                        "Confirmer", function()
                            net.Start("PS_RollCallMark")
                                net.WriteString(PS.Utils.ToJSON({ steamid = o.steamid, present = false }))
                            net.SendToServer()
                            timer.Simple(0.5, function()
                                net.Start("PS_RollCallRequest") net.SendToServer()
                            end)
                        end,
                        "Annuler", function() end
                    )
                end)
                menu:Open()
            end
        end
    end
end
