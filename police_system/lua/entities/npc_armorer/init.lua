-- ============================================================
--  entities/npc_armorer/init.lua
--  Logique serveur du PNJ armurier
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.Model        = "models/police.mdl"  -- modèle GMod standard policier
ENT.IdleAnim     = ACT_IDLE

function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetSolid(SOLID_BBOX)
    self:SetNPCState(NPC_STATE_IDLE)
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:CapabilitiesAdd(CAP_TURN_HEAD)
    self:SetMaxHealth(1000)
    self:SetHealth(1000)
    self:SetSchedule(SCHED_IDLE_STAND)
    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not PS.Utils.IsPolice(activator) then
        activator:ChatPrint("[Armurier] Désolé, je ne sers que les membres des forces de l'ordre.")
        return
    end
    -- Ouvre le menu côté client
    net.Start("PS_ArmorerOpen")
    net.Send(activator)
end

function ENT:OnTakeDamage(dmg)
    -- Invincible
    self:SetHealth(self:GetMaxHealth())
end

-- Réception achat
net.Receive("PS_ArmorerBuy", function(_, ply)
    if not PS.Utils.IsPolice(ply) then return end
    local json = net.ReadString()
    local data = PS.Utils.FromJSON(json)
    if not data then return end

    local category = data.category
    local itemIdx  = tonumber(data.item) or 1
    local catData  = PS.Config.ArmoryCatalog[category]

    if not catData then
        net.Start("PS_ArmorerResult") net.WriteString("Catégorie inconnue.") net.Send(ply)
        return
    end

    -- Vérif grade pour armes lourdes
    if catData.minRank and not PS.Utils.RankGTE(PS.Utils.GetRank(ply), catData.minRank) then
        net.Start("PS_ArmorerResult") net.WriteString("Grade insuffisant pour accéder à cette catégorie.") net.Send(ply)
        return
    end

    -- Vérif permission sniper
    if catData.permission == "sniper" and not PS.Utils.CanSniper(ply) then
        net.Start("PS_ArmorerResult") net.WriteString("Vous n'avez pas l'habilitation pour les snipers.") net.Send(ply)
        return
    end

    local item = catData.items[itemIdx]
    if not item then
        net.Start("PS_ArmorerResult") net.WriteString("Article introuvable.") net.Send(ply)
        return
    end

    -- Vérif argent (DarkRP)
    local price = item.price or 0
    if ply.getDarkRPVar then
        local wallet = ply:getDarkRPVar("money") or 0
        if wallet < price then
            net.Start("PS_ArmorerResult") net.WriteString("Fonds insuffisants. Il vous faut " .. price .. "$.") net.Send(ply)
            return
        end
        ply:addMoney(-price)
    end

    -- Donne l'article
    if item.armor then
        ply:SetArmor(math.min(100, ply:Armor() + item.armor))
    end
    if item.weapon then
        ply:Give(item.weapon)
    end

    net.Start("PS_ArmorerResult") net.WriteString("OK:" .. item.label) net.Send(ply)
end)

-- Spawn via commande
concommand.Add("ps_spawnarmorer", function(caller, _, _)
    if not IsValid(caller) or not caller:IsSuperAdmin() then return end
    local npc = ents.Create("npc_armorer")
    npc:SetPos(caller:GetPos() + caller:GetForward() * 80)
    npc:SetAngles(Angle(0, caller:GetAngles().y + 180, 0))
    npc:Spawn()
    npc:Activate()
    caller:ChatPrint("[PS] Armurier créé.")
end)
