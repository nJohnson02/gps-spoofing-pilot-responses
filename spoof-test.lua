-- spoof_injection_v4.lua
-- Uses Direct Draw method to ensure buttons appear
[cite_start]-- Logic based on Annex 2 of the provided document [cite: 121-160]

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("Imgui not supported. Script stopped.")
    return
end

-- 1. Variable Initialization (Global to ensure access)
spoofing_active = {
    dist_drift = false,    -- Distance Spoof
    course_drift = false,  -- Course Spoof
    heading_drift = false  -- Heading Spoof
}

current_spoof = {
    dist = 0, 
    course = 0, 
    heading = 0
}

[cite_start]-- 2. Spoof Parameters (Drift Rates) [cite: 114-116]
local variation = {
    dist = -20.0,      -- Meters per frame
    course = 0.1,      -- Degrees per frame
    heading = -0.1     -- Degrees per frame
}

-- 3. Main Spoofing Logic (Runs every physics frame)
function spoof_gps_logic()
    -- Check if ANY spoofing is active to trigger the GPS Override
    local override_needed = spoofing_active.dist_drift or spoofing_active.course_drift or 
                            spoofing_active.heading_drift
    
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
        set("sim/cockpit/radios/gps_dme_dist_m", current_spoof.dist)
    else
        current_spoof.dist = 0 
    end

    -- === Course Spoofing ===
    if spoofing_active.course_drift then
        if current_spoof.course == 0 then 
            current_spoof.course = get("sim/cockpit/radios/gps_course_degtm") 
        end
        current_spoof.course = (current_spoof.course + variation.course) % 360 
        set("sim/cockpit/radios/gps_course_degtm", current_spoof.course)
    else
        current_spoof.course = 0
    end

    -- === Heading Spoofing ===
    if spoofing_active.heading_drift then
        if current_spoof.heading == 0 then 
            current_spoof.heading = get("sim/cockpit/autopilot/heading_mag") 
        end
        current_spoof.heading = current_spoof.heading + variation.heading
        set("sim/cockpit/autopilot/heading_mag", current_spoof.heading)
    else
        current_spoof.heading = 0
    end
end

-- 4. UI Drawing Logic (Runs every graphics frame)
-- This manually creates the window, bypassing the "helper" that was causing the blank square.
function draw_spoof_panel()
    -- Create the window. The "nil" argument means it stays open until script stops.
    -- We use "AlwaysAutoResize" so the window shrinks/grows to fit the buttons.
    if imgui.Begin("GPS Attack Panel", nil, imgui.constant.WindowFlags.AlwaysAutoResize) then
        
        imgui.Text("Select Data to Corrupt:")
        imgui.Separator()
        
        -- Distance Toggle
        if imgui.Button(spoofing_active.dist_drift and "DIST Drift: ON" or "DIST Drift: OFF") then
            spoofing_active.dist_drift = not spoofing_active.dist_drift
            -- Reset logic to prevent jumps when turning back on
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
    -- Close the window context
    imgui.End()
end

-- 5. Registration
do_every_frame("spoof_gps_logic()") -- Updates physics
do_every_draw("draw_spoof_panel()") -- Updates graphics
