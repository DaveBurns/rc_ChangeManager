--[[
        CheckBatch.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local CheckBatch = {}


local dbg = Object.getDebugFunction( 'CheckBatch' )



--- Check batch main function.
--
--  @usage      called as menu handler.
--
function CheckBatch.main()

    app:call( Service:new{ name="Batch check selected photos", async=true, guard=App.guardVocal, main=function( service ) 

        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to perform batch check, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photos = catalog:getTargetPhotos() -- selected or all.
        if not photos or #photos == 0 then
            app:show( { warning="No photos to batch-check." } )
            return
        end
        
        local rawMeta = cat:getBatchRawMetadata( photos, { 'uuid', 'path', 'lastEditTime', 'fileFormat', 'isVirtualCopy' } )
        
        -- local props = LrBinding.makePropertyTable( service.context )
        local args = {}
        args.title = app:getAppName() .. " Lock is asking..."
        local mainItems = { bind_to_object = prefs }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "Batch Check ^1?", str:plural( #photos, "photo" ) ),
                font = '<system/bold>',
            }
        mainItems[#mainItems + 1] = 
            vf:spacer {
                height = 10,
            }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "'Batch Check' function will scrutinize all photos targeted in the filmstrip and divide them into types: \"Changed Since Lockage\", \"Unchanged Since Lockage\", \"Not Locked\". You will then be presented with a set of options to select for each type." ),
                height_in_lines = 5,
                width_in_chars = 40,
                wrap = true,
            }
        mainItems[#mainItems + 1] = vf:separator{ fill_horizontal=1 }
        local accItems = { bind_to_object = prefs }
        accItems[#accItems + 1] =
            vf:row {
                vf:spacer { width=1, fill_horizontal = 1 },
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
        args.actionVerb = "Batch Check"
        args.save_frame = 'InitialPrompts'
        local answer = LrDialogs.presentModalDialog( args )
        if answer == 'cancel' then
            service:cancel()
            return
        end
        
        service.selPhotos = cat:saveSelPhotos()
        
        service.scope = LrProgressScope {
            title = "Batch Checking " .. str:plural( #photos, 'Photo' ),
            caption = 'Scrutinizing...',
            -- caption = 'Doing virtual copies...',
            functionContext = service.context,
        }

        local devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
        
        local notLockedPhotos = {}
        local changedPhotos = {} -- locked and significantly changed.
        local unchangedPhotos = {} -- locked but insignficantly changed.
        local videos = {}
        -- local errorPhotos
        
        for i, photo in ipairs( photos ) do
            service.scope:setPortionComplete( i, #photos )
            repeat
                local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo, rawMeta )
                if not form then
                    app:logInfo( "Ignoring video: " .. photoPath )
                    videos[#videos + 1] = photoPath
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
                            unchangedPhotos[#unchangedPhotos + 1] = photo
                            break
                        end
                        
                        changedPhotos[#changedPhotos + 1] = photo
                        
                        --   P R O C E S S   C H A N G E S
                        
                        local changeDetailsCrLf = table.concat( disp, "\r\n" )
                        local changeDetailsLf = table.concat( disp, "\n" )
                        
                        app:logInfo( str:fmt( "Photo has changed since lock-date (^3), last change: ^4, photo: ^1\n^2", photoPathName, changeDetailsLf, lockTimeFmt, editTimeFmt ) )
                        
                    elseif changed == nil then
                        app:show( { error="Apparently locked photo contains some invalid metadata, consider re-locking: ^1" }, photoPathName )
                    else -- false
                        app:logInfo( str:fmt( "Photo has not changed at all: ^1", photoPathName ) )
                        unchangedPhotos[#unchangedPhotos + 1] = photo
                    end
                elseif locked == nil then -- locked? unlocked?? ...
                    app:show( { error=lockMsg } )
                else -- not locked
                    app:logInfo( str:fmt( "Photo is not locked: ^1", photoPathName ) )
                    notLockedPhotos[#notLockedPhotos + 1] = photo
                end
                    
            until true
            if service:isQuit() or service.scope:isCanceled() or service.scope:isDone() then
                break
            end
        end
        
        
        --   P R E S E N T   B A T C H   R E S U L T S   A N D   O P T I O N S


        local total = #changedPhotos + #unchangedPhotos + #notLockedPhotos
        if total == 0 then
            app:show( { warning="Nothing to report." } ) -- this shouldn't happen, since there should be at least one photo and it should fit one of these categories.
            return
        end
        
        local props = LrBinding.makePropertyTable( service.context )
        props.changedAction = 'ignore'
        props.unchangedAction = 'ignore'
        props.notLockedAction = 'ignore'
        local args = {}
        args.title = app:getAppName() .. " - Batch Check is asking..."
        local mainItems = { bind_to_object = props }
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "Choose options then click 'Apply', or click 'Quit'"),
            }
        mainItems[#mainItems + 1] = vf:spacer { height = 20 }
            
        if #changedPhotos > 0 then
            mainItems[#mainItems + 1] =
                vf:row {
                    vf:column {
                        vf:static_text {
                            title = str:fmt( "^1:    ", str:plural( #changedPhotos, "Changed Photo", true ) ),
                            width = share( 'label_width' ),
                        },
                    },
                    vf:column {
                        vf:radio_button {
                            title = 'Accept && Relock',
                            value = bind( 'changedAction' ),
                            checked_value = 'acceptAndRelock',
                        },
                        vf:radio_button {
                            title = 'Collect',
                            value = bind( 'changedAction' ),
                            checked_value = 'collect',
                        },
                        --LrView.conditionalItem( app:getGlobalPref( 'Windows' ),  commented out 1/Aug/2012 3:06 (RDC) revert supported on Mac now, via manual metadata read function.
                            vf:radio_button {
                                title = 'Revert',
                                value = bind( 'changedAction' ),
                                checked_value = 'revert',
                            }
                        ,--),
                        vf:radio_button {
                            title = 'Unlock',
                            value = bind( 'changedAction' ),
                            checked_value = 'unlock',
                        },
                        vf:radio_button {
                            title = 'Ignore',
                            value = bind( 'changedAction' ),
                            checked_value = 'ignore',
                        },
                    },
                }
            mainItems[#mainItems + 1] =
                vf:spacer {
                    height = 20,
                }
        end
        if #unchangedPhotos > 0 then
            mainItems[#mainItems + 1] =
                vf:row {
                    vf:column {
                        vf:static_text {
                            title = str:fmt( "^1:    ", str:plural( #unchangedPhotos, "Unchanged Photo", true ) ),
                            width = share( 'label_width' ),
                        },
                    },
                    vf:column {
                        vf:radio_button {
                            title = 'Unlock',
                            value = bind( 'unchangedAction' ),
                            checked_value = 'unlock',
                        },
                        LrView.conditionalItem( #changedPhotos > 0 or #notLockedPhotos > 0, 
                            vf:radio_button {
                                title = 'Ignore',
                                value = bind( 'unchangedAction' ),
                                checked_value = 'ignore',
                            }
                        )                        
                    },
                }
            mainItems[#mainItems + 1] =
                vf:spacer {
                    height = 20,
                }
        end
        if #notLockedPhotos > 0 then
            mainItems[#mainItems + 1] =
                vf:row {
                    vf:column {
                        vf:static_text {
                            title = str:fmt( "^1:    ", str:plural( #notLockedPhotos, 'Not Locked Photo', true ) ),
                            width = share( 'label_width' ),
                        },
                    },
                    vf:column {
                        vf:radio_button {
                            title = 'Lock',
                            value = bind( 'notLockedAction' ),
                            checked_value = 'lock',
                        },
                        vf:radio_button {
                            title = 'Ignore',
                            value = bind( 'notLockedAction' ),
                            checked_value = 'ignore',
                        },
                    },
                }
            mainItems[#mainItems + 1] =
                vf:spacer {
                    height = 20,
                }
        end
        if #changedPhotos > 0 or #notLockedPhotos > 0 then -- snapshot option presented.
            mainItems[#mainItems + 1] = Utils.getSnapshotAndMarkView( share( 'label_width' ) )
        end
        mainItems[#mainItems + 1] = vf:spacer { height = 20 }
        mainItems[#mainItems + 1] = vf:separator { fill_horizontal=1 }
        args.contents = vf:column( mainItems )
        args.actionVerb = 'Apply'
        args.cancelVerb = 'Quit'
        args.save_frame = 'PhotoBatchCheckPrompt'
        service.scope:setCaption( 'Dialog box needs your attention...' )
        local answer = LrDialogs.presentModalDialog( args )
        if answer == 'cancel' then
            service:cancel()
            return
        end
        
        assert( answer == 'ok', "bad answer" )

        --   A P P L Y   O P T I O N S        

        if #changedPhotos > 0 then
            if props.changedAction == 'acceptAndRelock' then
                app:logInfo( str:fmt( "Appling 'Snapshot & Accept' to ^1.", str:plural( #changedPhotos, "changed photo", true ) ) )
                service.nLocked = 0
                local snapshotAndMarkParams = {
                    styleName = app:getGlobalPref( 'styleName' ),    
                    historyPrefixForSnapshot = app:getGlobalPref( 'historyPrefixForSnapshot' ),    
                    historyPrefixForMark = app:getGlobalPref( 'historyPrefixForMark' ),
                    name = app:getGlobalPref( 'snapshotText' ),
                    snapshot = Utils.isSnapshot(),
                    mark = Utils.isMark(),
                    call = service,
                }
                local s, m = Utils.multiLock( changedPhotos, snapshotAndMarkParams, rawMeta ) -- handles caption
                if s then
                    app:logInfo( str:fmt( "Applying 'Snapshot & Accept' to ^1 completed.", str:plural( #changedPhotos, "changed photo", true ) ) )
                    if app:getGlobalPref( 'autoPublish' ) then
                        AutoPublish.autoPublish( changedPhotos, rawMeta, service )
                    else
                        -- Debug.
                    end
                else
                    app:logError( str:fmt( "Appling 'Snapshot & Accept' to ^1 incomplete, error message: ^2.", str:plural( #changedPhotos, "changed photo", true ), str:to( m ) ) )
                end
            elseif props.changedAction == 'collect' then
                service.nCollected = 0
                app:logInfo( str:fmt( "Appling 'Collect' to ^1.", str:plural( #changedPhotos, "changed photo", true ) ) )
                local s, m = Utils.multiCollect( changedPhotos, service )
                if s then
                    app:logInfo( str:fmt( "Appling 'Collect' to ^1 completed.", str:plural( #changedPhotos, "changed photo", true ) ) )
                else
                    app:logError( str:fmt( "Appling 'Collect' to ^1 incomplete, error message: ^2.", str:plural( #changedPhotos, "changed photo", true ), str:to( m ) ) )
                end
            elseif props.changedAction == 'revert' then
                service.nReverted = 0
                app:logInfo( str:fmt( "Appling 'Revert' to ^1.", str:plural( #changedPhotos, "changed photo", true ) ) )
                if #changedPhotos == 1 then
                    local photo = changedPhotos[1]
                    local isVirt = photo:getRawMetadata( 'isVirtualCopy' )
                    if isVirt then
                        app:show( { warning="Can not revert virtual copy automatically - please see info on website for virtual copy reversion instructions." } )
                        service:cancel() -- avoid log file biz.
                        return
                    end
                end
                local s, m = Utils.multiRevert( changedPhotos, service, rawMeta )
                if s then
                    app:logInfo( str:fmt( "Appling 'Revert' to ^1 completed.", str:plural( #changedPhotos, "changed photo", true ) ) )
                else
                    app:logError( str:fmt( "Appling 'Revert' to ^1 incomplete, error message: ^2.", str:plural( #changedPhotos, "changed photo", true ), str:to( m ) ) )
                end
            elseif props.changedAction == 'unlock' then
                app:logInfo( str:fmt( "Appling 'Unlock' to ^1.", str:plural( #changedPhotos, "changed photo", true ) ) )
                service.nReverted = 0
                local s, m = Utils.multiUnlock( changedPhotos, service )
                if s then
                    app:logInfo( str:fmt( "Appling 'Unlock' to ^1 completed.", str:plural( #changedPhotos, "changed photo", true ) ) )
                else
                    app:logError( str:fmt( "Appling 'Unlock' to ^1 incomplete, error message: ^2.", str:plural( #changedPhotos, "changed photo", true ), str:to( m ) ) )
                end
            elseif props.changedAction == 'ignore' then
                app:logInfo( str:fmt( "Ignoring ^1.", str:plural( #changedPhotos, "changed photo", true ) ) )
            else
                error( "Invalid changed-action." )
            end
        end
        
        if #unchangedPhotos > 0 then
            if props.unchangedAction == 'unlock' then
                service.nUnlocked = 0
                app:logInfo( str:fmt( "Appling 'Unlock' to ^1.", str:plural( #unchangedPhotos, "unchanged photo", true ) ) )
                local s, m = Utils.multiUnlock( unchangedPhotos, service )
                if s then
                    app:logInfo( str:fmt( "Appling 'Unlock' to ^1 completed.", str:plural( #unchangedPhotos, "unchanged photo", true ) ) )
                else
                    app:logError( str:fmt( "Appling 'Unlock' to ^1 incomplete, error message: ^2.", str:plural( #unchangedPhotos, "unchanged photo", true ), str:to( m ) ) )
                end
            elseif props.unchangedAction == 'ignore' then
                app:logInfo( str:fmt( "Ignoring ^1.", str:plural( #unchangedPhotos, "unchanged photo", true ) ) )
            else
                error( "Invalid unchanged-action." )
            end
        end
        
        if #notLockedPhotos > 0 then
            local snapshotFlag
            local snapshotPrefix -- acts as boolean to multi-lock function as well...
            local snapshotText = app:getGlobalPref( 'snapshotText' )
            if str:is( snapshotText ) then
                snapshotPrefix = snapshotText .. ' '
            else
                snapshotPrefix = 'Locked ' -- really no difference between acceptance and lockage, snapshot-wise.
            end
            if props.notLockedAction == 'lock' then
                app:logInfo( str:fmt( "Appling 'Lock' to ^1.", str:plural( #notLockedPhotos, "not locked photo", true ) ) )
                service.nLocked = 0
                local snapshotAndMarkParams = {
                    styleName = app:getGlobalPref( 'styleName' ),    
                    historyPrefixForSnapshot = app:getGlobalPref( 'historyPrefixForSnapshot' ),    
                    historyPrefixForMark = app:getGlobalPref( 'historyPrefixForMark' ),
                    name = app:getGlobalPref( 'snapshotText' ),
                    snapshot = Utils.isSnapshot(),
                    mark = Utils.isMark(),
                    call = service,
                }
                local s, m = Utils.multiLock( notLockedPhotos, snapshotAndMarkParams, rawMeta ) -- handles caption
                if s then
                    app:logInfo( str:fmt( "Appling 'Lock' to ^1 completed.", str:plural( #notLockedPhotos, "not locked photo", true ) ) )
                    if app:getGlobalPref( 'autoPublish' ) then
                        AutoPublish.autoPublish( notLockedPhotos, rawMeta, service )
                    else
                        -- Debug.
                    end
                else
                    app:logError( str:fmt( "Appling 'Lock' to ^1 incomplete, error message: ^2.", str:plural( #notLockedPhotos, "not locked photo", true ), str:to( m ) ) )
                end
            elseif props.notLockedAction == 'ignore' then
                app:logInfo( str:fmt( "Ignoring ^1.", str:plural( #notLockedPhotos, "not locked photo", true ) ) )
            else
                error( "Invalid not-locked-action." )
            end
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
        if service.nUnLocked then
            app:logInfo( str:fmt( "^1 unLocked.", service.nUnLocked ) )
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



return CheckBatch.main()
