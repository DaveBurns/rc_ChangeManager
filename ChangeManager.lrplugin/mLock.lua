--[[
        Lock.lua
        
        Handles file menu item.

        Speed lock - does not check previous status, force locks everything.        
--]]


local Lock = {}


local dbg, dbgf = Object.getDebugFunction( 'Lock' )



--- Lock selected photos.
--
--  @usage  lock menu item handler.
--
function Lock.main()

    app:call( Service:new{ name="Lock selected photos", async=true, guard=App.guardVocal, main=function( service ) 

        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to lock photos, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )
        
        local photos = catalog:getTargetPhotos() -- selected or all.
        if not photos or #photos == 0 then
            app:show( { warning="No photos to lock." } )
            return
        end
        service.nLocked = 0
        service.selPhotos = cat:saveSelPhotos()
        
        local rawMeta = cat:getBatchRawMetadata( photos, { 'uuid', 'path', 'lastEditTime', 'fileFormat', 'isVirtualCopy' } )
        
        -- local props = LrBinding.makePropertyTable( service.context ) - all prefs.
        local args = {}
        args.title = app:getAppName() .. " Lock is asking..."
        local mainItems = { bind_to_object = prefs }
        mainItems[#mainItems + 1] = 
            vf:row {
                vf:static_text {
                    title = str:fmt( "Lock ^1?", str:plural( #photos, "photo" ) ),
                    font = '<system/bold>',
                },
            }
        mainItems[#mainItems + 1] = vf:spacer{ height = 15 }
        mainItems[#mainItems + 1] = 
            vf:row {
                vf:static_text {
                    title = str:fmtx( "'Lock' function will save metadata in xmp (includes develop settings and most metadata), then make the xmp file read-only, and record locked state and lock-date in custom metadata for library filters && smart collections." ),
                    height_in_lines = 4,
                    width_in_chars = 40,
                    wrap = true,
                },
            }
        mainItems[#mainItems + 1] = vf:spacer{ height = 5 }
        mainItems[#mainItems + 1] = Utils.getSnapshotAndMarkView( share( 'label_width' ) )
        mainItems[#mainItems + 1] = vf:spacer { height = 20 }
        mainItems[#mainItems + 1] = vf:separator { fill_horizontal=1 }
        local accItems = { bind_to_object = prefs }
        accItems[#accItems + 1] = vf:spacer{ width = 1, fill_horizontal=1 }
        accItems[#accItems + 1] =
            vf:checkbox {
                title = str:fmt( "Develop Module" ),
                value = app:getGlobalPrefBinding( 'devMode' ),
                checked_value = "2",
                unchecked_value = "1",
                -- alignment = 'right',
            }
        args.actionVerb = "Lock"
        args.contents = vf:column( mainItems )
        args.accessoryView = vf:row( accItems )
        args.save_frame = 'InitialPrompts'
        
        local answer = LrDialogs.presentModalDialog( args )
        
        if answer == 'ok' then
            app:logInfo( str:fmt( "Locking ^1", str:plural( #photos, "photo" ) ) )
        elseif answer == 'cancel' then
            service:cancel()
            return
        else
            error( "Bad answer: " .. answer )
        end

        service.scope = LrProgressScope {
            title = str:fmt( 'Lock (^1 Selected)', str:plural( #photos, 'Photo' ) ),
            caption = 'Please wait...', -- Doing virtual copies...',
            functionContext = service.context,
        }
        
        local snapshotAndMarkParams = {
            styleName = app:getGlobalPref( 'styleName' ),    
            historyPrefixForSnapshot = app:getGlobalPref( 'historyPrefixForSnapshot' ),    
            historyPrefixForMark = app:getGlobalPref( 'historyPrefixForMark' ),
            name = app:getGlobalPref( 'snapshotText' ),
            snapshot = Utils.isSnapshot(),
            mark = Utils.isMark(),
            call = service,
        }
        local s, m = Utils.multiLock( photos, snapshotAndMarkParams, rawMeta )

        if s then
            -- scope:setCaption( str:fmt( "Locked ^1...", str:plural( #photos, "photo" ) ) ) - this will never be seen since its immediatly replaced with "done".
            if app:getGlobalPref( 'autoPublish' ) then
                AutoPublish.autoPublish( photos, rawMeta, service ) -- ignores service param, and initiates auto-publishing task then returns.
            else
                -- Debug.
            end
        else
            app:error( "Unable to lock photos, error message: ^1", str:to( m ) )
        end

    end, finale=function( service )

        dbgf( "Restoring selected photos after lockage, if any: ^1", str:to( service.selPhotos ) )
        cat:restoreSelPhotos( service.selPhotos )
        dbgf( "photos restored - if any" )
        background:continue()
        dbgf( "background continued - dunno if was paused..." )
        
        if not service:isQuit() then
            local moduleNumber = app:getGlobalPref( 'devMode' )
            local s, m = gui:switchModule( moduleNumber )
            if not s then
                app:logError( str:fmt( "Unable to go to module number: ^1, error message: ^2", str:to( moduleNumber ), str:to( m ) ) )
            else
                dbgf( "module switched" )
            end
        else
            dbgf( "service is quit" )
        end
        
        if service.nLocked ~= nil and service.nLocked > 0 then
            app:logInfo( str:fmt( "^1 locked.", str:plural( service.nLocked or 0, 'photo', true ) ) )
        else
            app:logv( "No photos got locked." )
        end
    
    end } )
    
end



Lock.main()
