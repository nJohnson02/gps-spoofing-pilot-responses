-- Scenario 2: KTPA 3 approach
-- Reconstructed from Annex 2.2

logMsg("Chargement du script plusieurs boutons de spoofing")

-- Variables activations
local spoofing_active = { UN = false }

-- Stockage des valeurs originales
local original_values = {
    UN = get("sim/cockpit2/gauges/indicators/airspeed_kts_pilot")
}

-- Valeurs spoofees initiales
local spoof_values = { UN = 100 }

-- Facteurs de variation
local variation = { UN = 0.02 }

-- Fonction principale executee en continu
function spoof_gps()
    -- Mise a jour des valeurs uniquement si le parametre est active
    if spoofing_active.UN then
        spoof_values.UN = spoof_values.UN + variation.UN
        
        -- Cap limit check based on PDF context
        if spoof_values.UN > 130 then
            spoof_values.UN = 130
        end
        
        set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", spoof_values.UN)
        set("sim/flightmodel/position/indicated_airspeed", spoof_values.UN)
    end
end

do_every_frame("spoof_gps()")

-- Fonction activation/desactivation
function toggleSpoofing(parameter)
    spoofing_active[parameter] = not spoofing_active[parameter]
    
    if not spoofing_active[parameter] then
        -- Retablir uniquement la valeur desactivee
        if parameter == "UN" then
            set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", original_values.UN)
            set("sim/flightmodel/position/indicated_airspeed", original_values.UN)
        end
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
