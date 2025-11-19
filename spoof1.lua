-- Scenario 1: KAPF - KFMY
-- Reconstructed from Annex 2.1

logMsg("Chargement du script plusieurs boutons de spoofing")

-- Variables activations
local spoofing_active = {
    DEUX = false, 
    TROIS = false, 
    QUATRE = false, 
    SEPT = false, 
    UN = false, 
    SIX = false, 
    CINQ = false 
}

-- Stockage des valeurs originales
local original_values = {
    DEUX = get("sim/cockpit/radios/gps_dme_dist_m"),
    TROIS = get("sim/cockpit/radios/gps_course_degtm"),
    QUATRE = get("sim/cockpit/radios/obs_mag"),
    SEPT = get("sim/cockpit/autopilot/heading_mag"),
    UN = get("sim/cockpit/radios/gps_dme_time_secs"),
    SIX = get("sim/cockpit/radios/gps_dme_dist_m"),
    CINQ = get("sim/cockpit/radios/gps_dme_time_secs")
}

-- Valeurs spoofees initiales
local spoof_values = {
    DEUX = 2, 
    TROIS = 348, 
    QUATRE = 348, 
    SEPT = 90.0,
    UN = 1, 
    SIX = 23.5, 
    CINQ = 6 * 60
}

-- Facteurs de variation
local variation = {
    DEUX = -0.0002, 
    TROIS = 0.001, 
    QUATRE = 0.001, 
    SEPT = -0.001, 
    UN = -0.0001, 
    SIX = -0.0008, 
    CINQ = -0.01
}

-- Fonction principale executee en continu
function spoof_gps()
    -- Verifier si au moins un parametre GPS est active
    local gps_override = spoofing_active.DEUX or spoofing_active.TROIS or 
                         spoofing_active.QUATRE or spoofing_active.SEPT or 
                         spoofing_active.UN or spoofing_active.SIX or spoofing_active.CINQ
    
    set("sim/operation/override/override_gps", gps_override and 1 or 0)

    -- Mise a jour des valeurs uniquement si le parametre est active
    if spoofing_active.DEUX then
        spoof_values.DEUX = spoof_values.DEUX + variation.DEUX
        if spoof_values.DEUX < 0 then
            spoof_values.DEUX = 0
        end
        set("sim/cockpit/radios/gps_dme_dist_m", spoof_values.DEUX)
    end

    if spoofing_active.TROIS then
        spoof_values.TROIS = (spoof_values.TROIS + variation.TROIS) % 360
        if spoof_values.TROIS > 357 then
            spoof_values.TROIS = 357
        end
        set("sim/cockpit/radios/gps_course_degtm", spoof_values.TROIS)
    end

    if spoofing_active.QUATRE then
        spoof_values.QUATRE = spoof_values.QUATRE + variation.QUATRE
        if spoof_values.QUATRE > 357 then
            spoof_values.QUATRE = 357
        end
        set("sim/cockpit/radios/obs_mag", spoof_values.QUATRE)
    end

    if spoofing_active.SEPT then
        spoof_values.SEPT = spoof_values.SEPT + variation.SEPT
        set("sim/cockpit/autopilot/heading_mag", spoof_values.SEPT)
    end

    if spoofing_active.UN then
        spoof_values.UN = spoof_values.UN + variation.UN
        if spoof_values.UN < 0 then
            spoof_values.UN = 0
        end
        set("sim/cockpit/radios/gps_dme_time_secs", spoof_values.UN)
    end

    if spoofing_active.SIX then
        spoof_values.SIX = spoof_values.SIX + variation.SIX
        if spoof_values.SIX < 0 then
            spoof_values.SIX = 0
        end
        set("sim/cockpit/radios/gps_dme_dist_m", spoof_values.SIX)
    end

    if spoofing_active.CINQ then
        spoof_values.CINQ = spoof_values.CINQ + variation.CINQ
        if spoof_values.CINQ < 0 then
            spoof_values.CINQ = 0
        end
        set("sim/cockpit/radios/gps_dme_time_secs", spoof_values.CINQ)
    end
end

do_every_frame("spoof_gps()")

-- Fonction activation/desactivation
function toggleSpoofing(parameter)
    spoofing_active[parameter] = not spoofing_active[parameter]
    
    if not spoofing_active[parameter] then
        -- Retablir uniquement la valeur desactivee
        if parameter == "DEUX" then set("sim/cockpit/radios/gps_dme_dist_m", original_values.DEUX) end
        if parameter == "TROIS" then set("sim/cockpit/radios/gps_course_degtm", original_values.TROIS) end
        if parameter == "QUATRE" then set("sim/cockpit/radios/obs_mag", original_values.QUATRE) end
        if parameter == "SEPT" then set("sim/cockpit/autopilot/heading_mag", original_values.SEPT) end
        if parameter == "UN" then set("sim/cockpit/radios/gps_dme_time_secs", original_values.UN) end
        if parameter == "SIX" then set("sim/cockpit/radios/gps_dme_dist_m", original_values.SIX) end
        if parameter == "CINQ" then set("sim/cockpit/radios/gps_dme_time_secs", original_values.CINQ) end
    end
    
    logMsg("Spoofing " .. parameter .. (spoofing_active[parameter] and " ACTIVE" or " DESACTIVE"))
end

-- Interface utilisateur
function draw_spoofing_buttons()
    for param, active in pairs(spoofing_active) do
        if imgui.Button(active and "Desactiver " .. param or "Activer " .. param) then
            toggleSpoofing(param)
        end
    end
end

-- Creation fenetre avec les boutons
spoofing_window = float_wnd_create(300, 200, 1, true)
float_wnd_set_imgui_builder(spoofing_window, "draw_spoofing_buttons")
logMsg("Script charge plusieurs boutons prets a l'emploi")
