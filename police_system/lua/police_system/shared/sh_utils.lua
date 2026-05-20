-- ============================================================
--  police_system/shared/sh_utils.lua
--  Fonctions utilitaires partagées
-- ============================================================

PS = PS or {}
PS.Utils = {}

-- Retourne true si le joueur est policier selon PS.Config.PoliceJobs
function PS.Utils.IsPolice(ply)
    if not IsValid(ply) then return false end
    -- DarkRP
    if ply.getDarkRPVar then
        local job = ply:getDarkRPVar("job")
        if job then
            job = string.lower(job)
            for _, j in ipairs(PS.Config.PoliceJobs) do
                if string.find(job, string.lower(j)) then return true end
            end
        end
    end
    -- Fallback : usergroup ou team
    if ply:IsUserGroup("police") then return true end
    return false
end

-- Retourne le grade d'un joueur (string key)
function PS.Utils.GetRank(ply)
    if not IsValid(ply) then return PS.Config.DefaultRank end
    return ply:GetNWString("PS_Rank", PS.Config.DefaultRank)
end

-- Retourne les infos de grade depuis la config
function PS.Utils.GetRankInfo(rankKey)
    return PS.Config.Ranks[rankKey] or PS.Config.Ranks[PS.Config.DefaultRank]
end

-- Retourne true si le grade A est >= grade B (par index numérique)
function PS.Utils.RankGTE(rankA, rankB)
    local a = PS.Utils.GetRankInfo(rankA)
    local b = PS.Utils.GetRankInfo(rankB)
    if not a or not b then return false end
    return a.rank >= b.rank
end

-- Retourne vrai si le joueur peut accéder aux armes lourdes
function PS.Utils.CanHeavy(ply)
    local info = PS.Utils.GetRankInfo(PS.Utils.GetRank(ply))
    return info and info.heavy == true
end

-- Retourne vrai si le joueur peut accéder au sniper
function PS.Utils.CanSniper(ply)
    local info = PS.Utils.GetRankInfo(PS.Utils.GetRank(ply))
    return info and info.sniper == true
end

-- Retourne vrai si le joueur est lieutenant ou plus
function PS.Utils.IsLieutenantPlus(ply)
    return PS.Utils.RankGTE(PS.Utils.GetRank(ply), "lieutenant")
end

-- Retourne vrai si le joueur est sergent ou plus
function PS.Utils.IsSergeantPlus(ply)
    return PS.Utils.RankGTE(PS.Utils.GetRank(ply), "sergeant")
end

-- Retourne vrai si le joueur est chef de la police
function PS.Utils.IsChief(ply)
    return PS.Utils.GetRank(ply) == "chief"
end

-- Distance entre deux entités
function PS.Utils.Distance(a, b)
    if not IsValid(a) or not IsValid(b) then return math.huge end
    return a:GetPos():Distance(b:GetPos())
end

-- Formate une date/heure à partir d'un timestamp unix
function PS.Utils.FormatTime(ts)
    ts = ts or os.time()
    return os.date("%d/%m/%Y %H:%M", ts)
end

-- Troncature d'un string pour l'affichage
function PS.Utils.Truncate(str, maxLen)
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 3) .. "..."
end

-- Sérialise un tableau en JSON (côté client et serveur)
function PS.Utils.ToJSON(t)
    return util.TableToJSON(t)
end

function PS.Utils.FromJSON(str)
    return util.JSONToTable(str) or {}
end
