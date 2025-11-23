-- =============================================================
-- TCAS RA GENERATOR (V32 - FINAL)
-- 1. PHYSICS: Kinematic Loop (Standard).
-- 2. AUDIO: Native X-Plane sound.
-- 3. BEHAVIOR: Always disappears on Abort/Range Limit.
-- =============================================================

local SCRIPT_NAME = "ADS-B Spoof V32"

-- =============================================================
-- 1. CONFIGURATION & STATE
-- =============================================================

-- Default Settings
local CONFIG = {
    speed_kts       = 550.0,
    spawn_dist_nm   = 5.0,
    disappear_nm    = 0.5   -- Auto-vanish when this close
}

-- Real-time State
local STATE = {
    active          = false,
    audio_triggered = false,
    current_dist_nm = 0.0,
    status_text     = "READY"
}

-- Internal Position Tracking
local g_x, g_y, g_z = 0, 0, 0

-- Audio Resource
local TRAFFIC_SOUND = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/traffic.wav")

-- =============================================================
-- 2. DATAREFS
-- =============================================================

local DR_sim_period = XPLMFindDataRef("sim/operation/misc/frame_rate_period")

-- USER
local DR_u_x     = XPLMFindDataRef("sim/flightmodel/position/local_x")
local DR_u_y     = XPLMFindDataRef("sim/flightmodel/position/local_y")
local DR_u_z     = XPLMFindDataRef("sim/flightmodel/position/local_z")
local DR_u_psi   = XPLMFindDataRef("sim/flightmodel/position/psi")

-- AI
local DR_ai_x    = XPLMFindDataRef("sim/multiplayer/position/plane1_x")
local DR_ai_y    = XPLMFindDataRef("sim/multiplayer/position/plane1_y")
local DR_ai_z    = XPLMFindDataRef("sim/multiplayer/position/plane1_z")
local DR_ai_psi  = XPLMFindDataRef("sim/multiplayer/position/plane1_psi")
local DR_ai_the  = XPLMFindDataRef("sim/multiplayer/position/plane1_the")
local DR_ai_phi  = XPLMFindDataRef("sim/multiplayer/position/plane1_phi")
local DR_ai_vx   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_x")
local DR_ai_vy   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_y")
local DR_ai_vz   = XPLMFindDataRef("sim/multiplayer/position/plane1_v_z")

local DR_ovr_pos = XPLMFindDataRef("sim/operation/override/override_plane_ai_1")

-- Constants
local R2D = 180.0 / math.pi
local D2R = math.pi / 180.0
local NM_TO_M = 1852.0

-- =============================================================
-- 3. HELPER FUNCTIONS
-- =============================================================

-- Teleport plane 100 NM behind user to "Disappear" it
function banish_ghost()
    local u_x = XPLMGetDataf(DR_u_x)
    local u_z = XPLMGetDataf(DR_u_z)
    local u_psi = XPLMGetDataf(DR_u_psi)
    
    -- Calculate position 100 NM behind (PSI + 180)
    local dist_m = 100.0 * NM_TO_M
    local rear_rad = (u_psi + 180) * D2R
    
    local dx = math.sin(rear_rad) * dist_m
    local dz = -math.cos(rear_rad) * dist_m
    
    -- Update internal and sim state immediately
    g_x = u_x + dx
    g_z = u_z + dz
    
    if DR_ai_x then XPLMSetDataf(DR_ai_x, g_x) end
    if DR_ai_z then XPLMSetDataf(DR_ai_z, g_z) end
end

-- =============================================================
-- 4. LOGIC LOOP
-- =============================================================

