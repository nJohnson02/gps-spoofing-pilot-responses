-- =============================================================
-- C172 G1000 GPS SPOOFING SCENARIO (V24 - PHYSICS TRANSLATION)
-- "Parallel Ghost Track"
-- Based on the stable V20 architecture.
-- Math: Calculates Real XTE and subtracts a linear offset.
-- =============================================================

logMsg("SPOOF: Loading V24 (Physics Translation)...")

-- =============================================================
-- 1. DATAREF TARGETING
-- =============================================================

local TARGETS = {
    -- INJECTORS (Write)
    override_gps    = "sim/operation/override/override_gps",
    hdef_dot        = "sim/cockpit/radios/gps_hdef_dot", 
    zulu_time       = "sim/time/zulu_time_sec",
    xpndr_fail      = "sim/operation/failures/rel_xpndr",

    -- SENSORS (Read Only Physics)
    real_lat        = "sim/flightmodel/position/latitude",
    real_lon        = "sim/flightmodel/position/longitude",
    real_psi        = "sim/flightmodel/position/psi" -- True Heading
}

-- Validate Refs
local VALID_REFS = {}
function validate_datarefs()
    for name, path in pairs(TARGETS) do
        local ref = XPLMFindDataRef(path)
        if ref then
            VALID_REFS[name] = path
        else
            logMsg("SPOOF: Missing -> " .. path)
        end
    end
end
validate_datarefs()

-- =============================================================
-- 2. STATE VARIABLES
-- =============================================================

local attack_active = false

-- The "Anchor" (Original Course Line)
local origin_lat = 0
local origin_lon = 0
local origin_heading = 0 

-- The Drift Offset
local current_drift_nm = 0

local CONFIG = {
    -- DRIFT RATE (NM per frame)
    -- 0.0003 is approx 0.5 NM per minute.
    drift_rate_nm = 0.0003,
    
    -- SENSITIVITY (For Dot Conversion)
    -- 0.3 NM = Full Scale (Approach Mode)
    full_scale_nm = 0.3,
    
    -- JITTER
    jitter_sec = 45
}

-- =============================================================
-- 3. MATH HELPERS
-- =============================================================

local D2R = math.pi / 180.0
local R2D = 180.0 / math.pi
local ERAD = 6371000

-- Calculate Distance (m) and Bearing (deg)
function get_geo_vector(lat1, lon1, lat2, lon2)
    local dLat = (lat2 - lat1) * D2R
    local dLon = (lon2 - lon1) * D2R
    local a = math.sin(dLat/2) * math.sin(dLat/2) +
              math.cos(lat1 * D2R) * math.cos(lat2 * D2R) *
              math.sin(dLon/2) * math.sin(dLon/2)
    local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    local dist_m = ERAD * c
    
    local y = math.sin(dLon) * math.cos(lat2 * D2R)
    local x = math.cos(lat1 * D2R) * math.sin(lat2 * D2R) -
              math.sin(lat1 * D2R) * math.cos(lat2 * D2R) * math.cos(dLon)
    local brg = math.atan2(y, x) * R2D
    
    return dist_m, (brg + 360) % 360
end

-- =============================================================
-- 4. MAIN LOGIC LOOP
-- =============================================================

