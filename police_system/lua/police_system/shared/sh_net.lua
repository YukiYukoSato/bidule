-- ============================================================
--  police_system/shared/sh_net.lua
--  Déclaration de tous les messages réseau (shared)
-- ============================================================

local strings = {
    -- Grades
    "PS_GetMyData",
    "PS_MyData",
    "PS_SetGrade",
    "PS_GradeUpdated",
    "PS_OfficersListRequest",
    "PS_OfficersList",

    -- Armurier
    "PS_ArmorerOpen",
    "PS_ArmorerBuy",
    "PS_ArmorerResult",

    -- Tablette / Blips
    "PS_TabletOpen",
    "PS_BlipsUpdate",
    "PS_OnDuty",
    "PS_OffDuty",

    -- Détresse
    "PS_Distress",
    "PS_DistressAck",
    "PS_DistressClear",
    "PS_DistressList",

    -- Dispatch / Patrouilles
    "PS_PatrolCreate",
    "PS_PatrolUpdate",
    "PS_PatrolDelete",
    "PS_PatrolList",
    "PS_PatrolAssignCall",

    -- Appels / Interventions
    "PS_CallNew",
    "PS_CallUpdate",
    "PS_CallList",
    "PS_CallEnRoute",
    "PS_CallFinish",
    "PS_GunshotAlert",

    -- Recensement
    "PS_CensusAdd",
    "PS_CensusSearch",
    "PS_CensusResults",
    "PS_CensusAmend",
    "PS_CensusImprison",

    -- Casier judiciaire
    "PS_RecordAdd",
    "PS_RecordGet",
    "PS_RecordData",

    -- Casier agent
    "PS_AgentNoteAdd",
    "PS_AgentNoteGet",
    "PS_AgentNoteData",

    -- Appel (roll-call / dispatch présence)
    "PS_RollCallRequest",
    "PS_RollCallData",
    "PS_RollCallMark",

    -- Administration
    "PS_AdminSetRank",
    "PS_AdminGivePermission",
}

for _, name in ipairs(strings) do
    util.AddNetworkString and util.AddNetworkString(name)
end
