-- =============================================================
-- C172 G1000 GPS SPOOFING SCENARIO (V30 - LIVE INPUTS)
-- "Unified Drift + Live Configuration Inputs"
-- 
-- UPDATES V30:
-- 1. INPUT BOXES: Added imgui.InputFloat fields to GUI.
--    Allows changing Rates and Max Deviations at runtime.
-- 2. PERSISTENCE: Defaults are set in CONFIG table below.
-- =============================================================

logMsg("SPOOF: Loading V30 (Live Inputs)...")

-- =============================================================
-- 1. CONFIGURATION (DEFAULTS)
-- =============================================================

local CONFIG = {
    -- H_DRIFT: 0.0001 is approx 0.5 NM per minute
    rate_h_nm = 0.0001,
    max_h_nm  = 2.0, 

    -- V_DRIFT: 0.05 is approx 150 fpm
    rate_v_m  = 0.05,
    max_v_m   = 300.0,

    -- SCALING (Instrument Sensitivity)
    scale_h_nm = 0.3,    -- HSI Full Scale
    scale_v_m  = 150.0,  -- VDI Full Scale
    
    -- JITTER
    jitter_amp = 45      -- Seconds
}

-- =============================================================
-- 2. DATAREFS
-- =============================================================

local D = {
    -- WRITE
    override  = "sim/operation/override/override_gps",
    h_dot     = "sim/cockpit/radios/gps_hdef_dot", 
    v_dot     = "sim/cockpit/radios/gps_vdef_dot", 
    time_sec  = "sim/time/zulu_time_sec",
    xpdr_fail = "sim/operation/failures/rel_xpndr",

    -- READ
    lat       = "sim/flightmodel/position/latitude",
    lon       = "sim/flightmodel/position/longitude",
    ele       = "sim/flightmodel/position/elevation",
    psi       = "sim/flightmodel/position/psi"
}

for k, v in pairs(D) do
    if not XPLMFindDataRef(v) then logMsg("SPOOF ERR: Missing " .. v) end
end

-- =============================================================
-- 3. STATE MANAGEMENT
-- =============================================================

local state = {
    drift_active = false,
    xpdr_active = false,
    jitter_active = false,
    
    -- Soft Lock Offsets
    lock_h_dots = 0,
    lock_v_dots = 0,
    
    -- Drifts
    drift_h = 0,
    drift_v = 0
}

local anchor = { lat=0, lon=0, alt=0, hdg=0, set=false }

-- =============================================================
-- 4. MATH CORE
-- =============================================================

local D2R = math.pi / 180.0
local ERAD = 6371000

function get_geo_vector(lat1, lon1, lat2, lon2)
    local dLat = (lat2 - lat1) * D2R
    local dLon = (lon2 - lon1) * D2R
    local a = math.sin(dLat/2)^2 + math.cos(lat1*D2R) * math.cos(lat2*D2R) * math.sin(dLon/2)^2
    local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    local d = ERAD * c
    local y = math.sin(dLon) * math.cos(lat2*D2R)
    local x = math.cos(lat1*D2R) * math.sin(lat2*D2R) - math.sin(lat1*D2R) * math.cos(lat2*D2R) * math.cos(dLon)
    local b = math.atan2(y, x) * 180 / math.pi
    return d, (b + 360) % 360
end

function clamp_dots(val)
    if val > 2.5 then return 2.5 end
    if val < -2.5 then return -2.5 end
    return val
end

-- =============================================================
-- 5. LOGIC LOOP
-- =============================================================

