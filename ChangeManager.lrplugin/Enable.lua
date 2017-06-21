--[[
        Enable.lua
--]]

-- _G.enabled = true - obsolete
if app then
    app:logInfo( "^1 is enabled - edits will be detected either manually or automatically depending on plugin manager configuration.", app:getPluginName() )
end
