-- ============================================================
--  police_system/server/sv_database.lua
--  Couche base de données SQLite (sql.* de GMod)
-- ============================================================

PS = PS or {}
PS.DB  = {}

-- -------------------------------------------------------
--  Initialisation : création des tables si inexistantes
-- -------------------------------------------------------
function PS.DB.Init()
    -- Table des officiers (profil policier persistant)
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_officers (
            steamid     TEXT PRIMARY KEY,
            firstname   TEXT NOT NULL DEFAULT '',
            lastname    TEXT NOT NULL DEFAULT '',
            rank        TEXT NOT NULL DEFAULT 'officer',
            permissions TEXT NOT NULL DEFAULT '[]',
            on_duty     INTEGER NOT NULL DEFAULT 0,
            last_seen   INTEGER NOT NULL DEFAULT 0,
            absent_ban  INTEGER NOT NULL DEFAULT 0
        )
    ]])

    -- Table des patrouilles actives
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_patrols (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            patrol_type TEXT NOT NULL DEFAULT 'lincoln',
            patrol_name TEXT NOT NULL DEFAULT '',
            members     TEXT NOT NULL DEFAULT '[]',
            vehicle     TEXT NOT NULL DEFAULT '',
            status      TEXT NOT NULL DEFAULT 'available',
            created_at  INTEGER NOT NULL DEFAULT 0
        )
    ]])

    -- Table des appels / interventions
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_calls (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            call_type   TEXT NOT NULL DEFAULT 'gunshot',
            position_x  REAL NOT NULL DEFAULT 0,
            position_y  REAL NOT NULL DEFAULT 0,
            position_z  REAL NOT NULL DEFAULT 0,
            description TEXT NOT NULL DEFAULT '',
            status      TEXT NOT NULL DEFAULT 'pending',
            patrols     TEXT NOT NULL DEFAULT '[]',
            created_at  INTEGER NOT NULL DEFAULT 0,
            finished_at INTEGER NOT NULL DEFAULT 0
        )
    ]])

    -- Table du recensement civil
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_census (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            steamid     TEXT NOT NULL DEFAULT '',
            firstname   TEXT NOT NULL DEFAULT '',
            lastname    TEXT NOT NULL DEFAULT '',
            age         INTEGER NOT NULL DEFAULT 0,
            birthdate   TEXT NOT NULL DEFAULT '',
            registered_at INTEGER NOT NULL DEFAULT 0,
            registered_by TEXT NOT NULL DEFAULT ''
        )
    ]])

    -- Table des casiers judiciaires
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_criminal_records (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            census_id   INTEGER NOT NULL DEFAULT 0,
            offense     TEXT NOT NULL DEFAULT '',
            date_str    TEXT NOT NULL DEFAULT '',
            time_str    TEXT NOT NULL DEFAULT '',
            details     TEXT NOT NULL DEFAULT '',
            added_by    TEXT NOT NULL DEFAULT '',
            added_at    INTEGER NOT NULL DEFAULT 0
        )
    ]])

    -- Table des casiers / notes d'agent
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_agent_notes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            officer_steamid TEXT NOT NULL DEFAULT '',
            note_type   TEXT NOT NULL DEFAULT 'note',
            content     TEXT NOT NULL DEFAULT '',
            added_by    TEXT NOT NULL DEFAULT '',
            added_at    INTEGER NOT NULL DEFAULT 0
        )
    ]])

    -- Table des appels de détresse
    sql.Query([[
        CREATE TABLE IF NOT EXISTS ps_distress (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            steamid     TEXT NOT NULL DEFAULT '',
            position_x  REAL NOT NULL DEFAULT 0,
            position_y  REAL NOT NULL DEFAULT 0,
            position_z  REAL NOT NULL DEFAULT 0,
            active      INTEGER NOT NULL DEFAULT 1,
            created_at  INTEGER NOT NULL DEFAULT 0
        )
    ]])

    print("[PS] Base de données initialisée.")
end

-- -------------------------------------------------------
--  Officiers
-- -------------------------------------------------------
function PS.DB.GetOfficer(steamid)
    local rows = sql.Query("SELECT * FROM ps_officers WHERE steamid = " .. sql.SQLStr(steamid))
    if rows and rows[1] then return rows[1] end
    return nil
end

