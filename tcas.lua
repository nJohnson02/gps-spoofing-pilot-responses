-- =============================================================
-- TCAS RA GENERATOR (V08 - VECTOR ALIGNMENT)
-- Heading is now calculated from actual motion vector.
-- This ensures the ADS-B arrow always points correctly.
-- =============================================================

local SCRIPT_NAME = "TCAS V08 (Vector Fix)"

-- =============================================================
-- 1. DATAREF MAPPING
-- =============================================================

-- USER (Read)
local DR_user_x   = XPLMFindDataRef("sim/flightmodel/position/local_x")
local DR_user_y   = XPLMFindDataRef("sim/flightmodel/position/local_y")
local DR_user_z   = XPLMFindDataRef("sim/flightmodel/position/local_z")
local DR_user_psi = XPLMFindDataRef("sim/flightmodel/position/psi") 
local DR_user_agl = XPLMFindDataRef("sim/flightmodel/position/y_agl")

-- AI AIRCRAFT 1 (Write)
local DR_ai1_x    = XPLMFindDataRef("sim/multiplayer/position/plane1_x")
local DR_ai1_y    = XPLMFindDataRef("sim/multiplayer/position/plane1_y")
local DR_ai1_z    = XPLMFindDataRef("sim/multiplayer/position/plane1_z")
local DR_ai1_psi  = XPLMFindDataRef("sim/multiplayer/position/plane1_psi")
local DR_ai1_the  = XPLMFindDataRef("sim/multiplayer/position/plane1_the")
local DR_ai1_phi  = XPLMFindDataRef("sim/multiplayer/position/plane1_phi")

-- OVERRIDE
local DR_override = XPLMFindDataRef("sim/operation/override/override_plane_ai_1")

-- =============================================================
-- 2. CONFIG & STATE
-- =============================================================

local active = false
local current_dist_m = 0
local START_DIST_NM = 5.0
local SPEED_KTS = 600 

local NM_TO_M = 1852.0
local D2R = math.pi / 180.0
local R2D = 180.0 / math.pi

-- HISTORY (For Vector Calculation)
local prev_g_x = 0
local prev_g_z = 0
local has_history = false

-- =============================================================
-- 3. LOGIC LOOP
-- =============================================================

function loop_tcas_vector()
    -- 1. Override Control
    if DR_override then
        if active then
            XPLMSetDatai(DR_override, 1)
        else
            XPLMSetDatai(DR_override, 0)
            -- Reset history when inactive
            has_history = false
            return
        end
    end

    -- 2. Update Distance (Closure)
    local tick = 0.05
    if SUPPORTS_FLOATING_WINDOWS == 1 then tick = 0.02 end
    
    local move_step = (SPEED_KTS * 0.5144) * tick
    current_dist_m = current_dist_m - move_step

    if current_dist_m < -200 then
        active = false
        return
    end

    -- 3. Calculate Target Position (Standard Head-On Logic)
    local u_x = XPLMGetDataf(DR_user_x)
    local u_y = XPLMGetDataf(DR_user_y)
    local u_z = XPLMGetDataf(DR_user_z)
    local u_psi = XPLMGetDataf(DR_user_psi)

    local sin_v = math.sin(u_psi * D2R)
    local cos_v = math.cos(u_psi * D2R)
    
    local g_x = u_x + (sin_v * current_dist_m)
    local g_z = u_z - (cos_v * current_dist_m)
    local g_y = u_y -- Co-Altitude

    -- 4. VECTOR HEADING CALCULATION
    -- Instead of guessing the heading, we measure it from the last frame.
    local final_psi = (u_psi + 180) % 360 -- Fallback (Reciprocal)

    if has_history then
        local dx = g_x - prev_g_x
        local dz = g_z - prev_g_z
        
        -- Only update heading if we actually moved (avoid divide by zero/jitter)
        if (dx * dx + dz * dz) > 0.001 then
            -- X-Plane Local Coords: +X=East, +Z=South
            -- Math.atan2(x, -z) gives us the angle from North CW
            local track_rad = math.atan2(dx, -dz)
            local track_deg = track_rad * R2D
            
            -- Normalize to 0-360
            if track_deg < 0 then track_deg = track_deg + 360 end
            final_psi = track_deg
        end
    end

    -- Update History
    prev_g_x = g_x
    prev_g_z = g_z
    has_history = true

    -- 5. Inject Data
    if DR_ai1_x then XPLMSetDataf(DR_ai1_x, g_x) end
    if DR_ai1_y then XPLMSetDataf(DR_ai1_y, g_y) end
    if DR_ai1_z then XPLMSetDataf(DR_ai1_z, g_z) end
    
    if DR_ai1_psi then XPLMSetDataf(DR_ai1_psi, final_psi) end
    if DR_ai1_the then XPLMSetDataf(DR_ai1_the, 0) end
    if DR_ai1_phi then XPLMSetDataf(DR_ai1_phi, 0) end
end

do_every_frame("loop_tcas_vector()")

-- =============================================================
-- 4. GUI
-- =============================================================

function draw_tcas_gui()
    imgui.TextUnformatted(SCRIPT_NAME)
    imgui.Separator()

    local agl = XPLMGetDataf(DR_user_agl)
    if agl < 300 then
        imgui.TextUnformatted("[!] WARNING: TOO LOW")
    end

    if active then
        imgui.TextUnformatted("!!! COLLISION ALERT !!!")
        local d_nm = current_dist_m / NM_TO_M
        local s_range = string.format("Range: %.2f NM", d_nm)
        imgui.TextUnformatted(s_range)
        
        if imgui.Button("ABORT") then
            active = false
        end
    else
        imgui.TextUnformatted("Status: READY")
        if imgui.Button("INITIATE HEAD-ON MERGE") then
            current_dist_m = START_DIST_NM * NM_TO_M
            active = true
            has_history = false -- Reset vector calc
        end
    end
end

local wnd = float_wnd_create(250, 200, 1, true)
float_wnd_set_title(wnd, "TCAS V08")
float_wnd_set_imgui_builder(wnd, "draw_tcas_gui")