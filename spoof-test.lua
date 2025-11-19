-- spoof_injection_v3.lua
-- Corrected for FlyWithLua Floating Window System
-- Based on Annex 2 of the provided document [cite: 83, 121, 297]

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("Imgui not supported. Script stopped.")
    return
end

-- 1. Variable Initialization
local spoofing_active = {
    dist_drift = false,    -- Distance Spoof
    course_drift = false,  -- Course Spoof
    heading_drift = false  -- Heading Spoof
}

-- 2. Store Original Values (Baseline)
local current_spoof = {
    dist = 0, 
    course = 0, 
    heading = 0
}

-- 3. Spoof Parameters (Drift Rates)
-- Adjust these numbers to make the attack faster or slower
local variation = {
    dist = -20.0,      -- Meters per frame
    course = 0.1,      -- Degrees per frame
    heading = -0.1     -- Degrees per frame
}

-- 4. Main Spoofing Function
function spoof_gps()
    -- Check if ANY spoofing is active to trigger the GPS Override
    local override_needed = spoofing_active.dist_drift or spoofing_active.course_drift or 
                            spoofing_active.heading_drift
    
    -- Force the sim to accept our fake values if active [cite: 126]
    if override_needed then
        set("sim/operation/override/override_gps", 1)
    else
        set("sim/operation/override/override_gps", 0)
    end

    -- === Distance Spoofing ===
    if spoofing_active.dist_drift then
        if current_spoof.dist == 0 then 
            current_spoof.dist = get("sim/cockpit/radios/gps_dme_dist_m") 
        end
        
        current_spoof.dist = current_spoof.dist + variation.dist
        if current_spoof.dist < 0 then current_spoof.dist = 0 end 
        
        set("sim/cockpit/radios/gps_dme_dist_m", current_spoof.dist) -- [cite: 131]
    else
        current_spoof.dist = 0 
    end

    -- === Course Spoofing ===
    if spoofing_active.course_drift then
        if current_spoof.course == 0 then 
            current_spoof.course = get("sim/cockpit/radios/gps_course_degtm") 
        end
        
        current_spoof.course = (current_spoof.course + variation.course) % 360 
        set("sim/cockpit/radios/gps_course_degtm", current_spoof.course) -- [cite: 163]    
    else
        current_spoof.course = 0
    end

    -- === Heading Spoofing ===
    if spoofing_active.heading_drift then
        if current_spoof.heading == 0 then 
            current_spoof.heading = get("sim/cockpit/autopilot/heading_mag") 
        end
        
        current_spoof.heading = current_spoof.heading + variation.heading
        set("sim/cockpit/autopilot/heading_mag", current_spoof.heading) -- [cite: 182]  
    else
        current_spoof.heading = 0
    end
end

-- Register the loop to run every frame
do_every_frame("spoof_gps()")


-- 5. User Interface (Drawing Function)
-- CORRECTED: No imgui.Begin() or imgui.End() needed here
function draw_spoofing_buttons()
    
    imgui.Text("Select Data to Corrupt:")
    imgui.Separator()
    
    -- Distance Toggle
    if imgui.Button(spoofing_active.dist_drift and "DIST Drift: ON" or "DIST Drift: OFF") then
        spoofing_active.dist_drift = not spoofing_active.dist_drift
        if not spoofing_active.dist_drift then current_spoof.dist = 0 end
    end
    
    -- Course Toggle
    if imgui.Button(spoofing_active.course_drift and "CRS Drift: ON" or "CRS Drift: OFF") then
        spoofing_active.course_drift = not spoofing_active.course_drift
         if not spoofing_active.course_drift then current_spoof.course = 0 end
    end

    -- Heading Toggle
    if imgui.Button(spoofing_active.heading_drift and "HDG Drift: ON" or "HDG Drift: OFF") then
        spoofing_active.heading_drift = not spoofing_active.heading_drift
         if not spoofing_active.heading_drift then current_spoof.heading = 0 end
    end
    
end

-- 6. Window Registration
-- Based on [cite: 292, 297]
spoof_window = float_wnd_create(250, 150, 1, true)
float_wnd_set_title(spoof_window, "GPS Attack Panel")
float_wnd_set_imgui_builder(spoof_window, "draw_spoofing_buttons")