function PS.DB.CreateOfficer(steamid, firstname, lastname)
    sql.Query(string.format(
        "INSERT OR IGNORE INTO ps_officers (steamid, firstname, lastname, rank, last_seen) VALUES (%s, %s, %s, %s, %d)",
        sql.SQLStr(steamid), sql.SQLStr(firstname), sql.SQLStr(lastname),
        sql.SQLStr(PS.Config.DefaultRank), os.time()
    ))
end

function PS.DB.UpdateOfficerRank(steamid, rank)
    sql.Query(string.format(
        "UPDATE ps_officers SET rank = %s WHERE steamid = %s",
        sql.SQLStr(rank), sql.SQLStr(steamid)
    ))
end

function PS.DB.UpdateOfficerDuty(steamid, onDuty)
    sql.Query(string.format(
        "UPDATE ps_officers SET on_duty = %d, last_seen = %d WHERE steamid = %s",
        onDuty and 1 or 0, os.time(), sql.SQLStr(steamid)
    ))
end

function PS.DB.SetAbsentBan(steamid, until_ts)
    sql.Query(string.format(
        "UPDATE ps_officers SET absent_ban = %d WHERE steamid = %s",
        until_ts, sql.SQLStr(steamid)
    ))
end

function PS.DB.GetOfficerPermissions(steamid)
    local row = PS.DB.GetOfficer(steamid)
    if not row then return {} end
    return PS.Utils.FromJSON(row.permissions)
end

function PS.DB.SetOfficerPermissions(steamid, perms)
    sql.Query(string.format(
        "UPDATE ps_officers SET permissions = %s WHERE steamid = %s",
        sql.SQLStr(PS.Utils.ToJSON(perms)), sql.SQLStr(steamid)
    ))
end

function PS.DB.GetAllOfficers()
    return sql.Query("SELECT * FROM ps_officers") or {}
end

-- -------------------------------------------------------
--  Patrouilles
-- -------------------------------------------------------
function PS.DB.CreatePatrol(patrolType, patrolName, members, vehicle)
    sql.Query(string.format(
        "INSERT INTO ps_patrols (patrol_type, patrol_name, members, vehicle, status, created_at) VALUES (%s, %s, %s, %s, 'available', %d)",
        sql.SQLStr(patrolType), sql.SQLStr(patrolName),
        sql.SQLStr(PS.Utils.ToJSON(members)), sql.SQLStr(vehicle), os.time()
    ))
    local rows = sql.Query("SELECT last_insert_rowid() as id")
    return rows and tonumber(rows[1].id) or nil
end

function PS.DB.UpdatePatrol(id, data)
    local sets = {}
    for k, v in pairs(data) do
        if type(v) == "table" then v = PS.Utils.ToJSON(v) end
        table.insert(sets, k .. " = " .. sql.SQLStr(tostring(v)))
    end
    if #sets == 0 then return end
    sql.Query(string.format(
        "UPDATE ps_patrols SET %s WHERE id = %s",
        table.concat(sets, ", "), sql.SQLStr(tostring(id))
    ))
end

function PS.DB.DeletePatrol(id)
    sql.Query("DELETE FROM ps_patrols WHERE id = " .. sql.SQLStr(tostring(id)))
end

function PS.DB.GetAllPatrols()
    return sql.Query("SELECT * FROM ps_patrols") or {}
end

-- -------------------------------------------------------
--  Appels / Interventions
-- -------------------------------------------------------
function PS.DB.CreateCall(callType, pos, description)
    sql.Query(string.format(
        "INSERT INTO ps_calls (call_type, position_x, position_y, position_z, description, status, created_at) VALUES (%s, %f, %f, %f, %s, 'pending', %d)",
        sql.SQLStr(callType), pos.x, pos.y, pos.z,
        sql.SQLStr(description), os.time()
    ))
    local rows = sql.Query("SELECT last_insert_rowid() as id")
    return rows and tonumber(rows[1].id) or nil
end

function PS.DB.UpdateCall(id, data)
    local sets = {}
    for k, v in pairs(data) do
        if type(v) == "table" then v = PS.Utils.ToJSON(v) end
        table.insert(sets, k .. " = " .. sql.SQLStr(tostring(v)))
    end
    if #sets == 0 then return end
    sql.Query(string.format("UPDATE ps_calls SET %s WHERE id = %s", table.concat(sets, ", "), sql.SQLStr(tostring(id))))
end

