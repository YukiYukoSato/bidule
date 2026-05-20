-- ============================================================
--  police_system/client/cl_tablet.lua
--  Tablette principale — contrôleur et animations
--  Ouvre/ferme avec PS.Config.TabletKey (défaut F6)
-- ============================================================

PS = PS or {}
PS.Tablet = PS.Tablet or {}

-- Données mises en cache localement
PS.Tablet.Data = {
    myData      = nil,       -- profil de l'officier connecté
    officers    = {},        -- liste des officiers en service (blips)
    distress    = {},        -- appels de détresse actifs
    calls       = { active = {}, finished = {} },
    patrols     = {},
    callAssign  = nil,       -- appel en cours assigné à notre patrouille {id, pos}
}

-- État d'ouverture
PS.Tablet.IsOpen  = false
PS.Tablet.Frame   = nil     -- DFrame principale

-- Onglet courant
PS.Tablet.ActiveTab = "map"

-- ------- Outils visuels internes -------

-- Dessine un bouton animé "pill"
function PS.Tablet.DrawTabButton(x, y, w, h, label, active, hovered)
    local bg = active and PS.Config.Colors.Accent
               or (hovered and PS.Config.Colors.Header
               or Color(28, 40, 65, 255))
    draw.RoundedBox(10, x, y, w, h, bg)
    local tc = active and Color(255,255,255) or PS.Config.Colors.TextDim
    draw.SimpleText(label, "DermaDefaultBold", x + w/2, y + h/2, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ------- Toggle tablette -------

local function ToggleTablet()
    if PS.Tablet.IsOpen then
        PS.Tablet.Close()
    else
        PS.Tablet.Open()
    end
end

-- Binding clavier direct (Think hook — méthode fiable dans GMod)
hook.Add("Think", "PS_TabletKeyThink", function()
    if input.IsKeyDown(PS.Config.TabletKey) and not PS.Tablet._keyHeld then
        PS.Tablet._keyHeld = true
        if PS.Utils.IsPolice(LocalPlayer()) then
            ToggleTablet()
        end
    elseif not input.IsKeyDown(PS.Config.TabletKey) then
        PS.Tablet._keyHeld = false
    end
end)

-- ------- Réceptions réseau -------

net.Receive("PS_MyData", function()
    local json = net.ReadString()
    PS.Tablet.Data.myData = PS.Utils.FromJSON(json)
    PS.Tablet.RefreshIfOpen()
end)

net.Receive("PS_OfficersList", function()
    local json = net.ReadString()
    PS.Tablet.Data.officers = PS.Utils.FromJSON(json)
end)

net.Receive("PS_PatrolList", function()
    local json = net.ReadString()
    PS.Tablet.Data.patrols = PS.Utils.FromJSON(json)
    PS.Tablet.RefreshIfOpen()
end)

net.Receive("PS_CallList", function()
    local json = net.ReadString()
    PS.Tablet.Data.calls = PS.Utils.FromJSON(json)
    PS.Tablet.RefreshIfOpen()
end)

net.Receive("PS_DistressList", function()
    local json = net.ReadString()
    PS.Tablet.Data.distress = PS.Utils.FromJSON(json)
end)

net.Receive("PS_GradeUpdated", function()
    local rank = net.ReadString()
    local info = PS.Config.Ranks[rank]
    if info then
        chat.AddText(Color(80, 200, 80), "[PS] ", Color(220,230,245), "Votre grade a été mis à jour : " .. info.label)
    end
    PS.Tablet.RefreshIfOpen()
end)

net.Receive("PS_GunshotAlert", function()
    local callId  = net.ReadUInt(32)
    local ctype   = net.ReadString()
    local pos     = net.ReadVector()
    local desc    = net.ReadString()
    surface.PlaySound(PS.Config.AlertSound)
    chat.AddText(Color(220, 80, 80), "[ALERTE] ", Color(220,230,245), desc)
    -- Met à jour la liste des appels
    net.Start("PS_CallList") net.SendToServer()
end)

net.Receive("PS_PatrolAssignCall", function()
    local callId = net.ReadUInt(32)
    local x = net.ReadFloat()
    local y = net.ReadFloat()
    local z = net.ReadFloat()
    PS.Tablet.Data.callAssign = { id = callId, pos = Vector(x, y, z) }
end)

-- ------- Ouverture / Fermeture -------

function PS.Tablet.Open()
    if PS.Tablet.IsOpen then return end
    PS.Tablet.IsOpen = true

    -- Demande les données fraîches
    net.Start("PS_GetMyData")    net.SendToServer()
    net.Start("PS_PatrolList")   net.SendToServer()
    net.Start("PS_CallList")     net.SendToServer()
    net.Start("PS_RollCallRequest") net.SendToServer()

    PS.Tablet.BuildUI()
end

function PS.Tablet.Close()
    if not PS.Tablet.IsOpen then return end
    PS.Tablet.IsOpen = false
    if IsValid(PS.Tablet.Frame) then
        PS.Tablet.Frame:Remove()
        PS.Tablet.Frame = nil
    end
end

function PS.Tablet.RefreshIfOpen()
    if PS.Tablet.IsOpen and IsValid(PS.Tablet.Frame) then
        PS.Tablet.RebuildContent()
    end
end

-- ------- Construction de l'UI -------

function PS.Tablet.BuildUI()
    if IsValid(PS.Tablet.Frame) then PS.Tablet.Frame:Remove() end

    local SW, SH   = ScrW(), ScrH()
    local TW, TH   = math.min(SW - 80, 980), math.min(SH - 60, 700)
    local TX, TY   = (SW - TW) / 2, (SH - TH) / 2

    local frame = vgui.Create("DFrame")
    PS.Tablet.Frame = frame
    frame:SetPos(TX, TY)
    frame:SetSize(TW, TH)
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    -- Curseur personnalisé visible
    frame:SetCursor("arrow")

    -- Fond principal + animation de "boot"
    local alpha     = 0
    local animDone  = false
    frame.Paint = function(s, w, h)
        if alpha < 255 then alpha = math.min(255, alpha + 18) end

        -- Fond tablette
        surface.SetDrawColor(PS.Config.Colors.Background.r, PS.Config.Colors.Background.g, PS.Config.Colors.Background.b, alpha)
        surface.DrawRect(0, 0, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(PS.Config.Colors.Background.r, PS.Config.Colors.Background.g, PS.Config.Colors.Background.b, alpha))

        -- Barre de titre
        draw.RoundedBoxEx(14, 0, 0, w, 50, Color(PS.Config.Colors.Header.r, PS.Config.Colors.Header.g, PS.Config.Colors.Header.b, alpha), true, true, false, false)
        surface.SetDrawColor(PS.Config.Colors.Accent.r, PS.Config.Colors.Accent.g, PS.Config.Colors.Accent.b, alpha)
        surface.DrawRect(0, 50, w, 2)

        -- Titre
        local my = PS.Tablet.Data.myData
        local nameStr = my and (my.firstname .. " " .. string.upper(my.lastname)) or LocalPlayer():Name()
        local rankKey = LocalPlayer():GetNWString("PS_Rank", PS.Config.DefaultRank)
        local rankInfo = PS.Config.Ranks[rankKey]
        local rankStr  = rankInfo and rankInfo.label or "Officier"

        draw.SimpleText("TABLETTE POLICE", "DermaLarge", 20, 25, Color(PS.Config.Colors.Accent.r, PS.Config.Colors.Accent.g, PS.Config.Colors.Accent.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(nameStr .. "  •  " .. rankStr, "DermaDefault", w - 20, 25, Color(PS.Config.Colors.TextDim.r, PS.Config.Colors.TextDim.g, PS.Config.Colors.TextDim.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- Heure
        draw.SimpleText(os.date("%H:%M"), "DermaDefaultBold", w / 2, 25, Color(PS.Config.Colors.Text.r, PS.Config.Colors.Text.g, PS.Config.Colors.Text.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Bouton fermer
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(TW - 40, 12)
    closeBtn:SetSize(28, 28)
    closeBtn:SetText("✕")
    closeBtn:SetFont("DermaDefaultBold")
    closeBtn:SetTextColor(PS.Config.Colors.TextDim)
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then draw.RoundedBox(7, 0, 0, w, h, PS.Config.Colors.Danger) end
    end
    closeBtn.DoClick = function() PS.Tablet.Close() end

    -- Barre d'onglets
    local tabs = {
        { key = "map",        label = "Carte"       },
        { key = "dispatch",   label = "Dispatch"    },
        { key = "census",     label = "Recensement" },
        { key = "records",    label = "Casiers"     },
        { key = "rollcall",   label = "Appel"       },
        { key = "agentfile",  label = "Profil Agent"},
    }

    local tabBar = vgui.Create("DPanel", frame)
    tabBar:SetPos(0, 52)
    tabBar:SetSize(TW, 40)
    tabBar.Paint = function() end

    local tabBtns = {}
    local tabW = math.floor(TW / #tabs)
    for i, t in ipairs(tabs) do
        local btn = vgui.Create("DButton", tabBar)
        btn:SetPos((i - 1) * tabW, 0)
        btn:SetSize(tabW, 40)
        btn:SetText("")
        local tk = t.key
        local tl = t.label
        btn.Paint = function(s, w, h)
            local active  = PS.Tablet.ActiveTab == tk
            local hovered = s:IsHovered()
            local bg = active  and PS.Config.Colors.Accent
                    or hovered and PS.Config.Colors.Header
                    or Color(25, 35, 58, 255)
            draw.RoundedBox(0, 0, 0, w, h, bg)
            local tc = active and Color(255,255,255) or PS.Config.Colors.TextDim
            draw.SimpleText(tl, "DermaDefault", w/2, h/2, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if active then
                surface.SetDrawColor(PS.Config.Colors.Accent)
                surface.DrawRect(0, h - 2, w, 2)
            end
        end
        btn.DoClick = function()
            PS.Tablet.ActiveTab = tk
            PS.Tablet.RebuildContent()
        end
        tabBtns[tk] = btn
    end

    -- Zone de contenu
    PS.Tablet.ContentPanel = vgui.Create("DPanel", frame)
    PS.Tablet.ContentPanel:SetPos(0, 92)
    PS.Tablet.ContentPanel:SetSize(TW, TH - 92)
    PS.Tablet.ContentPanel.Paint = function() end

    PS.Tablet.RebuildContent()
end

function PS.Tablet.RebuildContent()
    if not IsValid(PS.Tablet.ContentPanel) then return end
    PS.Tablet.ContentPanel:Clear()

    local tab = PS.Tablet.ActiveTab
    if     tab == "map"       then PS.TabletMap.Build(PS.Tablet.ContentPanel)
    elseif tab == "dispatch"  then PS.TabletDispatch.Build(PS.Tablet.ContentPanel)
    elseif tab == "census"    then PS.TabletCensus.Build(PS.Tablet.ContentPanel)
    elseif tab == "records"   then PS.TabletRecords.Build(PS.Tablet.ContentPanel)
    elseif tab == "rollcall"  then PS.TabletRollcall.Build(PS.Tablet.ContentPanel)
    elseif tab == "agentfile" then PS.TabletAgentFile.Build(PS.Tablet.ContentPanel)
    end
end

-- ------- Prise / fin de service -------
-- Les policiers peuvent prendre/quitter leur service depuis la tablette.
-- Également accessible via le chat.

hook.Add("InitPostEntity", "PS_TabletInit", function()
    -- Demande les données initiales si policier
    timer.Simple(2, function()
        if PS.Utils.IsPolice(LocalPlayer()) then
            net.Start("PS_GetMyData") net.SendToServer()
        end
    end)
end)
