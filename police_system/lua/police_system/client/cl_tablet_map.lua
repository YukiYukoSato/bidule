-- ============================================================
--  police_system/client/cl_tablet_map.lua
--  Onglet Carte — blips officiers, appels, détresse
-- ============================================================

PS = PS or {}
PS.TabletMap = {}

-- Dessin d'un cercle via polygone (surface.DrawCircle n'existe pas dans GMod)
local function DrawCircle(x, y, radius, segments)
    segments = segments or 24
    local poly = {}
    for i = 0, segments - 1 do
        local a = math.rad(i / segments * 360)
        poly[i + 1] = { x = x + math.cos(a) * radius, y = y + math.sin(a) * radius }
    end
    draw.NoTexture()
    surface.DrawPoly(poly)
end

-- Conversion position monde → coordonnée sur la minimap
-- La minimap est un rectangle de dimensions (mapW x mapH) représentant
-- les coordonnées du monde. On utilise les limites de la map via
-- engine.GetMapName et une approximation standard pour HL2 maps.
local function WorldToMap(worldPos, panelX, panelY, panelW, panelH)
    -- Limites approximatives de la plupart des maps GMod (ajustable)
    local worldMinX = -8192
    local worldMaxX =  8192
    local worldMinY = -8192
    local worldMaxY =  8192

    -- Essaie d'utiliser les limites réelles si disponibles
    if util and util.worldspawn then
        -- GMod n'expose pas directement les limites de la map par API simple
        -- On utilise les valeurs par défaut ci-dessus
    end

    local nx = (worldPos.x - worldMinX) / (worldMaxX - worldMinX)
    local ny = (worldPos.y - worldMinY) / (worldMaxY - worldMinY)
    -- Y est inversé en GMod (Y+ = nord dans le monde, Y+ = bas à l'écran)
    ny = 1 - ny

    return panelX + nx * panelW, panelY + ny * panelH
end

function PS.TabletMap.Build(parent)
    local W, H = parent:GetSize()

    -- Fond de carte
    local mapPanel = vgui.Create("DPanel", parent)
    mapPanel:SetPos(8, 8)
    mapPanel:SetSize(W - 200, H - 16)
    local mW, mH = mapPanel:GetSize()

    mapPanel.Paint = function(s, w, h)
        -- Fond sombre simulant une carte
        draw.RoundedBox(10, 0, 0, w, h, Color(18, 28, 48, 255))
        surface.SetDrawColor(PS.Config.Colors.PanelBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        -- Grille subtile
        surface.SetDrawColor(30, 50, 80, 60)
        local step = 40
        for gx = 0, w, step do surface.DrawLine(gx, 0, gx, h) end
        for gy = 0, h, step do surface.DrawLine(0, gy, w, gy) end

        -- Titre
        draw.SimpleText("CARTE EN DIRECT", "DermaDefault", w/2, 12, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local myPos = LocalPlayer():GetPos()

        -- Position du joueur local
        local px, py = WorldToMap(myPos, 0, 0, w, h)
        -- Halo
        surface.SetDrawColor(PS.Config.Colors.Accent.r, PS.Config.Colors.Accent.g, PS.Config.Colors.Accent.b, 60)
        DrawCircle(px, py, 14)
        -- Blip joueur local (blanc)
        surface.SetDrawColor(255, 255, 255, 255)
        draw.RoundedBox(5, px - 6, py - 6, 12, 12, Color(255, 255, 255, 255))
        draw.SimpleText("MOI", "DermaDefault", px, py + 10, Color(255,255,255,200), TEXT_ALIGN_CENTER)

        -- Blips des autres officiers
        for _, officer in ipairs(PS.Tablet.Data.officers or {}) do
            if officer.steamid ~= LocalPlayer():SteamID() then
                local op = Vector(officer.pos_x, officer.pos_y, officer.pos_z)
                local ox, oy = WorldToMap(op, 0, 0, w, h)
                local rankInfo = PS.Config.Ranks[officer.rank or "officer"]
                local blipColor = Color(80, 160, 255, 255)
                surface.SetDrawColor(blipColor.r, blipColor.g, blipColor.b, 220)
                draw.RoundedBox(5, ox - 5, oy - 5, 10, 10, blipColor)
                draw.SimpleText(officer.name or "?", "DermaDefault", ox, oy + 9, Color(180,200,240,220), TEXT_ALIGN_CENTER)
            end
        end

        -- Blips appels actifs
        for _, call in ipairs(PS.Tablet.Data.calls.active or {}) do
            local cp = Vector(tonumber(call.position_x), tonumber(call.position_y), tonumber(call.position_z))
            local cx, cy = WorldToMap(cp, 0, 0, w, h)
            local blipC = (call.call_type == "gunshot") and Color(220, 80, 80) or Color(220, 160, 30)
            draw.RoundedBox(5, cx - 6, cy - 6, 12, 12, blipC)
            surface.SetDrawColor(blipC.r, blipC.g, blipC.b, 80)
            DrawCircle(cx, cy, 14)
            draw.SimpleText("!", "DermaDefaultBold", cx, cy - 1, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Blips détresse (rouge clignotant)
        local blink = math.floor(CurTime() * 2) % 2 == 0
        for _, d in ipairs(PS.Tablet.Data.distress or {}) do
            local dp = Vector(tonumber(d.position_x), tonumber(d.position_y), tonumber(d.position_z))
            local dx, dy = WorldToMap(dp, 0, 0, w, h)
            if blink then
                draw.RoundedBox(6, dx - 7, dy - 7, 14, 14, Color(255, 30, 30, 255))
                draw.SimpleText("SOS", "DermaDefault", dx, dy + 11, Color(255, 80, 80, 255), TEXT_ALIGN_CENTER)
            end
        end

        -- Appel assigné à notre patrouille (bleu + flèche)
        if PS.Tablet.Data.callAssign then
            local ap = PS.Tablet.Data.callAssign.pos
            local ax, ay = WorldToMap(ap, 0, 0, w, h)
            draw.RoundedBox(7, ax - 8, ay - 8, 16, 16, Color(30, 100, 220, 255))
            -- Flèche simple vers le bas
            surface.SetDrawColor(80, 150, 255, 255)
            surface.DrawLine(ax, ay + 8, ax, ay + 20)
            surface.DrawLine(ax, ay + 20, ax - 5, ay + 15)
            surface.DrawLine(ax, ay + 20, ax + 5, ay + 15)
        end
    end

    -- Panneau latéral légende + status
    local sidePanel = vgui.Create("DPanel", parent)
    sidePanel:SetPos(W - 188, 8)
    sidePanel:SetSize(180, H - 16)
    sidePanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
    end

    -- Légende
    local y = 12
    local function LegendItem(label, color, yy)
        draw.RoundedBox(4, 10, yy, 14, 14, color)
        draw.SimpleText(label, "DermaDefault", 32, yy + 7, PS.Config.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    sidePanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PS.Config.Colors.PanelBg)
        draw.SimpleText("LÉGENDE", "DermaDefaultBold", w/2, 14, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
        LegendItem("Vous",            Color(255,255,255), 32)
        LegendItem("Officier",        Color(80, 160, 255), 54)
        LegendItem("Alerte tirs",     Color(220, 80, 80),  76)
        LegendItem("Alerte autre",    Color(220,160, 30),  98)
        LegendItem("SOS",             Color(255, 30, 30), 120)
        LegendItem("En route (moi)",  Color(30, 100,220), 142)

        -- Compteurs
        local officers = PS.Tablet.Data.officers or {}
        local calls    = PS.Tablet.Data.calls.active or {}
        local distress = PS.Tablet.Data.distress or {}

        draw.SimpleText("Officiers en service:", "DermaDefault", 10, 175, PS.Config.Colors.TextDim)
        draw.SimpleText(tostring(#officers), "DermaDefaultBold", w-10, 175, PS.Config.Colors.Accent, TEXT_ALIGN_RIGHT)

        draw.SimpleText("Appels actifs:", "DermaDefault", 10, 195, PS.Config.Colors.TextDim)
        draw.SimpleText(tostring(#calls), "DermaDefaultBold", w-10, 195, PS.Config.Colors.Warning, TEXT_ALIGN_RIGHT)

        draw.SimpleText("SOS actifs:", "DermaDefault", 10, 215, PS.Config.Colors.TextDim)
        draw.SimpleText(tostring(#distress), "DermaDefaultBold", w-10, 215, PS.Config.Colors.Danger, TEXT_ALIGN_RIGHT)

        -- Liste officiers
        local oy = 240
        draw.SimpleText("OFFICIERS", "DermaDefaultBold", w/2, oy, PS.Config.Colors.Accent, TEXT_ALIGN_CENTER)
        oy = oy + 18
        for i, officer in ipairs(officers) do
            if oy > h - 20 then break end
            local rk  = PS.Config.Ranks[officer.rank or "officer"]
            local rkl = rk and rk.label or "Officier"
            draw.SimpleText(officer.name or "?", "DermaDefault", 10, oy, PS.Config.Colors.Text)
            oy = oy + 14
            draw.SimpleText(rkl, "DermaDefault", 10, oy, PS.Config.Colors.TextDim)
            oy = oy + 18
        end
    end

    -- Bouton prise de service
    local dutyBtn = vgui.Create("DButton", parent)
    dutyBtn:SetPos(8, H - 44)
    dutyBtn:SetSize(180, 36)
    dutyBtn:SetText("")
    local onDuty = LocalPlayer():GetNWBool("PS_OnDuty", false)
    dutyBtn.Paint = function(s, w, h)
        onDuty = LocalPlayer():GetNWBool("PS_OnDuty", false)
        local bg = onDuty and PS.Config.Colors.Danger or PS.Config.Colors.Success
        if s:IsHovered() then bg = Color(bg.r + 20, bg.g + 20, bg.b + 20) end
        draw.RoundedBox(8, 0, 0, w, h, bg)
        local txt = onDuty and "Quitter le service" or "Prendre le service"
        draw.SimpleText(txt, "DermaDefaultBold", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    dutyBtn.DoClick = function()
        onDuty = LocalPlayer():GetNWBool("PS_OnDuty", false)
        if onDuty then
            net.Start("PS_OffDuty") net.SendToServer()
        else
            net.Start("PS_OnDuty") net.SendToServer()
        end
        timer.Simple(0.5, function() PS.Tablet.RefreshIfOpen() end)
    end
end
