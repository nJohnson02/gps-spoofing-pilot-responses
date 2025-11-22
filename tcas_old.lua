-- =============================================================
-- TCAS RA GENERATOR (V30 - GOLD STANDARD)
-- 1. Based on the successful V23 Logic.
-- 2. Injects Velocity Vectors (Essential for G1000 RA).
-- 3. Disables Lights (Stealth Mode).
-- 4. No complex "Hide" hacks that cause crashes.
-- =============================================================

local SCRIPT_NAME = "TCAS V30 (Stable)"

-- =============================================================
-- 1. DATAREFS
-- =============================================================

-- USER
local DR_u_x     = XPLMFindDataRef("sim/flightmodel/position/local_x")
local DR_u_y     = XPLMFindDataRef("sim/flightmodel/position/local_y")
local DR_u_z     = XPLMFindDataRef("sim/flightmodel/position/local_z")
local DR_u_psi   = XPLMFindDataRef("sim/flightmodel/position/psi")

-- AI POSITION & PHYSICS
local DR_ai_x    = XPLMFindDataRef("sim/multiplayer/position/plane1_x")
local DR_ai_y    = XPLMFindDataRef("sim/multiplayer/position/plane1_y")
local DR_ai_z    = XPLMFindDataRef("sim/multiplayer/position/plane1_z")
local DR_ai_psi  = XPLMFindDataRef("sim/multiplayer/position/plane1_psi")
local DR_ai_the  = XPLMFindDataRef("sim/multiplayer/position/plane1_the")
local DR_ai_phi  = XPLMFindDataRef("sim/multiplayer/position/plane1_phi")

-- AI VELOCITY (The Secret Sauce for G1000)
local DR_ai_vx   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_x")
local DR_ai_vy   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_y")
local DR_ai_vz   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_z")

-- LIGHTS & OVERRIDE
local DR_ai_lights = XPLMFindDataRef("sim/multiplayer/controls/lights_request")
local DR_ovr_pos   = XPLMFindDataRef("sim/operation/override/override_plane_ai_1")

-- =============================================================
-- 2. STATE
-- =============================================================

local active = false
local SPEED_KTS = 550
local R2D = 180.0 / math.pi
local D2R = math.pi / 180.0
local NM_TO_M = 1852.0

local g_x = 0
local g_y = 0
local g_z = 0

-- Vertical Bias (To force the RA decision)
-- We climb slowly to give the TCAS a trend to calculate.
local climb_rate_mps = 5.0 -- ~1000 fpm

-- =============================================================
-- 3. LOGIC LOOP
-- =============================================================

