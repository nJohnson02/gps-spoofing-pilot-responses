-- spoof_manual_trigger.lua
-- Replicates the manual button trigger from the PDF Annex 2

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("Imgui not supported.")
    return
end

-- 1. State Variables (The "Triggers")
local spoof_active = {
    dist = false,
    course = false,
    heading = false
}

-- 2. Storage for the drifting values
local spoof_val = { dist=0, course=0, heading=0 }

-- 3. The Drift Rates (From PDF)
local rates = { dist = -20.0, course = 0.1, heading = -0.1 }

-- 4. Main Logic Loop
function update_spoofing()
    -- Check if we need to override the GPS
    if spoof_active.dist or spoof_active.course or spoof_active.heading then
        set("sim/operation/override/override_gps", 1)
    else
        set("sim/operation/override/override_gps", 0)
    end

    -- Distance Logic
    if spoof_active.dist then
        if spoof_val.dist == 0 then spoof_val.dist = get("sim/cockpit/radios/gps_dme_dist_m") end
        spoof_val.dist = spoof_val.dist + rates.dist
        if spoof_val.dist < 0 then spoof_val.dist = 0 end
        set("sim/cockpit/radios/gps_dme_dist_m", spoof_val.dist)
    else
        spoof_val.dist = 0 
    end

    -- Heading Logic
    if spoof_active.heading then
        if spoof_val.heading == 0 then spoof_val.heading = get("sim/cockpit/autopilot/heading_mag") end
        spoof_val.heading = spoof_val.heading + rates.heading
        set("sim/cockpit/autopilot/heading_mag", spoof_val.heading)
    else
        spoof_val.heading = 0
    end
end

-- 5. The Trigger UI (Simplified)
function draw_triggers()
    -- Create a fixed window at 50, 50 (Top Left) to ensure it never disappears
    imgui.SetNextWindowPos(50, 50, imgui.constant.Cond.FirstUseEver)
    imgui.SetNextWindowSize(200, 150, imgui.constant.Cond.FirstUseEver)
    
    if imgui.Begin("Spoof Triggers", nil, imgui.constant.WindowFlags.NoResize) then
        
        -- Button 1: Distance
        if imgui.Button(spoof_active.dist and "DIST: ACTIVE" or "Activate Distance") then
            spoof_active.dist = not spoof_active.dist
            if not spoof_active.dist then spoof_val.dist = 0 end -- Reset on deactivate
        end

        -- Button 2: Heading
        if imgui.Button(spoof_active.heading and "HDG: ACTIVE" or "Activate Heading") then
            spoof_active.heading = not spoof_active.heading
            if not spoof_active.heading then spoof_val.heading = 0 end -- Reset on deactivate
        end

    end
    imgui.End()
end

-- Register functions
do_every_frame("update_spoofing()")
do_every_draw("draw_triggers()")
