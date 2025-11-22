-- =============================================================
-- GPS/ADS-B Spoofing Script (Fixed for FWL NG/XP12)
-- =============================================================

local ffi = require("ffi")

-- Define C function for coordinate conversion
ffi.cdef[[
    void XPLMWorldToLocal(double inLatitude, double inLongitude, double inAltitude, double *outX, double *outY, double *outZ);
]]

local outX = ffi.new("double[1]")
local outY = ffi.new("double[1]")
local outZ = ffi.new("double[1]")

-- =============================================================
-- CONFIGURATION
-- =============================================================
local spoof_lat = 47.445 
local spoof_lon = -122.305
local spoof_alt_ft = 3000

-- =============================================================
-- STABLE DATAREF MAPPING
-- =============================================================

-- 1. The Override Switch (Single Value)
-- We bind this to a Lua variable named 'OverrideTCAS'
DataRef("OverrideTCAS", "sim/operation/override/override_tcas", "writable")

-- 2. The Target Data (Specific Array Index)
-- Instead of trying to read the whole table, we bind DIRECTLY to Target #1.
-- (Index 1 is actually the 2nd slot, 0 is the 1st. This is safe.)
DataRef("GhostX", "sim/cockpit2/tcas/targets/position_x", "writable", 1)
DataRef("GhostY", "sim/cockpit2/tcas/targets/position_y", "writable", 1)
DataRef("GhostZ", "sim/cockpit2/tcas/targets/position_z", "writable", 1)
DataRef("GhostMode", "sim/cockpit2/tcas/targets/mode", "writable", 1)

-- =============================================================
-- MAIN LOOP
-- =============================================================
function update_spoofing_signal()
    -- Enable the override
    OverrideTCAS = 1

    -- Convert Lat/Lon to Local X/Y/Z
    local alt_meters = spoof_alt_ft * 0.3048
    ffi.C.XPLMWorldToLocal(spoof_lat, spoof_lon, alt_meters, outX, outY, outZ)

    -- Write to the variables we defined above
    GhostX = outX[0]
    GhostY = outY[0]
    GhostZ = outZ[0]
    
    -- Mode 3 = Active Mode C/S Transponder
    GhostMode = 3
end

do_every_frame("update_spoofing_signal()")