function PS.DB.GetActiveCalls()
    return sql.Query("SELECT * FROM ps_calls WHERE status != 'finished' ORDER BY created_at DESC") or {}
end

function PS.DB.GetFinishedCalls()
    return sql.Query("SELECT * FROM ps_calls WHERE status = 'finished' ORDER BY finished_at DESC LIMIT 50") or {}
end

-- -------------------------------------------------------
--  Recensement
-- -------------------------------------------------------
function PS.DB.AddCensus(steamid, firstname, lastname, age, birthdate, addedBy)
    sql.Query(string.format(
        "INSERT INTO ps_census (steamid, firstname, lastname, age, birthdate, registered_at, registered_by) VALUES (%s, %s, %s, %d, %s, %d, %s)",
        sql.SQLStr(steamid), sql.SQLStr(firstname), sql.SQLStr(lastname),
        age, sql.SQLStr(birthdate), os.time(), sql.SQLStr(addedBy)
    ))
    local rows = sql.Query("SELECT last_insert_rowid() as id")
    return rows and tonumber(rows[1].id) or nil
end

function PS.DB.SearchCensus(query)
    local q = sql.SQLStr("%" .. query .. "%")
    return sql.Query(string.format(
        "SELECT * FROM ps_census WHERE firstname LIKE %s OR lastname LIKE %s OR steamid LIKE %s ORDER BY lastname ASC LIMIT 30",
        q, q, q
    )) or {}
end

function PS.DB.GetCensusById(id)
    local rows = sql.Query("SELECT * FROM ps_census WHERE id = " .. sql.SQLStr(tostring(id)))
    return rows and rows[1] or nil
end

-- -------------------------------------------------------
--  Casier judiciaire
-- -------------------------------------------------------
function PS.DB.AddCriminalRecord(censusId, offense, dateStr, timeStr, details, addedBy)
    sql.Query(string.format(
        "INSERT INTO ps_criminal_records (census_id, offense, date_str, time_str, details, added_by, added_at) VALUES (%d, %s, %s, %s, %s, %s, %d)",
        censusId, sql.SQLStr(offense), sql.SQLStr(dateStr), sql.SQLStr(timeStr),
        sql.SQLStr(details), sql.SQLStr(addedBy), os.time()
    ))
end

function PS.DB.GetCriminalRecords(censusId)
    return sql.Query("SELECT * FROM ps_criminal_records WHERE census_id = " .. sql.SQLStr(tostring(censusId)) .. " ORDER BY added_at DESC") or {}
end

function PS.DB.DeleteCriminalRecord(id)
    sql.Query("DELETE FROM ps_criminal_records WHERE id = " .. sql.SQLStr(tostring(id)))
end

-- -------------------------------------------------------
--  Casier / notes d'agent
-- -------------------------------------------------------
function PS.DB.AddAgentNote(officerSteamid, noteType, content, addedBy)
    sql.Query(string.format(
        "INSERT INTO ps_agent_notes (officer_steamid, note_type, content, added_by, added_at) VALUES (%s, %s, %s, %s, %d)",
        sql.SQLStr(officerSteamid), sql.SQLStr(noteType),
        sql.SQLStr(content), sql.SQLStr(addedBy), os.time()
    ))
end

function PS.DB.GetAgentNotes(officerSteamid)
    return sql.Query(string.format(
        "SELECT * FROM ps_agent_notes WHERE officer_steamid = %s ORDER BY added_at DESC",
        sql.SQLStr(officerSteamid)
    )) or {}
end

-- -------------------------------------------------------
--  Détresse
-- -------------------------------------------------------
function PS.DB.AddDistress(steamid, pos)
    -- Supprime l'ancienne détresse du même joueur
    sql.Query("DELETE FROM ps_distress WHERE steamid = " .. sql.SQLStr(steamid))
    sql.Query(string.format(
        "INSERT INTO ps_distress (steamid, position_x, position_y, position_z, active, created_at) VALUES (%s, %f, %f, %f, 1, %d)",
        sql.SQLStr(steamid), pos.x, pos.y, pos.z, os.time()
    ))
end

function PS.DB.ClearDistress(steamid)
    sql.Query("UPDATE ps_distress SET active = 0 WHERE steamid = " .. sql.SQLStr(steamid))
end

function PS.DB.GetActiveDistress()
    return sql.Query("SELECT * FROM ps_distress WHERE active = 1") or {}
end
