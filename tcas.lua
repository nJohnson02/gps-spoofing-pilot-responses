-- =============================================================
-- TCAS RA GENERATOR (V23 - FULL KINEMATIC LOOP)
-- 1. Updates Position (Move to User).
-- 2. Updates Heading (Face User).
-- 3. Updates VELOCITY VECTORS (Match Heading).
-- =============================================================

local SCRIPT_NAME = "TCAS V23 (Kinematic)"

-- =============================================================
-- 1. DATAREFS
-- =============================================================

-- SYSTEM
local DR_sim_period = XPLMFindDataRef("sim/operation/misc/frame_rate_period")

-- USER
local DR_u_x     = XPLMFindDataRef("sim/flightmodel/position/local_x")
local DR_u_y     = XPLMFindDataRef("sim/flightmodel/position/local_y")
local DR_u_z     = XPLMFindDataRef("sim/flightmodel/position/local_z")
local DR_u_psi   = XPLMFindDataRef("sim/flightmodel/position/psi")

-- AI POSITION
local DR_ai_x    = XPLMFindDataRef("sim/multiplayer/position/plane1_x")
local DR_ai_y    = XPLMFindDataRef("sim/multiplayer/position/plane1_y")
local DR_ai_z    = XPLMFindDataRef("sim/multiplayer/position/plane1_z")
local DR_ai_psi  = XPLMFindDataRef("sim/multiplayer/position/plane1_psi")
local DR_ai_the  = XPLMFindDataRef("sim/multiplayer/position/plane1_the")
local DR_ai_phi  = XPLMFindDataRef("sim/multiplayer/position/plane1_phi")

-- AI PHYSICS
local DR_ai_vx   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_x")
local DR_ai_vy   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_y")
local DR_ai_vz   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_z")

-- OVERRIDE
local DR_ovr_pos = XPLMFindDataRef("sim/operation/override/override_plane_ai_1")

-- =============================================================
-- 2. STATE
-- =============================================================

local active = false
local SPEED_KTS = 550
local R2D = 180.0 / math.pi
local D2R = math.pi / 180.0
local NM_TO_M = 1852.0
local ALT_OFFSET_M = 60.96 -- 200 ft offset to avoid self-filtering

-- Internal Tracking
local g_x = 0
local g_y = 0
local g_z = 0

-- =============================================================
-- 3. LOGIC LOOP
-- =============================================================

function loop_tcas_v23()
    -- 1. Manage Override
    if not active then
        if DR_ovr_pos and XPLMGetDatai(DR_ovr_pos) == 1 then
             XPLMSetDatai(DR_ovr_pos, 0)
        end
        return
    end

    -- Force Physics Override (God Mode)
    if DR_ovr_pos then XPLMSetDatai(DR_ovr_pos, 1) end

    -- 2. Get User Pos
    local u_x = XPLMGetDataf(DR_u_x)
    local u_y = XPLMGetDataf(DR_u_y)
    local u_z = XPLMGetDataf(DR_u_z)

    -- 3. Calculate Vector To User
    local dx = u_x - g_x
    local dy = u_y - g_y
    local dz = u_z - g_z
    local dist = math.sqrt(dx*dx + dz*dz)

    -- 4. Move Ghost (Position Update)
    -- Use actual simulation time (dt) for smooth interpolation
    local dt = XPLMGetDataf(DR_sim_period)
    local speed_mps = SPEED_KTS * 0.5144
    local move_step = speed_mps * dt

    if dist > 20 then
        -- Normalize Direction
        local nx = dx / dist
        local nz = dz / dist
        
        -- Update Position
        g_x = g_x + (nx * move_step)
        g_z = g_z + (nz * move_step)
        
        -- Vertical Lock with Offset (Ghost is below User)
        g_y = u_y - ALT_OFFSET_M
        
        -- 5. Calculate Heading (Look where we are going)
        -- atan2(x, -z) = Heading in X-Plane coordinates
        local trk_rad = math.atan2(nx, -nz)
        local trk_deg = trk_rad * R2D
        if trk_deg < 0 then trk_deg = trk_deg + 360 end
        
        -- 6. CALCULATE VELOCITY VECTORS
        -- The G1000 needs the velocity vector to match the position update
        local v_x = math.sin(trk_rad) * speed_mps
        local v_z = -math.cos(trk_rad) * speed_mps
        
        -- 7. INJECT EVERYTHING
        if DR_ai_x then XPLMSetDataf(DR_ai_x, g_x) end
        if DR_ai_y then XPLMSetDataf(DR_ai_y, g_y) end
        if DR_ai_z then XPLMSetDataf(DR_ai_z, g_z) end
        
        if DR_ai_psi then XPLMSetDataf(DR_ai_psi, trk_deg) end
        if DR_ai_the then XPLMSetDataf(DR_ai_the, 0) end
        if DR_ai_phi then XPLMSetDataf(DR_ai_phi, 0) end
        
        -- Inject the Physics Vectors
        if DR_ai_vx then XPLMSetDataf(DR_ai_vx, v_x) end
        if DR_ai_vz then XPLMSetDataf(DR_ai_vz, v_z) end
        if DR_ai_vy then XPLMSetDataf(DR_ai_vy, 0) end
    end

    -- Auto-Abort on Impact/Near Miss
    if dist < 50 then active = false end
end

do_every_frame("loop_tcas_v23()")

-- =============================================================
-- 4. SPAWN LOGIC
-- =============================================================

function spawn_kinematic()
    local u_x = XPLMGetDataf(DR_u_x)
    local u_y = XPLMGetDataf(DR_u_y)
    local u_z = XPLMGetDataf(DR_u_z)
    local u_psi = XPLMGetDataf(DR_u_psi)
    
    -- Spawn 5 NM Ahead
    local dist_m = 5.0 * NM_TO_M
    local sin_v = math.sin(u_psi * D2R)
    local cos_v = math.cos(u_psi * D2R)
    
    g_x = u_x + (sin_v * dist_m)
    g_z = u_z - (cos_v * dist_m)
    
    -- Initialize altitude with the offset so it doesn't jump
    g_y = u_y - ALT_OFFSET_M
    
    active = true
end

-- =============================================================
-- 5. GUI
-- =============================================================

function draw_tcas_gui()
    imgui.TextUnformatted(SCRIPT_NAME)
    imgui.Separator()

    if active then
        imgui.TextUnformatted("!!! KINEMATIC LOOP ACTIVE !!!")
        
        local u_x = XPLMGetDataf(DR_u_x)
        local u_z = XPLMGetDataf(DR_u_z)
        local dx = g_x - u_x
        local dz = g_z - u_z
        local dist_nm = math.sqrt(dx*dx + dz*dz) / NM_TO_M
        
        imgui.TextUnformatted(string.format("Range: %.1f NM", dist_nm))
        imgui.TextUnformatted(string.format("Speed: %d KTS", SPEED_KTS))
        
        if imgui.Button("ABORT") then active = false end
    else
        imgui.TextUnformatted("Status: READY")
        if imgui.Button("SPAWN THREAT (5NM)") then
            spawn_kinematic()
        end
    end
end

local wnd = float_wnd_create(250, 150, 1, true)
float_wnd_set_title(wnd, "TCAS V23")
float_wnd_set_imgui_builder(wnd, "draw_tcas_gui")