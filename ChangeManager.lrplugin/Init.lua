--[[
        Init.lua (Change Manager)
--]]



-- Unstrictify _G
local mt = getmetatable( _G ) or {}
mt.__newIndex = function( t, n, v )
    rawset( t, n, v )
end
mt.__index = function( t, n )
    return rawget( t, n )
end
setmetatable( _G, mt )



--   I N I T I A L I Z E   L O A D E R
do
    local LrPathUtils = import 'LrPathUtils'
    local frameworkDir = LrPathUtils.child( _PLUGIN.path, "Framework" )
    local reqFile = frameworkDir .. "/System/Require.lua"
    local status, result1, result2 = pcall( dofile, reqFile ) -- gives good "file-not-found" error - no reason to check first (and is ok with forward slashes).
    if status then
        _G.Require = result1
        _G.Debug = result2
        assert( Require ~= nil, "no require" )
        assert( Debug ~= nil, "no debug" )
        assert( require == Require.require, "'require' is not what's expected" ) -- synonym: helps remind that its not vanilla 'require'.
    else
        error( result1 ) -- we can trust pcall+dofile to return a non-nil error message.
    end
    if _PLUGIN.path:sub( -12 ) == '.lrdevplugin' then
        Require.path( frameworkDir )
    else
        assert( _PLUGIN.path:sub( -9 ) == '.lrplugin', "Invalid plugin extension" )
        Require.path( 'Framework' ) -- relative to lrplugin dir.
    end
end



--   S E T   S T R I C T   G L O B A L   P O L I C Y
_G.Globals = require( 'System/Globals' )
_G.gbl = Globals:new{ strict = true }



_G.Object = require( 'System/Object' ) -- required.
_G.ObjectFactory = require( 'System/ObjectFactory' ) -- required.
_G.ExtendedObjectFactory = require( 'ExtendedObjectFactory' )
_G.InitFramework = require( 'System/InitFramework' )
_G.objectFactory = ExtendedObjectFactory:new()
_G.init = objectFactory:newObject( 'InitFramework' )
init:framework()



Object.register( 'Lock' )
Object.register( 'UnLock' )
Object.register( 'Utils' )
Object.register( 'CheckBatch' )
Object.register( 'CheckForChanges' )
Object.register( 'SelectToCompare' )
Object.register( 'Compare' )



_G.ExtendedManager = require( 'ExtendedManager' )


_G.LrExportSession = import 'LrExportSession' -- for faux publishing / auto-wise.
_G.PublishServices = require( 'Catalog/PublishServices' )
_G.Utils = require( 'Utils' )
_G.AutoPublish = require( 'AutoPublish' )
_G.SnapshotAndMark = require( 'SnapshotAndMark' )
_G.ExtendedBackground = require( 'ExtendedBackground' )
_G.background = ExtendedBackground:new() -- @19/Aug/2011, interval is .5 seconds. min-init-time is defaulting.
_G.snapshotAndMark = SnapshotAndMark:new()
_G.changeColl = false -- declare change check collection. - probably could have made this a static member of Utils. ###2
_G.DevelopSettings = require( 'Catalog/DevelopSettings' )
_G.devSettings = DevelopSettings:new{ cleanup = true }
_G.Xmp = require( 'Image/Xmp' )
_G.xmpo = Xmp:new()
_G.Compare = require( 'Compare' )



app:initGlobalPref( 'devMode', '1' )
app:initGlobalPref( 'markEditHistory', false )
ExtendedManager.initPrefs()
app:initDone()
background:start() -- will terminate task after (asynchronous) initialization if local background pref disabled.