function loop_tcas_v30()
    -- Cleanup
    if not active then
        if DR_ovr_pos and XPLMGetDatai(DR_ovr_pos) == 1 then
             XPLMSetDatai(DR_ovr_pos, 0)
        end
        return
    end

    -- 1. Force Override (God Mode)
    if DR_ovr_pos then XPLMSetDatai(DR_ovr_pos, 1) end
    
    -- 2. Kill Lights
    if DR_ai_lights then XPLMSetDatai(DR_ai_lights, 0) end

    -- 3. Get User Position
    local u_x = XPLMGetDataf(DR_u_x)
    local u_y = XPLMGetDataf(DR_u_y)
    local u_z = XPLMGetDataf(DR_u_z)

    -- 4. Kinematics (Move to User)
    local dx = u_x - g_x
    local dy = u_y - g_y
    local dz = u_z - g_z
    local dist_h = math.sqrt(dx*dx + dz*dz)

    local tick = 0.05
    if SUPPORTS_FLOATING_WINDOWS == 1 then tick = 0.02 end
    
    local h_speed_mps = SPEED_KTS * 0.5144
    local move_step = h_speed_mps * tick
    local v_step = climb_rate_mps * tick

    if dist_h > 20 then
        -- Normalize Direction
        local nx = dx / dist_h
        local nz = dz / dist_h
        
        -- Update Ghost Coordinates
        g_x = g_x + (nx * move_step)
        g_z = g_z + (nz * move_step)
        
        -- Gradual Climb Logic (Force the RA)
        -- We aim to be at User Altitude exactly at impact, so we start low and climb.
        -- Or we can just climb continuously. Let's just climb continuously.
        g_y = g_y + v_step 
        
        -- Calculate Heading (Look where we walk)
        -- atan2(x, -z) = Heading
        local trk_rad = math.atan2(nx, -nz)
        local trk_deg = trk_rad * R2D
        if trk_deg < 0 then trk_deg = trk_deg + 360 end
        
        -- Calculate Velocity Vectors (CRITICAL FOR G1000)
        -- X-Plane Physics: X = sin(psi), Z = -cos(psi)
        local v_x = math.sin(trk_rad) * h_speed_mps
        local v_z = -math.cos(trk_rad) * h_speed_mps
        local v_y = climb_rate_mps
        
        -- 5. Inject Data
        if DR_ai_x then XPLMSetDataf(DR_ai_x, g_x) end
        if DR_ai_y then XPLMSetDataf(DR_ai_y, g_y) end
        if DR_ai_z then XPLMSetDataf(DR_ai_z, g_z) end
        
        if DR_ai_psi then XPLMSetDataf(DR_ai_psi, trk_deg) end
        if DR_ai_the then XPLMSetDataf(DR_ai_the, 0) end
        if DR_ai_phi then XPLMSetDataf(DR_ai_phi, 0) end
        
        if DR_ai_vx then XPLMSetDataf(DR_ai_vx, v_x) end
        if DR_ai_vy then XPLMSetDataf(DR_ai_vy, v_y) end
        if DR_ai_vz then XPLMSetDataf(DR_ai_vz, v_z) end
    end

    if dist_h < 50 then active = false end
end

do_every_frame("loop_tcas_v30()")

-- =============================================================
-- 4. SPAWN LOGIC
-- =============================================================

function spawn_v30()
    local u_x = XPLMGetDataf(DR_u_x)
    local u_y = XPLMGetDataf(DR_u_y)
    local u_z = XPLMGetDataf(DR_u_z)
    local u_psi = XPLMGetDataf(DR_u_psi)
    
    local dist_m = 5.0 * NM_TO_M
    local sin_v = math.sin(u_psi * D2R)
    local cos_v = math.cos(u_psi * D2R)
    
    g_x = u_x + (sin_v * dist_m)
    g_z = u_z - (cos_v * dist_m)
    
    -- Spawn 500ft below user to start the climb profile
    g_y = u_y - 152.0 
    
    active = true
end

-- =============================================================
-- 5. GUI
-- =============================================================

function draw_tcas_gui()
    imgui.TextUnformatted(SCRIPT_NAME)
    imgui.Separator()

    if active then
        imgui.TextUnformatted("!!! TRACKING !!!")
        
        local u_x = XPLMGetDataf(DR_u_x)
        local u_y = XPLMGetDataf(DR_u_y)
        local u_z = XPLMGetDataf(DR_u_z)
        local dx = g_x - u_x
        local dz = g_z - u_z
        local dist_nm = math.sqrt(dx*dx + dz*dz) / NM_TO_M
        
        -- Show Alt Diff
        local dy = (g_y - u_y) * 3.28 -- Meters to Feet
        local s_range = string.format("Range: %.1f NM", dist_nm)
        local s_alt = string.format("Alt: %+.0f ft", dy)
        
        imgui.TextUnformatted(s_range)
        imgui.TextUnformatted(s_alt)
        
        if imgui.Button("ABORT") then active = false end
    else
        imgui.TextUnformatted("Status: READY")
        if imgui.Button("SPAWN THREAT") then
            spawn_v30()
        end
    end
end

local wnd = float_wnd_create(250, 250, 1, true)
float_wnd_set_title(wnd, "TCAS V30")
float_wnd_set_imgui_builder(wnd, "draw_tcas_gui")