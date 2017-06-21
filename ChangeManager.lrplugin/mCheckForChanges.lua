--[[
        CheckForChanges.lua
        
        Menu item handler.
--]]


local CheckForChanges = {} -- , dbg, dbgf = Object.register( 'CheckForChanges' )


local dbg, dbgf = Object.getDebugFunction( 'CheckForChanges' )



--- check for changes menu handler.
--
function CheckForChanges.main()

    app:call( Service:new{ name="Check for changed photos", async=true, guard=App.guardVocal, main=function( service ) 

        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to check for changes, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photos = catalog:getTargetPhotos() -- selected or all.
        if not photos or #photos == 0 then
            app:logWarning( "No photos to check." )
            return
        end
        
        local rawMeta = cat:getBatchRawMetadata( photos, { 'uuid', 'path', 'lastEditTime', 'fileFormat', 'isVirtualCopy' } )
        
        -- local props = LrBinding.makePropertyTable( service.context )
        local args = {}
        args.title = app:getAppName() .. " Lock is asking..."
        local mainItems = { bind_to_object = prefs }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "Check ^1 for changes?", str:plural( #photos, "photo" ) ),
                font = '<system/bold>',
            }
        mainItems[#mainItems + 1] = vf:spacer { height = 10 }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "'Check For Changes' function will scrutinize the photos targeted in the filmstrip, looking for those that have changed since lockage. If found, you will be presented with a detailed list of changes, and a set of options to choose from." ),
                height_in_lines = 5,
                width_in_chars = 40,
                wrap = true,
            }
        --mainItems[#mainItems + 1] = vf:spacer { height = 5 }
        mainItems[#mainItems + 1] = vf:separator { fill_horizontal=1 }
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
                },
            }
        args.contents = vf:column( mainItems )
        args.accessoryView = vf:row( accItems )
        args.actionVerb = "Check For Changes"
        args.save_frame = 'InitialPrompts'
        local answer = LrDialogs.presentModalDialog( args )
        if answer == 'cancel' then
            service:cancel()
            return
        end
        
        service.selPhotos = cat:saveSelPhotos()
        
        service.scope = LrProgressScope {
            title = "Checking " .. str:plural( #photos, 'Photo' ),
            caption = 'Please wait...',
            functionContext = service.context,
        }

        local devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
        
        local rawMeta = cat:getBatchRawMetadata( photos, { 'uuid', 'path', 'lastEditTime', 'isVirtualCopy', 'fileFormat' } )
        
        for i, photo in ipairs( photos ) do
            repeat
                local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo, rawMeta )
                if not form then
                    app:logInfo( "Ignoring video: " .. photoPath )
                    break
                end
                local locked, lockMsg = Utils.isLocked( photo )
                if locked then
                    local changed, lockTimeFmt, editTimeRaw = Utils.isChanged( photo )
                    if changed then
                        
                        local editTimeFmt = LrDate.timeToUserFormat( editTimeRaw, "%Y-%m-%d %H:%M:%S" )
                        
                        local changedDetails, changeDetailsMsg, disp = Utils.getChangeDetails( photo, devSetExcl, rawMetaExcl, fmtMetaExcl, editTimeRaw )
                        
                        if changeDetailsMsg then -- error
                            app:logError( changeDetailsMsg )
                            break
                        end
                        
                        if not changedDetails then
                            app:logInfo( "No significant changes to: " .. photoPathName )
                            if #photos == 1 then
                                app:show{ info="Photo has not changed significantly since locked: ^1", photoName }
                            end
                            break
                        end
                        
                        --   P R O C E S S   C H A N G E S
                        
                        local changeDetailsCrLf = table.concat( disp, "\r\n" )
                        local changeDetailsLf = table.concat( disp, "\n" )
                        
                        -- local s, m = cat:selectOnePhoto( photo ) -- display photo associated with decision user is to make (single photo so only its metadata is displayed too, regardless of pref for it).
                        local s = cat:assurePhotoIsSelected( photo, photoPath )
                        if s then
                            app:logVerbose( "Photo selected: ^1", photoPath )
                        else
                            -- app:logErr( "Unable to select photo for change processing, error message: ^1", m ) -- m includes path.
                            app:logErr( "Unable to select photo for change processing, path: ^1", photoPath )
                            break
                        end

                        app:logInfo( str:fmt( "Photo has changed since lock-date (^3), last change: ^4, photo: ^1\n^2", photoPathName, changeDetailsLf, lockTimeFmt, editTimeFmt ) )
                        
                        local args = {}
                        args.title = app:getAppName() .. " - Interactive Check is asking..."
                        local chgItems = { bind_to_object = prefs }
                        chgItems[#chgItems + 1] = 
                            vf:column {
                                vf:static_text {
                                    title = str:fmt( "Photo: ^1\n \nChanges since lock-date ^2, last changed: ^3", photoPathName, lockTimeFmt, editTimeFmt ),
                                },
                                vf:edit_field {
                                    value = changeDetailsCrLf,
                                    width_in_chars = 70,
                                    height_in_lines = 20,
                                },
                                vf:spacer{
                                    height = 3,
                                },
                            }
                        chgItems[#chgItems + 1] = Utils.getSnapshotAndMarkView( share( 'label_width' ) )
                        chgItems[#chgItems + 1] = vf:spacer{ height=20 }
                        chgItems[#chgItems + 1] = vf:separator{ fill_horizontal=1 }
                        args.contents = vf:view( chgItems )
                        local props = LrBinding.makePropertyTable( service.context )
                        props.rememberAnswer = false
                        args.accessoryView = vf:row {
                            vf:push_button {
                                title = "Quit",
                                action = function( button )
                                    LrDialogs.stopModalWithResult( button, "quit" )
                                end
                            },
                            vf:spacer{
                                width = 1,
                                fill_horizontal = 1,
                            },
                            vf:checkbox {
                                title = "Do same for remainder of changed photos:",
                                bind_to_object = props,
                                value = bind( 'rememberAnswer' ),
                            },
                            LrView.conditionalItem( not photo:getRawMetadata( 'isVirtualCopy' ), --  or MAC_ENV, ###1 test this on mac
                                vf:push_button {
                                    title = "Revert",
                                    --bind_to_object = prefs,
                                    --enabled = app:getGlobalPrefBinding( 'Windows' ),
                                    action = function( button )
                                        LrDialogs.stopModalWithResult( button, "revert" )
                                    end
                                }
                            ),
                            vf:push_button {
                                title = "Unlock",
                                action = function( button )
                                    LrDialogs.stopModalWithResult( button, "unlock" )
                                end
                            },
                        }
                        args.actionVerb = 'Accept && Relock' -- return 'ok'
                        -- args.actionBinding - is broken or I dont know how to use it.
                        args.cancelVerb = 'Collect'
                        args.save_frame = 'PhotoCheckForChangesPrompt'
                        local answer = LrDialogs.presentModalDialog( args )
                        if answer == 'quit' then
                            app:logWarning( str:fmt( "Unresolved changes to photo since locked (check canceled): ^1 - not put in change collection.", photoPathName ) )
                            service:cancel()
                            break
                        end
                        if props.rememberAnswer then
                            local photosRemaining = Utils.getChangedPhotos( photos, i, rawMeta ) -- includes current one without checking it.
                            if photosRemaining then
                                if answer == 'revert' then
                                    if #photosRemaining == 1 then
                                        local photo = photosRemaining[1]
                                        local isVirt = photo:getRawMetadata( 'isVirtualCopy' )
                                        if isVirt then
                                            app:show( { warning="Can not revert virtual copy automatically - please see info on website for virtual copy reversion instructions." } )
                                            return
                                        end
                                    end
                                    local s, m = Utils.multiRevert( photosRemaining, service, rawMeta )
                                    if s then
                                        app:logInfo( "Reverted multiple photos successfully." ) -- stats displays count.
                                    else
                                        app:logError( "Unable to revert, error message: " .. m )
                                    end
                                elseif answer == 'ok' then -- accept && relock
                                    local snapshotAndMarkParams = {
                                        styleName = app:getGlobalPref( 'styleName' ),    
                                        historyPrefixForSnapshot = app:getGlobalPref( 'historyPrefixForSnapshot' ),    
                                        historyPrefixForMark = app:getGlobalPref( 'historyPrefixForMark' ),
                                        name = app:getGlobalPref( 'snapshotText' ),
                                        snapshot = Utils.isSnapshot(),
                                        mark = Utils.isMark(),
                                        call = service,
                                    }
                                    local s, m = Utils.multiLock( photosRemaining, snapshotAndMarkParams, rawMeta )
                                    if s then
                                        app:logInfo( "Accepted multiple changes" )
                                        if app:getGlobalPref( 'autoPublish' ) then
                                            AutoPublish.autoPublish( photosRemaining, rawMeta, service )
                                        else
                                            -- Debug.
                                        end
                                    else
                                        app:logError( "Unable to accept changes to photosRemaining, error message: " .. m )
                                    end
                                elseif answer == 'unlock' then
                                    local s, m = Utils.multiUnlock( photosRemaining, service )
                                    if s then
                                        app:logInfo( str:fmt( "Unlocked multiple photosRemaining" ) )
                                    else
                                        app:logError( str:fmt( "Unable to unlock photosRemaining, error message: ^1", m ) )
                                    end
                                elseif answer == 'cancel' then -- 'Collect'
                                    local s, m = Utils.multiCollect( photosRemaining, service )
                                    if s then
                                        app:logWarning( str:fmt( "Remainder of photosRemaining added to change collection - dont forget..." ) )
                                    else
                                        app:logError( str:fmt( "Unable to add remainder of photosRemaining to change collection, error message: ^1", m ) )
                                    end
                                else -- quit
                                    app:logWarning( str:fmt( "Unresolved changes to photo since locked (check canceled): ^1 - not put in change collection.", photoPathName ) )
                                    service:cancel()
                                end
                            else
                                error( "bad answer" )                            
                            end
                            service.scope:done()
                            break
                        end
                        -- fall-through => just do one photo
                        if answer == 'revert' then -- revert real photo
                            local s, m = Utils.revert( photo, photoPath, targ, photoName, false ) -- false => not already in lib module for sure.
                            -- ###2 could move the check functions to lib menu, then would be sure already in lib module.
                            if s then
                                app:logInfo( "Reverted: " .. photoPath ) -- vc not supported
                            else
                                app:logError( "Unable to revert " .. photoPath .. ", error message: " .. m )
                            end
                        elseif answer == 'ok' then -- accept
                            local snapshotAndMarkParams = {
                                styleName = app:getGlobalPref( 'styleName' ),    
                                historyPrefixForSnapshot = app:getGlobalPref( 'historyPrefixForSnapshot' ),    
                                historyPrefixForMark = app:getGlobalPref( 'historyPrefixForMark' ),
                                name = app:getGlobalPref( 'snapshotText' ),
                                snapshot = Utils.isSnapshot(),
                                mark = Utils.isMark(),
                                call = service,
                            }
                            local s, m = Utils.lockPhoto( photo, photoPath, targ, photoName, snapshotAndMarkParams )
                            if s then
                                app:logInfo( "Accepted photo changes to: " .. photoPathName )
                            else
                                app:logError( "Unable to accept changes to photo: " .. photoPathName .. ", error message: " .. m )
                            end
                        elseif answer == 'unlock' then
                            local s, m = Utils.unlockPhoto( photo, photoPath, targ, photoName )
                            if s then
                                app:logInfo( str:fmt( "Unlocked photo: ^1", photoPathName ) )
                            else
                                app:logError( str:fmt( "Unable to unlock photo: ^1, error message: ^2", photoPathName, m ) )
                            end
                        elseif answer == 'cancel' then -- 'Collect'
                            local s, m = Utils.collect( photo, photoName )
                            if s then
                                app:logWarning( str:fmt( "Unresolved changes to photo since locked (skipped): ^1 - see change collection.", photoPathName  ) )
                            else
                                app:logError( str:fmt( "Unresolved changes to photo since locked (skipped): ^1 - error putting in change collection: ^2", photoPathName, m ) )
                            end
                        else -- quit
                            app:logWarning( str:fmt( "Unresolved changes to photo since locked (check canceled): ^1 - not put in change collection.", photoPathName ) )
                            service:cancel()
                        end
                    elseif changed == nil then
                        app:show( { error="Apparently locked photo contains some invalid metadata, consider re-locking: ^1" }, photoPathName )
                    else -- false
                        app:logInfo( str:fmt( "Photo has not changed at all: ^1", photoPathName ) )
                        if #photos == 1 then
                            app:show{ info="Photo has not changed since locked: ^1", photoName }
                        end
                    end
                elseif locked == nil then -- locked? unlocked?? ...
                    app:show( { error=str:to( lockMsg ) } )
                else -- not locked
                    app:logInfo( str:fmt( "Photo is not locked: ^1", photoPathName ) )
                    if #photos == 1 then
                        app:show{ info="Photo is not locked: ^1", photoName }
                    end
                end
                    
            until true
            if service:isQuit() or service.scope:isCanceled() or service.scope:isDone() then
                break
            end
            service.scope:setPortionComplete( i, #photos )
        end

    end, finale=function( service, status, message )
    
        cat:restoreSelPhotos( service.selPhotos )
        background:continue()
        
        if not service:isQuit() then
            local moduleNumber = app:getGlobalPref( 'devMode' )
            local s, m = gui:switchModule( moduleNumber )
            if not s then
                app:logError( str:fmt( "Unable to go to module number: ^1, error message: ^2", str:to( moduleNumber ), str:to( m ) ) )
            end
        end
        
        if service.nLocked then
            app:logInfo( str:fmt( "^1 locked.", service.nLocked ) )
        end
        if service.nUnlocked then
            app:logInfo( str:fmt( "^1 unlocked.", service.nUnlocked ) )
        end
        if service.nReverted then
            app:logInfo( str:fmt( "^1 reverted.", service.nReverted ) )
        end
        if service.nCollected then
            app:logInfo( str:fmt( "^1 added to change collection.", service.nCollected ) )
        end
        if service.nIgnored then
            app:logInfo( str:fmt( "^1 ignored.", service.nIgnored ) )
        end
        
    end } )    
    
end



return CheckForChanges.main()
