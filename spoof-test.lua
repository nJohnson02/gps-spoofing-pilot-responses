-- spoof_injection_v2.lua
-- Fixed version that properly registers the ImGui window
-- Based on Annex 2 of the provided document [cite: 82]

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("Imgui not supported. Script stopped.")
    return
end

-- 1. Variable Initialization
-- Flags to control which spoofing is active
local spoofing_active = {
    dist_drift = false,    -- Corresponds to "DEUX" (Distance)
    course_drift = false,  -- Corresponds to "TROIS" (Course)
    heading_drift = false  -- Corresponds to "SEPT" (Heading)
}

-- 2. Store Original Values (Baseline)
-- We read these to have a starting point
local current_spoof = {
    dist = 0, 
    course = 0, 
    heading = 0
}

-- 3. Spoof Parameters (Drift Rates) [cite: 115, 116]
-- These values determine how fast the instrument drifts per frame
local variation = {
    dist = -20.0,      -- Meters per frame (drifts distance closer/further)
    course = 0.1,      -- Degrees per frame (drifts course alignment)
    heading = -0.1     -- Degrees per frame (drifts Magnetic Heading)
}

-- 4. Main Spoofing Function
function spoof_gps()
    -- Check if ANY spoofing is active to trigger the GPS Override [cite: 124]
    local override_needed = spoofing_active.dist_drift or spoofing_active.course_drift or 
                            spoofing_active.heading_drift
    
    -- Force the sim to accept our fake values if active [cite: 126]
    if override_needed then
        set("sim/operation/override/override_gps", 1)
    else
        set("sim/operation/override/override_gps", 0)
    end

    -- === Distance Spoofing (DEUX) [cite: 127, 128] ===
    if spoofing_active.dist_drift then
        -- Initialize spoof value if we haven't yet
        if current_spoof.dist == 0 then 
            current_spoof.dist = get("sim/cockpit/radios/gps_dme_dist_m") 
        end
        
        -- Apply Drift
        current_spoof.dist = current_spoof.dist + variation.dist
        if current_spoof.dist < 0 then current_spoof.dist = 0 end 
        
        -- Inject Value
        set("sim/cockpit/radios/gps_dme_dist_m", current_spoof.dist)
    else
        current_spoof.dist = 0 -- Reset
    end

    -- === Course Spoofing (TROIS) [cite: 144, 147] ===
    if spoofing_active.course_drift then
        if current_spoof.course == 0 then 
            current_spoof.course = get("sim/cockpit/radios/gps_course_degtm") 
        end
        
        current_spoof.course = (current_spoof.course + variation.course) % 360 
        set("sim/cockpit/radios/gps_course_degtm", current_spoof.course)      
    else
        current_spoof.course = 0
    end

    -- === Heading Spoofing (SEPT) [cite: 176, 180] ===
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

-- Register the loop to run every frame [cite: 230]
do_every_frame("spoof_gps()")


-- 5. User Interface (Drawing Function) [cite: 275]
function draw_spoofing_buttons()
    -- Only start drawing if the window is visible
    -- Note: Begin() returns true if the window is open/expanded
    -- We use AlwaysAutoResize so it fits the buttons neatly
    if imgui.Begin("GPS Attack Panel", nil, imgui.constant.WindowFlags.AlwaysAutoResize) then
        imgui.Text("Select Data to Corrupt:")
        imgui.Separator()
        
        -- Buttons toggle the boolean flags [cite: 387]
        if imgui.Button(spoofing_active.dist_drift and "DIST Drift: ON" or "DIST Drift: OFF") then
            spoofing_active.dist_drift = not spoofing_active.dist_drift
            -- Reset value when toggling off to prevent "jumping" next time
            if not spoofing_active.dist_drift then current_spoof.dist = 0 end
        end
        
        if imgui.Button(spoofing_active.course_drift and "CRS Drift: ON" or "CRS Drift: OFF") then
            spoofing_active.course_drift = not spoofing_active.course_drift
             if not spoofing_active.course_drift then current_spoof.course = 0 end
        end

        if imgui.Button(spoofing_active.heading_drift and "HDG Drift: ON" or "HDG Drift: OFF") then
            spoofing_active.heading_drift = not spoofing_active.heading_drift
             if not spoofing_active.heading_drift then current_spoof.heading = 0 end
        end
    end
    imgui.End()
end

-- 6. Window Registration (CRITICAL FIX) [cite: 292, 297]
-- We create the window handle and tell FWL to use our function to draw it.
-- We do NOT call draw_spoofing_buttons() directly.
spoof_window = float_wnd_create(250, 150, 1, true)
float_wnd_set_title(spoof_window, "GPS Attack Panel")
float_wnd_set_imgui_builder(spoof_window, "draw_spoofing_buttons")