function run_spoof_v30()
    -- 1. DRIFT LOGIC (Unified)
    if state.drift_active then
        set(D.override, 1)

        if not anchor.set then
            anchor.lat = get(D.lat)
            anchor.lon = get(D.lon)
            anchor.alt = get(D.ele)
            anchor.hdg = get(D.psi)
            anchor.set = true
        end

        local curr_lat, curr_lon = get(D.lat), get(D.lon)
        local dist_m, bearing = get_geo_vector(anchor.lat, anchor.lon, curr_lat, curr_lon)
        local angle_diff = bearing - anchor.hdg
        
        local real_xte_m = dist_m * math.sin(angle_diff * D2R)
        local real_xte_nm = real_xte_m / 1852.0
        local real_vde_m = get(D.ele) - anchor.alt

        -- ACCUMULATE DRIFT (Using dynamic CONFIG values)
        if state.drift_h < CONFIG.max_h_nm then
            state.drift_h = state.drift_h + CONFIG.rate_h_nm
        end

        if state.drift_v > -CONFIG.max_v_m then
            state.drift_v = state.drift_v - CONFIG.rate_v_m
        end

        -- INJECT
        local ind_xte_nm = real_xte_nm - state.drift_h
        local h_dots = (ind_xte_nm / CONFIG.scale_h_nm) * 2.0
        set(D.h_dot, -clamp_dots(h_dots + state.lock_h_dots))

        local ind_vde_m = real_vde_m - state.drift_v
        local v_dots = (ind_vde_m / CONFIG.scale_v_m) * 2.0
        set(D.v_dot, -clamp_dots(v_dots + state.lock_v_dots))

    else
        set(D.override, 0)
        anchor.set = false
    end
    
    -- 2. JITTER
    if state.jitter_active then
        local j = math.sin(os.clock() * 15) * CONFIG.jitter_amp
        set(D.time_sec, get(D.time_sec) + (j * 0.01))
    end
end

do_every_frame("run_spoof_v30()")

-- =============================================================
-- 6. TOGGLE FUNCTIONS
-- =============================================================

function toggle_drift()
    state.drift_active = not state.drift_active
    if state.drift_active then
        state.drift_h = 0
        state.drift_v = 0
        state.lock_h_dots = -(get(D.h_dot)) 
        state.lock_v_dots = -(get(D.v_dot))
    end
end

function toggle_xpdr()
    state.xpdr_active = not state.xpdr_active
    if state.xpdr_active then set(D.xpdr_fail, 6) else set(D.xpdr_fail, 0) end
end

function toggle_jitter()
    state.jitter_active = not state.jitter_active
end

-- =============================================================
-- 7. GUI
-- =============================================================

function draw_v30_gui()
    imgui.TextUnformatted("GPS SPOOF V30 - LIVE INPUTS")
    imgui.Separator()
    
    -- STATUS READOUT
    local h_status = string.format("Current H-Drift: %.2f NM", state.drift_h)
    local v_status = string.format("Current V-Drift: %.1f M", state.drift_v)
    imgui.TextUnformatted(h_status)
    imgui.TextUnformatted(v_status)
    
    imgui.Dummy(10,10)
    imgui.Separator()
    imgui.TextUnformatted("SETTINGS (Typable)")

    -- INPUT BOXES
    -- Format: changed, val = imgui.InputFloat(label, val, step, step_fast, format)
    
    local chg_rh, new_rh = imgui.InputFloat("H Rate (NM/f)", CONFIG.rate_h_nm, 0.0001, 0.001, "%.5f")
    if chg_rh then CONFIG.rate_h_nm = new_rh end

    local chg_rv, new_rv = imgui.InputFloat("V Rate (M/f)", CONFIG.rate_v_m, 0.01, 0.1, "%.3f")
    if chg_rv then CONFIG.rate_v_m = new_rv end

    local chg_mh, new_mh = imgui.InputFloat("Max H (NM)", CONFIG.max_h_nm, 0.1, 1.0, "%.1f")
    if chg_mh then CONFIG.max_h_nm = new_mh end

    local chg_mv, new_mv = imgui.InputFloat("Max V (M)", CONFIG.max_v_m, 10.0, 50.0, "%.0f")
    if chg_mv then CONFIG.max_v_m = new_mv end

    imgui.Dummy(10,10)
    imgui.Separator()
    
    -- BUTTONS
    if imgui.Button(state.drift_active and "SPOOF NAVIGATION: ACTIVE" or "SPOOF NAVIGATION: INACTIVE") then
        toggle_drift()
    end

    imgui.Dummy(10,5)

    if imgui.Button(state.xpdr_active and "XPDR FAIL: ON" or "XPDR FAIL: OFF") then
        toggle_xpdr()
    end
    
    if imgui.Button(state.jitter_active and "TIME JITTER: ON" or "TIME JITTER: OFF") then
        toggle_jitter()
    end

end

spoof_wnd = float_wnd_create(350, 450, 1, true)
float_wnd_set_title(spoof_wnd, "Spoof V30")
float_wnd_set_imgui_builder(spoof_wnd, "draw_v30_gui")