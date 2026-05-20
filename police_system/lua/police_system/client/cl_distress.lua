-- ============================================================
--  police_system/client/cl_distress.lua
--  Appel de détresse F7 + indicateurs 3D monde
--  Montre la distance aux points d'alerte et de détresse en
--  tournant la caméra (DrawTranslucent / HUDPaint)
-- ============================================================

PS = PS or {}
PS.Distress = PS.Distress or {}

-- ------- Appel de détresse -------

local distressActive = false

hook.Add("Think", "PS_DistressKey", function()
    if not PS.Utils.IsPolice(LocalPlayer()) then return end
    if input.IsKeyDown(PS.Config.DistressKey) and not PS.Distress._held then
        PS.Distress._held = true
        if not distressActive then
            distressActive = true
            net.Start("PS_Distress") net.SendToServer()
            chat.AddText(Color(220, 80, 80), "[SOS] ", Color(220,230,245), "Appel de détresse envoyé ! Appuyez à nouveau pour annuler.")
        else
            distressActive = false
            net.Start("PS_DistressClear") net.SendToServer()
            chat.AddText(Color(80, 200, 80), "[SOS] ", Color(220,230,245), "Appel de détresse annulé.")
        end
    elseif not input.IsKeyDown(PS.Config.DistressKey) then
        PS.Distress._held = false
    end
end)

-- Nettoyage à la déconnexion / changement de job
hook.Add("InitPostEntity", "PS_DistressReset", function()
    distressActive = false
end)

-- ------- Indicateurs 3D à l'écran (HUDPaint) -------
-- Affiche la distance vers chaque alerte / SOS quand ils sont
-- dans le champ de vision du joueur.

local function DrawWorldIndicator(pos, label, color)
    local screenPos = pos:ToScreen()
    if not screenPos.visible then return end

    local myPos  = LocalPlayer():GetPos()
    local dist   = math.floor(myPos:Distance(pos))
    local distM  = math.floor(dist * 0.01905)  -- unités Hammer → mètres approximatif

    local x, y = screenPos.x, screenPos.y

    -- Cercle extérieur pulsant
    local pulse = math.abs(math.sin(CurTime() * 2)) * 10
    surface.SetDrawColor(color.r, color.g, color.b, 80)
    surface.DrawCircle(x, y, 20 + pulse, 32)

    -- Point central
    draw.RoundedBox(5, x - 7, y - 7, 14, 14, color)

    -- Fond étiquette
    local labelFull = label .. " — " .. distM .. "m"
    local tw        = #labelFull * 6 + 16
    draw.RoundedBox(5, x - tw/2, y - 36, tw, 22, Color(10, 15, 30, 200))
    draw.SimpleText(labelFull, "DermaDefault", x, y - 25, Color(255,255,255,230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "PS_WorldIndicators", function()
    if not PS.Utils.IsPolice(LocalPlayer()) then return end

    -- Appels actifs assignés à notre patrouille
    if PS.Tablet.Data.callAssign then
        local ap = PS.Tablet.Data.callAssign.pos
        DrawWorldIndicator(ap, "INTERVENTION", Color(30, 100, 220))
    end

    -- Appels de détresse de collègues
    for _, d in ipairs(PS.Tablet.Data.distress or {}) do
        if d.steamid ~= LocalPlayer():SteamID() then
            local dp = Vector(tonumber(d.position_x), tonumber(d.position_y), tonumber(d.position_z) + 72)
            DrawWorldIndicator(dp, "SOS", Color(220, 40, 40))
        end
    end

    -- Appels actifs (tirs etc.) — tous visibles même non assignés
    for _, call in ipairs(PS.Tablet.Data.calls.active or {}) do
        local cp = Vector(tonumber(call.position_x), tonumber(call.position_y), tonumber(call.position_z) + 72)
        local cl = call.call_type == "gunshot" and Color(220, 80, 80) or Color(220, 160, 30)
        DrawWorldIndicator(cp, string.upper(call.call_type or "ALERTE"), cl)
    end
end)
