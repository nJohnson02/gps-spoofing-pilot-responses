-- Scenario 3: KDAB - KOMN
-- Reconstructed from Annex 2.3

logMsg("Chargement du script plusieurs boutons de spoofing avec fluctuation de la vitesse")

-- Variables activations
local spoofing_active = { UN = false, DEUX = false }

-- Stockage des valeurs originales
local original_values = {
    VI = get("sim/cockpit2/gauges/indicators/airspeed_kts_pilot")
}

-- Valeurs spoofees initiales
local spoof_values = { UN = 100, DEUX = 60 }

-- Facteurs de variation
local variation = { UN = -0.008, DEUX = -0.05 }

-- Fonction principale executee en continu
function spoof_gps()
    if spoofing_active.UN then
        spoof_values.UN = spoof_values.UN + variation.UN
        
        -- Check threshold to trigger second stage
        if spoof_values.UN < 65 then
            spoof_values.UN = 65
            
            -- Apply first stage spoofing
            set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", spoof_values.UN)
            set("sim/flightmodel/position/indicated_airspeed", spoof_values.UN)
            
            -- Trigger second stage if active
            if spoofing_active.DEUX then
                spoof_values.DEUX = spoof_values.DEUX + variation.DEUX
                
                if spoof_values.DEUX < 1 then
                   spoof_values.DEUX = 0
                end
                
                set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", spoof_values.DEUX)
                set("sim/flightmodel/position/indicated_airspeed", spoof_values.DEUX)
            end
        else
            -- Standard decay if above 65
            set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", spoof_values.UN)
            set("sim/flightmodel/position/indicated_airspeed", spoof_values.UN)
        end
    end
end

do_every_frame("spoof_gps()")

-- Fonction activation/desactivation
function toggleSpoofing(parameter)
    spoofing_active[parameter] = not spoofing_active[parameter]
    
    if not spoofing_active[parameter] then
        -- Retablir uniquement la valeur desactivee
        if parameter == "UN" or parameter == "DEUX" then
            set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", original_values.VI)
            set("sim/flightmodel/position/indicated_airspeed", original_values.VI)
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
logMsg("Script charge plusieurs boutons prets a l'emploi avec fluctuation de la vitesse")
