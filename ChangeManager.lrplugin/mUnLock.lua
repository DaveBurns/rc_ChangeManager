--[[
        UnLock.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local UnLock = {} -- , dbg, dbgf = Object.register( 'UnLock' )


local dbg = Object.getDebugFunction( 'UnLock' )



--- unlock menu item handler
--
function UnLock.main()

    app:call( Service:new{ name="UnLock selected photos", async=true, guard=App.guardVocal, main=function( service ) 
    
        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to unlock photos, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photos = catalog:getTargetPhotos() -- selected or all - only nil if no photos in filmstrip.
        if not photos or #photos == 0 then
            app:show( { warning="No photos to unlock" } )
            return
        end
        
        -- local props = LrBinding.makePropertyTable( service.context )
        local args = {}
        args.title = app:getAppName() .. " Lock is asking..."
        local mainItems = { bind_to_object = prefs }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "Unlock ^1?", str:plural( #photos, "photo" ) ),
                font = '<system/bold>',
            }
        mainItems[#mainItems + 1] = 
            vf:spacer {
                height = 15,
            }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "'Unlock' function simply makes your xmp files writeable, and makes note to self that files are unlocked. After unlocking you can change your photos without restrictions." ),
                height_in_lines = 4,
                width_in_chars = 40,
                wrap = true,
            }
        mainItems[#mainItems + 1] = 
            vf:separator {
                width = 1,
                fill_horizontal = 1,
            }
        local accItems = { bind_to_object = prefs }
        accItems[#accItems + 1] = 
            vf:row {
                vf:spacer { width=1, fill_horizontal=1 },
                vf:checkbox {
                    title = str:fmt( "Develop Module" ),
                    value = app:getGlobalPrefBinding( 'devMode' ),
                    checked_value = "2",
                    unchecked_value = "1",
                    alignment = 'right',
                }
            }
        args.contents = vf:column( mainItems )
        args.accessoryView = vf:row( accItems )
        args.actionVerb = "Unlock"
        args.save_frame = 'InitialPrompts'
        local answer = LrDialogs.presentModalDialog( args )
        if answer == 'cancel' then
            service:cancel()
            return
        end

        service.selPhotos = cat:saveSelPhotos()
        
        service.nTotal = #photos
        service.nUnlocked = 0
        
        service.scope = LrProgressScope {
            title = "Unlocking " .. str:plural( #photos, 'photo' ),
            caption = 'Please wait...',
            functionContext = service.context,
        }
        
        local s, m = Utils.multiUnlock( photos, service ) -- unlock photos starting at first, keep stats and progress in service object.
        
        if not s then
            error( str:to( m ) )
        end
    
    end, finale = function( service, status, message )

        --dbg( 'unlock finale' )

        cat:restoreSelPhotos( service.selPhotos )
        background:continue()
        
        if not service:isQuit() then
            local moduleNumber = app:getGlobalPref( 'devMode' )
            local s, m = gui:switchModule( moduleNumber )
            if not s then
                --dbg( 'switch error' )
                app:logError( str:fmt( "Unable to go to module number: ^1, error message: ^2", str:to( moduleNumber ), str:to( m ) ) )
            -- else
            end
        -- else
        end
        
        if service.nUnlocked then
            app:logInfo( str:fmt( "Unlocked ^1.", str:plural( service.nUnlocked, "photo", true ) ) )
        end
    
    end } )    
    
end



return UnLock.main()
