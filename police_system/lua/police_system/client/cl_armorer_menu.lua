-- ============================================================
--  police_system/client/cl_armorer_menu.lua
--  Menu client de l'armurier (VGUI)
-- ============================================================

local function OpenArmorerMenu()
    if IsValid(PS.ArmorerFrame) then PS.ArmorerFrame:Remove() end

    local W, H = 520, 480
    local frame = vgui.Create("DFrame")
    PS.ArmorerFrame = frame
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    -- Fond personnalisé
    frame.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, PS.Config.Colors.Background)
        draw.RoundedBoxEx(10, 0, 0, w, 44, PS.Config.Colors.Header, true, true, false, false)
        draw.SimpleText("ARMURIER", "DermaLarge", w / 2, 22, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(PS.Config.Colors.PanelBorder)
        surface.DrawRect(0, 44, w, 1)
    end

    -- Bouton fermer
    local close = vgui.Create("DButton", frame)
    close:SetPos(W - 36, 8)
    close:SetSize(28, 28)
    close:SetText("✕")
    close:SetFont("DermaDefaultBold")
    close:SetTextColor(PS.Config.Colors.TextDim)
    close.Paint = function(s, w, h)
        if s:IsHovered() then draw.RoundedBox(6, 0, 0, w, h, Color(180, 40, 40, 200)) end
    end
    close.DoClick = function() frame:Remove() end

    -- Panel des catégories
    local catPanel = vgui.Create("DPanel", frame)
    catPanel:SetPos(10, 54)
    catPanel:SetSize(160, H - 64)
    catPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
    end

    -- Panel des articles
    local itemPanel = vgui.Create("DPanel", frame)
    itemPanel:SetPos(180, 54)
    itemPanel:SetSize(W - 190, H - 64)
    itemPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
    end

    local currentCat = nil

    local function ShowItems(catKey)
        currentCat = catKey
        itemPanel:Clear()

        local catData = PS.Config.ArmoryCatalog[catKey]
        if not catData then return end

        local scroll = vgui.Create("DScrollPanel", itemPanel)
        scroll:Dock(FILL)
        scroll:DockMargin(6, 6, 6, 6)

        for idx, item in ipairs(catData.items) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 6)
            row:SetTall(60)
            local i = idx  -- capture

            row.Paint = function(s, w, h)
                local bg = s:IsHovered() and PS.Config.Colors.Header or Color(30, 40, 65, 255)
                draw.RoundedBox(8, 0, 0, w, h, bg)
                draw.SimpleText(item.label, "DermaDefaultBold", 12, 10, PS.Config.Colors.Text, TEXT_ALIGN_LEFT)
                local priceStr = item.price and (item.price .. "$") or "Gratuit"
                draw.SimpleText(priceStr, "DermaDefault", 12, 32, PS.Config.Colors.Accent, TEXT_ALIGN_LEFT)
                if item.armor then
                    draw.SimpleText("+" .. item.armor .. " Armure", "DermaDefault", w - 12, 22, PS.Config.Colors.Success, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end

            row:SetCursor("hand")
            row.OnMousePressed = function(s, key)
                if key ~= MOUSE_LEFT then return end
                -- Confirmation
                local conf = vgui.Create("DFrame")
                conf:SetSize(280, 120)
                conf:Center()
                conf:SetTitle("")
                conf:SetDraggable(false)
                conf:MakePopup()
                conf.Paint = function(_, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.Background)
                    draw.SimpleText("Confirmer l'achat ?", "DermaDefaultBold", w/2, 20, PS.Config.Colors.Text, TEXT_ALIGN_CENTER)
                    draw.SimpleText(item.label .. " — " .. (item.price or 0) .. "$", "DermaDefault", w/2, 44, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
                end

                local yes = vgui.Create("DButton", conf)
                yes:SetPos(20, 78)
                yes:SetSize(110, 30)
                yes:SetText("Acheter")
                yes:SetTextColor(Color(255,255,255))
                yes.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, PS.Config.Colors.Success) end
                yes.DoClick = function()
                    conf:Remove()
                    net.Start("PS_ArmorerBuy")
                        net.WriteString(PS.Utils.ToJSON({ category = catKey, item = i }))
                    net.SendToServer()
                end

                local no = vgui.Create("DButton", conf)
                no:SetPos(150, 78)
                no:SetSize(110, 30)
                no:SetText("Annuler")
                no:SetTextColor(Color(255,255,255))
                no.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, PS.Config.Colors.Danger) end
                no.DoClick = function() conf:Remove() end
            end
        end
    end

    -- Boutons de catégorie
    local catOrder = { "kevlar", "handguns", "heavy", "sniper" }
    local y = 8
    for _, catKey in ipairs(catOrder) do
        local catData = PS.Config.ArmoryCatalog[catKey]
        if catData then
            local btn = vgui.Create("DButton", catPanel)
            btn:SetPos(8, y)
            btn:SetSize(144, 40)
            btn:SetText(catData.label)
            btn:SetTextColor(PS.Config.Colors.Text)
            btn:SetFont("DermaDefaultBold")
            btn.Paint = function(s, w, h)
                local isActive = currentCat == catKey
                local bg = isActive and PS.Config.Colors.Accent or (s:IsHovered() and PS.Config.Colors.Header or Color(35, 48, 75, 255))
                draw.RoundedBox(7, 0, 0, w, h, bg)
            end
            btn.DoClick = function() ShowItems(catKey) end
            y = y + 48
        end
    end

    -- Sélection initiale
    ShowItems("kevlar")
end

-- Résultat d'achat
net.Receive("PS_ArmorerResult", function()
    local msg = net.ReadString()
    if string.sub(msg, 1, 3) == "OK:" then
        local item = string.sub(msg, 4)
        chat.AddText(Color(80, 200, 80), "[Armurier] ", Color(220,230,245), "Article reçu : " .. item)
        surface.PlaySound("buttons/button14.wav")
    else
        chat.AddText(Color(200, 80, 80), "[Armurier] ", Color(220,230,245), msg)
        surface.PlaySound("buttons/button8.wav")
    end
end)

-- Réception signal ouverture depuis le serveur
net.Receive("PS_ArmorerOpen", function()
    OpenArmorerMenu()
end)
