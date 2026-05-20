-- ============================================================
--  entities/npc_armorer/cl_init.lua
--  Rendu côté client du PNJ armurier
-- ============================================================

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawEntityOutline()
    -- Contour bleu quand on vise le NPC
    render.SetColorModulation(0.6, 0.8, 1)
end