function loop_tcas_final()
    -- Manage Override
    if not STATE.active then
        if DR_ovr_pos and XPLMGetDatai(DR_ovr_pos) == 1 then
             XPLMSetDatai(DR_ovr_pos, 0)
        end
        return
    end

    if DR_ovr_pos then XPLMSetDatai(DR_ovr_pos, 1) end

    -- Get Data
    local u_x = XPLMGetDataf(DR_u_x)
    local u_y = XPLMGetDataf(DR_u_y)
    local u_z = XPLMGetDataf(DR_u_z)
    local dt = XPLMGetDataf(DR_sim_period)

    -- Vector Calculation
    local dx = u_x - g_x
    local dy = u_y - g_y
    local dz = u_z - g_z
    local dist = math.sqrt(dx*dx + dz*dz)
    
    -- Update UI State
    STATE.current_dist_nm = dist / NM_TO_M

    -- CHECK DISAPPEAR DISTANCE (AUTO-ABORT)
    local limit_m = CONFIG.disappear_nm * NM_TO_M
    if dist < limit_m then
        banish_ghost()
        STATE.active = false
        STATE.status_text = "TARGET DISAPPEARED (Range Limit)"
        return
    end

    -- Move Ghost
    local speed_mps = CONFIG.speed_kts * 0.5144
    local move_step = speed_mps * dt

    -- Normalize & Update
    local nx = dx / dist
    local nz = dz / dist
    
    g_x = g_x + (nx * move_step)
    g_z = g_z + (nz * move_step)
    g_y = u_y -- Same Altitude
    
    -- Heading & Physics
    local trk_rad = math.atan2(nx, -nz)
    local trk_deg = trk_rad * R2D
    if trk_deg < 0 then trk_deg = trk_deg + 360 end
    
    local v_x = math.sin(trk_rad) * speed_mps
    local v_z = -math.cos(trk_rad) * speed_mps
    
    -- INJECT
    if DR_ai_x then XPLMSetDataf(DR_ai_x, g_x) end
    if DR_ai_y then XPLMSetDataf(DR_ai_y, g_y) end
    if DR_ai_z then XPLMSetDataf(DR_ai_z, g_z) end
    if DR_ai_psi then XPLMSetDataf(DR_ai_psi, trk_deg) end
    if DR_ai_the then XPLMSetDataf(DR_ai_the, 0) end
    if DR_ai_phi then XPLMSetDataf(DR_ai_phi, 0) end
    if DR_ai_vx then XPLMSetDataf(DR_ai_vx, v_x) end
    if DR_ai_vz then XPLMSetDataf(DR_ai_vz, v_z) end
    if DR_ai_vy then XPLMSetDataf(DR_ai_vy, 0) end

    -- AUDIO TRIGGER (2.0 NM)
    if not STATE.audio_triggered and dist < (2.0 * NM_TO_M) then
        play_sound(TRAFFIC_SOUND)
        STATE.audio_triggered = true
    end
end

do_every_frame("loop_tcas_final()")

-- =============================================================
-- 5. SPAWN & ABORT
-- =============================================================

function toggle_attack()
    if STATE.active then
        -- STOPPING
        STATE.active = false
        STATE.status_text = "ABORTED"
        banish_ghost() -- Always vanish on stop
    else
        -- STARTING
        local u_x = XPLMGetDataf(DR_u_x)
        local u_y = XPLMGetDataf(DR_u_y)
        local u_z = XPLMGetDataf(DR_u_z)
        local u_psi = XPLMGetDataf(DR_u_psi)
        
        local dist_m = CONFIG.spawn_dist_nm * NM_TO_M
        local sin_v = math.sin(u_psi * D2R)
        local cos_v = math.cos(u_psi * D2R)
        
        g_x = u_x + (sin_v * dist_m)
        g_z = u_z - (cos_v * dist_m)
        g_y = u_y
        
        STATE.active = true
        STATE.audio_triggered = false
        STATE.status_text = "TRACKING..."
    end
end

-- =============================================================
-- 6. GUI
-- =============================================================

function draw_final_gui()
    imgui.TextUnformatted(SCRIPT_NAME)
    imgui.Separator()

    -- STATUS READOUT
    local rng_txt = string.format("Range: %.2f NM", STATE.current_dist_nm)
    imgui.TextUnformatted(STATE.status_text)
    imgui.TextUnformatted(rng_txt)
    
    if STATE.audio_triggered then
        imgui.TextUnformatted(">> AUDIO ALERT FIRED <<")
    else
        imgui.TextUnformatted("")
    end

    imgui.Separator()
    imgui.TextUnformatted("ATTACK SETTINGS")

    -- INPUT BOXES
    
    local chg_s, new_s = imgui.InputFloat("Speed (KTS)", CONFIG.speed_kts, 10.0, 50.0, "%.0f")
    if chg_s then CONFIG.speed_kts = new_s end

    local chg_d, new_d = imgui.InputFloat("Spawn Dist (NM)", CONFIG.spawn_dist_nm, 0.5, 1.0, "%.1f")
    if chg_d then CONFIG.spawn_dist_nm = new_d end

    local chg_v, new_v = imgui.InputFloat("Disappear At (NM)", CONFIG.disappear_nm, 0.1, 0.5, "%.1f")
    if chg_v then CONFIG.disappear_nm = new_v end

    imgui.Dummy(10,10)
    imgui.Separator()
    
    -- MAIN ACTION BUTTON
    if imgui.Button(STATE.active and "ADS-B Spoofing: ACTIVE" or "ADS-B Spoofing: inactive") then
        toggle_attack()
    end
end

local wnd = float_wnd_create(350, 400, 1, true)
float_wnd_set_title(wnd, "ADS-B Spoof V32")
float_wnd_set_imgui_builder(wnd, "draw_final_gui")