function run_spoof_logic()
    -- Safety
    if not attack_active then
        if VALID_REFS.override_gps then set(VALID_REFS.override_gps, 0) end
        return
    end

    if VALID_REFS.override_gps then set(VALID_REFS.override_gps, 1) end

    -- === 1. INCREMENT GHOST DRIFT (Translation) ===
    -- This pushes the "Ghost Line" further away from the "Real Line"
    -- We assume drift to the RIGHT (+), so Ghost Line is Right of Real Line.
    current_drift_nm = current_drift_nm + CONFIG.drift_rate_nm

    -- === 2. CALCULATE REAL XTE (Physics) ===
    local curr_lat = get(VALID_REFS.real_lat)
    local curr_lon = get(VALID_REFS.real_lon)
    
    -- Vector from Anchor -> Plane
    local dist_m, bearing_to_plane = get_geo_vector(origin_lat, origin_lon, curr_lat, curr_lon)
    
    -- Angle Difference (Plane Bearing vs Track Heading)
    local angle_diff = (bearing_to_plane - origin_heading)
    
    -- Real XTE in NM (Positive = Plane is Right of Track)
    local real_xte_m = dist_m * math.sin(angle_diff * D2R)
    local real_xte_nm = real_xte_m / 1852.0
    
    -- === 3. CALCULATE SPOOFED NEEDLE ===
    -- The instrument should show the distance from the GHOST line, not the Real line.
    -- Indicated Error = (Where I am) - (Where the Ghost Line is)
    -- If Ghost Line is 1 NM Right (+1), and I am 1 NM Right (+1), result is 0 (Centered).
    local indicated_xte_nm = real_xte_nm - current_drift_nm
    
    -- Convert to Dots
    local h_dots = (indicated_xte_nm / CONFIG.full_scale_nm) * 2.0
    
    -- Clamp (-2.5 to 2.5)
    if h_dots > 2.5 then h_dots = 2.5 end
    if h_dots < -2.5 then h_dots = -2.5 end
    
    -- Inject (Invert sign because +XTE usually means "Needle Left")
    if VALID_REFS.hdef_dot then set(VALID_REFS.hdef_dot, -h_dots) end

    -- === 4. CLOCK JITTER ===
    if VALID_REFS.zulu_time then
        local jitter = math.sin(os.clock() * 15) * CONFIG.jitter_sec
        local current_time = get(VALID_REFS.zulu_time)
        set(VALID_REFS.zulu_time, current_time + (jitter * 0.01))
    end
end

do_every_frame("run_spoof_logic()")

-- =============================================================
-- 5. CONTROLS
-- =============================================================

function toggle_attack()
    attack_active = not attack_active
    
    if attack_active then
        -- SNAPSHOT ORIGIN
        origin_lat = get(VALID_REFS.real_lat)
        origin_lon = get(VALID_REFS.real_lon)
        origin_heading = get(VALID_REFS.real_psi)
        
        -- RESET DRIFT
        current_drift_nm = 0
        
        -- FAIL XPDR
        if VALID_REFS.xpndr_fail then set(VALID_REFS.xpndr_fail, 6) end
        
    else
        -- STOP ATTACK
        if VALID_REFS.xpndr_fail then set(VALID_REFS.xpndr_fail, 0) end
        if VALID_REFS.override_gps then set(VALID_REFS.override_gps, 0) end
    end
end

-- =============================================================
-- 6. GUI
-- =============================================================

function draw_spoof_gui()
    imgui.TextUnformatted("GPS SPOOF V24")
    imgui.TextUnformatted("Physics Translation")
    imgui.Separator()
    
    if attack_active then
        imgui.TextUnformatted("!!! TRACK SHIFTING !!!")
        
        local off_str = string.format("Ghost Shift: %.2f NM", current_drift_nm)
        imgui.TextUnformatted(off_str)
        
    else
        imgui.TextUnformatted("... SIGNAL CLEAR ...")
    end
    
    imgui.Dummy(10,5)
    
    if imgui.Button(attack_active and "CEASE ATTACK" or "INITIATE ATTACK") then
        toggle_attack()
    end
    
    imgui.Dummy(10,5)
    imgui.Separator()
    
    imgui.TextUnformatted("Active Effects:")
    
    if attack_active then
        imgui.TextUnformatted("[X] Parallel Track Shift")
        imgui.TextUnformatted("[X] Clock Jitter")
        imgui.TextUnformatted("[X] XPDR Hard Fail")
    else
        imgui.TextUnformatted("[ ] Parallel Track Shift")
        imgui.TextUnformatted("[ ] Clock Jitter")
        imgui.TextUnformatted("[ ] XPDR Hard Fail")
    end
end

spoof_wnd = float_wnd_create(250, 350, 1, true)
float_wnd_set_title(spoof_wnd, "Spoof V24")
float_wnd_set_imgui_builder(spoof_wnd, "draw_spoof_gui")
