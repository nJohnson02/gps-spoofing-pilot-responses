-- =============================================================
-- C172 G1000 GPS SPOOFING SCENARIO (V15 - FINAL)
-- "Ghost Drift"
-- Targets: Cross-Track Error (XTE), Clock Jitter, XPDR Fail
-- Excludes: Pitot/Static (Airspeed), Wandering Signals
-- =============================================================

logMsg("SPOOF: Loading V15 (Ghost Drift)...")

-- =============================================================
-- 1. DATAREF TARGETING
-- =============================================================

local TARGETS = {
    -- MASTER OVERRIDE (Unlocks the XTE and Time vars)
    override_gps    = "sim/operation/override/override_gps",

    -- NAVIGATION: Cross Track Error (Nautical Miles)
    -- This is the "Result" of Lat/Lon spoofing. 
    -- If we force this to grow, the AP thinks we are drifting away from the line.
    xte_nm          = "sim/cockpit/radios/gps_x_track_nm",
    
    -- Fallback: Horizontal Dots (If XTE missing)
    hdef_dot        = "sim/cockpit/radios/gps_hdef_dot",

    -- TIME: Zulu Clock (The User Favorite)
    zulu_time       = "sim/time/zulu_time_sec",
    
    -- SYSTEM: Transponder Failure Flag (Amber 'XPDR FAIL')
    -- 6 = Total Failure
    xpndr_fail      = "sim/operation/failures/rel_xpndr"
}

-- Validate Refs (Log what we find)
local VALID_REFS = {}
function validate_datarefs()
    for name, path in pairs(TARGETS) do
        local ref = XPLMFindDataRef(path)
        if ref then
            VALID_REFS[name] = path
            logMsg("SPOOF: Found -> " .. path)
        else
            logMsg("SPOOF: Missing -> " .. path)
        end
    end
end
validate_datarefs()

-- =============================================================
-- 2. ATTACK CONFIGURATION
-- =============================================================

local attack_active = false

-- Accumulator for the position error
local drift_nm_accum = 0

local CONFIG = {
    -- Drift Rate (Nautical Miles per frame)
    -- 0.0005 is roughly 0.03 NM per second (2 NM per minute)
    -- This is fast enough to see, slow enough to feel "real".
    drift_rate_nm = 0.0005,
    
    -- Max Drift (Stops increasing error after this distance)
    max_drift_nm  = 5.0,
    
    -- Clock Jitter Intensity (Seconds)
    jitter_sec    = 45
}

-- =============================================================
-- 3. MAIN LOGIC
-- =============================================================

function run_spoof_logic()
    -- Safety: If not attacking, ensure override is OFF
    if not attack_active then
        if VALID_REFS.override_gps then set(VALID_REFS.override_gps, 0) end
        return
    end

    -- 1. ENABLE OVERRIDE
    if VALID_REFS.override_gps then set(VALID_REFS.override_gps, 1) end

    -- 2. NAVIGATION DRIFT (The "Ghost Position")
    if VALID_REFS.xte_nm then
        -- Linearly increase the error
        if drift_nm_accum < CONFIG.max_drift_nm then
            drift_nm_accum = drift_nm_accum + CONFIG.drift_rate_nm
        end
        
        -- Apply the error.
        -- Setting this POSITIVE (+) usually means "You are Right of Course" -> AP turns Left.
        -- Setting this NEGATIVE (-) usually means "You are Left of Course" -> AP turns Right.
        -- We will set it NEGATIVE to force a RIGHT turn.
        set(VALID_REFS.xte_nm, -drift_nm_accum)
        
    elseif VALID_REFS.hdef_dot then
        -- Fallback if NM var is missing (uses dots instead)
        if drift_nm_accum < 2.5 then
            drift_nm_accum = drift_nm_accum + 0.002 -- Slower rate for dots
        end
        set(VALID_REFS.hdef_dot, -drift_nm_accum)
    end

    -- 3. CLOCK JITTER (The Signature)
    if VALID_REFS.zulu_time then
        -- Sine wave jitter to create "Time Dilation" effect
        local jitter = math.sin(os.clock() * 15) * CONFIG.jitter_sec
        local current_time = get(VALID_REFS.zulu_time)
        set(VALID_REFS.zulu_time, current_time + (jitter * 0.01))
    end
end

do_every_frame("run_spoof_logic()")

-- =============================================================
-- 4. CONTROLS
-- =============================================================

function toggle_attack()
    attack_active = not attack_active
    
    if attack_active then
        -- Start Attack: Reset Drift to 0 so it ramps up smoothly
        drift_nm_accum = 0
        
        -- FAIL THE TRANSPONDER (Hard Fail)
        if VALID_REFS.xpndr_fail then set(VALID_REFS.xpndr_fail, 6) end
        
    else
        -- Stop Attack: Fix Transponder
        if VALID_REFS.xpndr_fail then set(VALID_REFS.xpndr_fail, 0) end
        
        -- Release GPS Control
        if VALID_REFS.override_gps then set(VALID_REFS.override_gps, 0) end
    end
end

-- =============================================================
-- 5. GUI DISPLAY
-- =============================================================

function draw_spoof_gui()
    imgui.TextUnformatted("GPS SPOOF V15")
    imgui.TextUnformatted("Scenario: PANC Ghost Drift")
    imgui.Separator()
    
    if attack_active then
        imgui.TextUnformatted("!!! JAMMING ACTIVE !!!")
        
        -- Dynamic drift readout
        local drift_str = string.format("Drift Error: %.2f NM", drift_nm_accum)
        imgui.TextUnformatted(drift_str)
    else
        imgui.TextUnformatted("... SIGNAL CLEAR ...")
    end
    
    imgui.Dummy(10,5)
    
    if imgui.Button(attack_active and "CEASE ATTACK" or "INITIATE ATTACK") then
        toggle_attack()
    end
    
    imgui.Dummy(10,5)
    imgui.Separator()
    
    imgui.TextUnformatted("Active Symptoms:")
    
    if attack_active then
        -- XTE Status
        if VALID_REFS.xte_nm then
            imgui.TextUnformatted("[X] Cross-Track Drift (NM)")
        elseif VALID_REFS.hdef_dot then
            imgui.TextUnformatted("[X] Deviation Drift (Fallback)")
        else
            imgui.TextUnformatted("[!] Nav Refs Missing")
        end
        
        -- Other Status
        if VALID_REFS.zulu_time then
            imgui.TextUnformatted("[X] Clock Jitter")
        else
            imgui.TextUnformatted("[!] Clock Ref Missing")
        end
        
        if VALID_REFS.xpndr_fail then
            imgui.TextUnformatted("[X] XPDR Hard Fail")
        else
            imgui.TextUnformatted("[!] XPDR Ref Missing")
        end
        
    else
        imgui.TextUnformatted("[ ] Cross-Track Drift")
        imgui.TextUnformatted("[ ] Clock Jitter")
        imgui.TextUnformatted("[ ] XPDR Hard Fail")
    end
end

spoof_wnd = float_wnd_create(250, 350, 1, true)
float_wnd_set_title(spoof_wnd, "Spoof V15")
float_wnd_set_imgui_builder(spoof_wnd, "draw_spoof_gui")
