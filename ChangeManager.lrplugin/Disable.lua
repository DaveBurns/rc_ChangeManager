--[[
        Disable.lua
--]]

-- _G.enabled = false
if app then
    app:logWarning( "^1 is disabled - you will not have edit lock protection until it is enabled.", app:getPluginName() )
end
