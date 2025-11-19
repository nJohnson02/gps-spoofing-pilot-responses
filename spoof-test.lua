-- spoof_injection.lua
-- Based on Annex 2: FlyWithLua Scripts from the provided document 

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("Imgui not supported. Script stopped.")
    return
end

-- 1. Variable Initialization
-- Flags to control which spoofing is active (UN, DEUX, etc. from PDF) [cite: 91]
local spoofing_active = {
    time_drift = false,    -- Corresponds to "UN" (Time)
    dist_drift = false,    -- Corresponds to "DEUX" (Distance) [cite: 109]
    course_drift = false,  -- Corresponds to "TROIS" (Course)
    obs_drift = false,     -- Corresponds to "QUATRE" (OBS)
    heading_drift = false  -- Corresponds to "SEPT" (Heading)
}

-- 2. Store Original Values [cite: 96]
-- We read these to have a baseline, though the spoof loop modifies them dynamically
local original_values = {
    dist = get("sim/cockpit/radios/gps_dme_dist_m"),      -- [cite: 100]
    course = get("sim/cockpit/radios/gps_course_degtm"),  -- [cite: 100]
    obs = get("sim/cockpit/radios/obs_mag"),              -- [cite: 100]
    heading = get("sim/cockpit/autopilot/heading_mag"),   -- [cite: 101]
    time = get("sim/cockpit/radios/gps_dme_time_secs")    -- [cite: 102]
}

-- 3. Spoof Parameters (Drift Rates)
-- "Variation" determines how fast the value drifts per frame 
local variation = {
    dist = -0.002,      -- Drifts distance closer/further slowly
    course = 0.001,     -- Drifts course alignment
    obs = 0.001,        -- Drifts OBS selection
    heading = -0.001,   -- Drifts Magnetic Heading
    time = -0.0001
}

-- Current spoofed values (starts at current value, then drifts)
local current_spoof = {
    dist = 0, course = 0, obs = 0, heading = 0, time = 0
}

-- 4. Main Spoofing Function [cite: 121]
function spoof_gps()
    -- Check if ANY spoofing is active to trigger the GPS Override [cite: 124]
    local override_needed = spoofing_active.dist_drift or spoofing_active.course_drift or 
                            spoofing_active.obs_drift or spoofing_active.heading_drift or 
                            spoofing_active.time_drift
    
    -- Force the sim to accept our fake values 
    if override_needed then
        set("sim/operation/override/override_gps", 1)
    else
        set("sim/operation/override/override_gps", 0)
    end

    -- === Distance Spoofing (DEUX) === [cite: 127]
    if spoofing_active.dist_drift then
        -- Initialize spoof value if starting fresh
        if current_spoof.dist == 0 then current_spoof.dist = get("sim/cockpit/radios/gps_dme_dist_m") end
        
        -- Apply Drift [cite: 128]
        current_spoof.dist = current_spoof.dist + variation.dist
        if current_spoof.dist < 0 then current_spoof.dist = 0 end -- Prevent negative distance [cite: 128]
        
        -- Inject Value 
        set("sim/cockpit/radios/gps_dme_dist_m", current_spoof.dist)
    else
        current_spoof.dist = 0 -- Reset
    end

    -- === Course Spoofing (TROIS) === [cite: 144]
    if spoofing_active.course_drift then
        if current_spoof.course == 0 then current_spoof.course = get("sim/cockpit/radios/gps_course_degtm") end
        
        current_spoof.course = (current_spoof.course + variation.course) % 360 -- Keep within 0-360 [cite: 147]
        set("sim/cockpit/radios/gps_course_degtm", current_spoof.course)      -- [cite: 163]
    else
        current_spoof.course = 0
    end

    -- === Heading Spoofing (SEPT) === [cite: 176]
    if spoofing_active.heading_drift then
        if current_spoof.heading == 0 then current_spoof.heading = get("sim/cockpit/autopilot/heading_mag") end
        
        current_spoof.heading = current_spoof.heading + variation.heading -- [cite: 179]
        set("sim/cockpit/autopilot/heading_mag", current_spoof.heading)   -- 
    else
        current_spoof.heading = 0
    end
end

-- Run this function every single frame [cite: 230]
do_every_frame("spoof_gps()")


-- 5. User Interface (Window to Toggle Spoofs) [cite: 275]
function draw_spoofing_buttons()
    local wnd = float_wnd_create(250, 200, 1, true)
    float_wnd_set_title(wnd, "GPS Attack Panel")
    
    if imgui.Begin("GPS Attack Panel", nil, imgui.constant.WindowFlags.AlwaysAutoResize) then
        imgui.Text("Select Data to Corrupt:")
        
        -- Buttons toggle the boolean flags [cite: 278, 387]
        if imgui.Button(spoofing_active.dist_drift and "Distance: ACTIVE" or "Distance: Normal") then
            spoofing_active.dist_drift = not spoofing_active.dist_drift
        end
        
        if imgui.Button(spoofing_active.course_drift and "Course: ACTIVE" or "Course: Normal") then
            spoofing_active.course_drift = not spoofing_active.course_drift
        end

        if imgui.Button(spoofing_active.heading_drift and "Heading: ACTIVE" or "Heading: Normal") then
            spoofing_active.heading_drift = not spoofing_active.heading_drift
        end
    end
    imgui.End()
end

-- Create the window [cite: 292]
draw_spoofing_buttons()
