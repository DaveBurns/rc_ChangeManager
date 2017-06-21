--[[
        Check.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local ExtendedBackground, dbg, dbgf = Background:newClass{ className = 'ExtendedBackground' }



--- Constructor for extending class.
--
function ExtendedBackground:newClass( t )
    return Background.newClass( self, t )
end



--- Constructor for new instance.
--
function ExtendedBackground:new( t )
    local minInitTime
    local interval
    if app:getUserName() == '_RobCole_' and app:isAdvDbgEna() then
        minInitTime = 3
        interval = .1
    else
        minInitTime = nil -- assume the default.
        interval = .5
    end
    local o = Background.new( self, { interval = interval, minInitTime = minInitTime } ) -- default min init time should be appropriate.
    -- interval should be short enough that user wont make inadvertent changes despite the lock,
    -- but long enough that its not too much load...
    o.editTime = {}
    return o
end



--- Initialize background task.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:init( call )
    local s
    s, changeColl = LrTasks.pcall( cat.assurePluginCollection, cat, "Changed Since Locked" )
    if s then
        self.initStatus = true
        if not app:getPref( 'background' ) then
            self:quit()
        end
    else
        self.initStatus = false
        app:logError( "Unable to initialize due to error: " .. str:to( changeColl ) )
        app:show{ error="Unable to initialize." }
    end
end




--- Called when nothing else going on this time, i.e. more-or-less idle...
--
--  @usage      Care must be taken to avoid infinite recursion, since its calling back to what initiated call to it.<br>
--              the target is used as a flag to indicate "mode" as well as referencing the next photo to process idly.
--
function ExtendedBackground:idleProcess( target, call )
    self:process( call, target )
end



--- Background processing method.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:process( call, target )

    if shutdown then return end

    local selPhotos
    local photo
    if not target then
        photo = catalog:getTargetPhoto() -- most-selected.
    else
        photo = target
    end
    
    if photo == nil then
        if not target then
            self:considerIdleProcessing( call )
        end
        return
    end
    
    local form = photo:getRawMetadata( 'fileFormat' )
    if form == 'VIDEO' then
        if not target then
            self:considerIdleProcessing( call )
        end
        return
    end
    
    local colls = photo:getContainedCollections()
    for i, v in ipairs( colls ) do
        if v == changeColl then
            if not target then
                self:considerIdleProcessing( call )
            end
            return
        end
    end
    
    --dbg( "getting photo info" )
    local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )
    --dbg( "got photo info, getting lock status" )
    
    local exists = fso:existsAsFile( photoPath )
    
    local locked, lockMsg = Utils.isLocked( photo )
    if locked then
    
        if targ and not exists  then
            app:logError( "Source file corresponding to locked photo is in catalog, but not on disk: ^1", photoPath )
            -- this will overflow the error log after a while - not good. ###3
            app:sleep( 1 ) -- this will slow it down.
            -- and this should bring it to user's attention:
            self:displayError( "Source file is missing." ) -- reminder: this is special bg obj meth, not app meth.
            return
        end
        
        --dbg( "got lock status, getting change status" )
        local changed, lockTimeFmt, editTimeRaw = Utils.isChanged( photo )
        --dbg( "got change status" )
        if changed then
        
            --dbg( "changed" )
            if self.editTime[photo] == editTimeRaw then
                if not target then
                    self:considerIdleProcessing( call )
                end
                return
            end
        
            local changeDet, changeDetMsg, disp = Utils.getChangeDetails( photo, nil, nil, nil, editTimeRaw ) -- time consuming...
            if changeDetMsg then -- error
                app:logError( changeDetMsg )
                return
            end
                        
            if not changeDet then
            
                -- app:logVerbose( "No significant changes to: " .. photoPath )
                -- no longer much of a hit since it only happens once, still: for optimized performance: omitted.
                --dbg( "No significant changes to", photoPath )
                self.editTime[photo] = editTimeRaw
                return
            end
            
            local editTimeFmt = LrDate.timeToUserFormat( editTimeRaw, "%Y-%m-%d %H:%M:%S" )
            
            local changeDetailsCrLf = table.concat( disp, "\r\n" )
            local changeDetailsLf = table.concat( disp, "\n" )
                
            app:logInfo( str:fmt( "Locked photo has changed: ^1\n^2", photoPathName, changeDetailsLf ) )

            local args = { title = app:getAppName() .. " auto-check is asking..." }
            local chgItems = { bind_to_object = prefs }
            chgItems[#chgItems + 1] = 
                vf:column {
                    vf:row {
                        view:getThumbnailViewItem{ viewOptions = {
                            photo = photo,
                            width = 200,
                            height = 200,
                        } },
                        vf:column {
                            vf:spacer { height = 50 },
                            vf:static_text {
                                title = str:fmt( "^1\n \nhas changed since it was locked on ^2\n \nLast changed: ^3", photoPathName, lockTimeFmt, editTimeFmt ),
                            },
                        },
                    },
                    vf:edit_field {
                        value = changeDetailsCrLf,
                        width_in_chars = app:getPref{ name='autoWidth', expectedType='number', default=60 },
                        height_in_lines = app:getPref{ name='autoHeight', expectedType='number', default=20 },
                    },
                    vf:spacer{
                        height = 5,
                    },
                }
            chgItems[#chgItems + 1] = Utils.getSnapshotAndMarkView( share( 'label_width' ) )
            chgItems[#chgItems + 1] = vf:spacer{ height=20 }
            chgItems[#chgItems + 1] = vf:separator{ fill_horizontal=1 }
            args.contents = vf:view( chgItems )
            local acc = {}
            acc[#acc + 1] = vf:spacer{ width=1, fill_horizontal=1 }
            if targ then -- real photo (not virtual copy)
                acc[#acc + 1] = 
                    --LrView.conditionalItem( WIN_ENV,
                    vf:push_button { -- Mac supports reversion, sorta...
                        title = "Revert", -- ###4 could handle reversion by keeping track of all develop settings, and metadata
                            -- but then reversion would exclude croppage &tone-curve enable switch, anything else?
                        --bind_to_object = prefs,
                        --enabled = app:getGlobalPrefBinding( 'Windows' ),
                        action = function( button )
                            LrDialogs.stopModalWithResult( button, "revert" )
                        end,
                        width = share 'revert_width',
                        tooltip = "Revert to state when photo was locked - develop settings and metadata.",
                    }
                    -- )
                acc[#acc + 1] = 
                    LrView.conditionalItem( WIN_ENV and not target, -- disallowing create-virtual-copy option in case of idle-processing.
                    vf:push_button { -- Mac would support virtual copy, but it requires reverting the original first.
                        title = "V-Copy",
                        action = function( button )
                            LrDialogs.stopModalWithResult( button, "virtualCopy" )
                        end,
                        tooltip = "Create an unlocked virtual copy which has the changes made to the master, so you can edit it instead (changed master will revert to locked state).",
                    } )
            end
            acc[#acc + 1] = 
                vf:push_button {
                    title = "Collect",
                    action = function( button )
                        LrDialogs.stopModalWithResult( button, "collect" )
                    end,
                    width = share 'revert_width',
                    tooltip = "Put in changed collection for so you can deal with it later - auto-check will no longer alert you about it.",
                }
            acc[#acc + 1] = 
                vf:push_button {
                    title = "Edit",
                    action = function( button )
                        LrDialogs.stopModalWithResult( button, "edit" )
                    end,
                    width = share 'revert_width',
                    tooltip = "Put's in changed collection and selects it for you to deal with now - auto-check will no longer alert you about it.",
                }
            acc[#acc + 1] = 
                vf:push_button {
                    title = "Unlock",
                    action = function( button )
                        LrDialogs.stopModalWithResult( button, "unlock" )
                    end,
                    tooltip = "Simply unlocks it.",
                }
            if targ then                
                acc[#acc + 1] = 
                    vf:checkbox {
                        title = str:fmt( "Develop" ),
                        bind_to_object = prefs,
                        value = app:getGlobalPrefBinding( 'devMode' ),
                        checked_value = "2",
                        unchecked_value = "1",
                        alignment = 'right',
                        tooltip = "Go to develop module after after unlocking, reverting, ...",
                    }
            end
            args.accessoryView = vf:row( acc )
            args.actionVerb = 'Accept && Relock'
            args.cancelVerb = 'Ignore'
            args.save_frame = 'PhotoBgPrompt'
            if target and target ~= catalog:getTargetPhoto() then
                local buried = cat:isBuriedInStack( target )
                if buried then
                    if app:getPref( "ignoreBuried" ) then
                        app:logInfo( "*** Changed photo is buried in stack and can't be selected. As specified in plugin manager, its being ignored: ^1", photoPath )
                    else
                        app:logWarning( "Changed photo is buried in stack and can't be selected by plugin, so it is not being handled by idle-time auto-check: ^1", photoPath )
                        app:show{ info="Changed photo is buried in stack and can't be selected by plugin - consider rectifying somehow to keep this prompt from recurring in the future: ^1\n \n(photo path has been added to log file for reference).", photoPath }
                    end
                    return 
                end                
                app:show{ info="^1 has changed since it was locked. Is it OK to auto-select it for change-processing decision? (your present selection will be restored afterward).",
                          actionPrefKey="Prompt to change photo selection", photoPath }
                selPhotos = cat:saveSelPhotos()
                local assured = cat:assurePhotoIsSelected( target ) -- by any means.
                if assured then
                    -- great: the code below, DEPENDS on target photo being most selected.
                else
                    app:logWarning( "Unable to select changed photo: ^1, so its being ignored.", photoPath )
                    return 
                end
            end
            local answer = LrDialogs.presentModalDialog( args )
            -- note: methods below will try to restore a changed selection, so selection restoral needs to either be done right,
            -- or abandoned. I think for now, just assuring target is selected, then putting it back that way after processing, will suffice.
            if answer == 'revert' then -- revert. all these functions should be wrapped, its only the non-UI errors that needs to be suppressed..., right?
                app:call( Call:new{ name="Revert Photo", async=false, guard=App.guardSilent, main=function( call )
                    --assert( WIN_ENV, call.name .. " should not be offered to Mac users - sorry." ) ###1 test mac reversion now that metadata-read is supported on Mac.
                    local s, m = gui:switchModule( 1, true ) -- library module, mandatory.
                    if s then
                        app:logVerbose( "Switched to library module" )
                    else
                        app:error( "Unable to revert ^1, error message: ^2", photoPath, m ) -- this was bombing until 13/Jun/2014 11:02 - need to release ###1.
                    end
                    local sel = catalog:getTargetPhoto()
                    local oth = cat:getSelectedPhotos()
                    -- revert depends on single photo selection.
                    -- local s, m = cat:selectOnePhoto( photo ) - commented out 13/Sep/2011 17:03
                    local s = cat:assurePhotoIsSelected( photo, photoPath ) -- added 13/Sep/2011 17:03
                    if s then
                        app:logVerbose( "Photo selected for reversion: ^1", photoPath )
                    else
                        -- error( str:fmt( "Unable to select photo for reversion, error message: ^1", m ) ) -- m includes path.
                        error( str:fmt( "Unable to select photo for reversion (see log file for details) path: ^1", photoPath ) )
                    end
                    s, m = Utils.revert( photo, photoPath, targ, photoName, true )
                    if not target then
                        local s, m = cat:setSelectedPhotos( sel, oth ) -- critical for a yield to occur after setting selected photos, which is one of the things this method does.
                        if s then
                            app:logVerbose( "Photo selected for reversion: ^1", photoPath )
                        else
                            app:logErr( "Unable to restore previous photo selections following reversion, error message: ^1", m )
                        end
                    -- else -- restoral done outside
                    end
                    if s then
                        app:logInfo( str:fmt( "Reverted: ^1", photoPath ) )
                        app:show{ info="Reverted: ^1", photoName, actionPrefKey="RevertedPrompt" }
                    else
                        error( str:fmt( "Unable to revert ^1, error message: ^2", photoPath, m ) ) -- maybe just the error message is enough (it contains paths?) ###2
                    end
                end, finale=function( call, status, message )
                    if status then
                        Utils.restoreModule()
                    else
                        app:show{ error=message }
                        app:sleepUnlessShutdown( 3 )
                    end
                end } )
                
            elseif answer == 'collect' or answer == 'edit' then -- collect and/or edit
                app:call( Call:new{ name="Collect and/or Edit", async=false, guard=App.guardSilent, main=function( call )
                    local s, m = Utils.collect( photo, photoName )
                    if s then
                        if answer == 'collect' then
                            app:show{ info="Remember ^1 is in change collection.", photoName, actionPrefKey="Reminder photo is in change collection" } 
                            app:logWarning( "Unresolved changes to locked photo: ^1 - put in change collection.", photoPathName )
                        else
                            app:show{ info="^1 is in change collection, which means auto-check will no longer warn about the changes that have been made to it - when this dialog box is closed, it will be selected in the change collection for editing so you can deal with it.",
                                subs = photoName,
                                actionPrefKey="Photo to edit is in change collection"
                            } 
                            catalog:setActiveSources{ changeColl }
                            local assured = cat:assurePhotoIsSelected( photo, photoPath ) -- by any means.
                            if assured then
                                -- great: the code below, DEPENDS on target photo being most selected.
                                selPhotos = nil -- assure selection is not restored upon finale, othrewise this feature no sirve.
                            else
                                app:logWarning( "Unable to select photo for editing: '^1' - you can find it in the change collection.", photoPath )
                                return 
                            end
                            app:log( "Unresolved changes to locked photo: ^1 - put in change collection, and selected for editing.", photoPathName )
                        end
                    else
                        error( str:fmt( "Unresolved changes to locked photo, skipped: ^1 - error putting in change collection: ^2", photoPathName, m ) )
                    end
                end, final=function( service, status, message )
                    if status then
                        Utils.restoreModule()
                    else
                        app:show{ error=message }
                        app:sleepUnlessShutdown( 3 )
                    end
                end } )
            elseif answer == 'cancel' then -- ignore
                app:show{ info="Changes to ^1 will be ignored temporarily (for a few seconds). If you are unsure whether to accept changes, then collect (or unlock - you can always re-lock after you sort things out.", photoName, actionPrefKey="IgnorePrompt" }
                app:sleepUnlessShutdown( 5 )
            elseif answer == 'unlock' then -- unlock
                app:call( Call:new{ name="Unlock Photo", async=false, guard=App.guardSilent, main=function( call )
                    -- errors are caught by outer context as well as inner service.
                    -- there seems to be no such thing as a "private/localized" error.
                    local s, m = Utils.unlockPhoto( photo, photoPath, targ, photoName ) -- does not alter photo selection internally.
                    if s then
                        app:log( "Unlocked ^1", photoPathName )
                        app:show{ info="Unlocked ^1", photoName, actionPrefKey="UnlockedPrompt" }
                    else
                        error( str:fmt( "Unable to unlock ^1 due to error: ", photoPathName, m ) )
                    end
                end, finale=function( service, status, message )
                    if status then
                        Utils.restoreModule()
                    else
                        app:show{ error=message }
                        app:sleepUnlessShutdown( 3 ) -- give user a chance to bail...
                    end
                end } )
            elseif answer == 'ok' then -- accept

                --   R E - L O C K   P H O T O
                
                app:call( Call:new{ name="Re-lock Photo", async=false, guard=App.guardSilent, main=function( call )
                    
                    local sel = catalog:getTargetPhoto()
                    local oth = cat:getSelectedPhotos()
                    
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
                    
                    if not target then
                        local s, m = catalog:setSelectedPhotos( sel, oth )
                        if not s then
                            app:logVerbose( "Unable to set selected photos - ^1", str:to( m ) )
                        end
                    end
                    if s then
                        if snapshotAndMarkParams.snapshot then
                            app:log( "Accepted changes, snapshotted, and re-locked ^1.", photoPathName )
                            app:show{ info="Accepted changes, snapshotted, and re-locked ^1.", photoName, actionPrefKey="AcceptAndSnapshotPrompt" }
                        else
                            app:log( "Accepted changes, and re-locked ^1.", photoPathName ) -- autoPublish
                            app:show{ info="Accepted changes, and re-locked ^1.", photoName, actionPrefKey="Photo accepted and relocked confirmation" }
                        end
                        if app:getGlobalPref( 'autoPublish' ) then
                            AutoPublish.autoPublish{ photo } -- raw-meta & service params are specified, but not currently used. ###2
                        else
                            -- Debug.
                        end
                    else
                        error( str:fmt( "Unable to re-lock ^1 because ^2", photoPathName, m ) )
                    end
                end, finale=function( call )
                    if call.status then
                        Utils.restoreModule()
                    else
                        app:show{ error=call.message }
                        app:sleepUnlessShutdown( 3 )
                    end
                end } )
                
            elseif answer == 'virtualCopy' then
                app:call( Call:new{ name="Create Virtual Copy", async=false, guard=App.guardSilent, main=function( call )
                    assert( WIN_ENV, call.name .. " should not be offered to Mac users - sorry." )
                    assert( not target, call.name .. " should not be offered during idle processing." )
                    local selPhotos = cat:getSelectedPhotos()
                    local mostSelPhoto = catalog:getTargetPhoto()
                    -- reminder: creation of virtual copy must precede reversion, since we want the virtual copy to have
                    -- the changes made by the user.
                    local newPhoto, msg = cat:createVirtualCopy( mostSelPhoto, true ) -- true => prompt
                    if newPhoto then
                        app:log( "Created virtual copy of ^1 (^2) named ^3", photo:getFormattedMetadata( 'fileName' ), photo:getFormattedMetadata( 'copyName' ), newPhoto:getFormattedMetadata( 'copyName' ) )
                        selPhotos[#selPhotos + 1] = newPhoto
                        local s, m = Utils.unlockPhoto( newPhoto, newPhoto:getRawMetadata( 'path' ), false, newPhoto:getFormattedMetadata( 'copyName' ) ) -- dont think last param is used, but its called for so...
                        -- *** false => don't try and make xmp read/write (since there isn't any).
                        if s then
                            app:log( "Above mentioned virtual copy has been successfully unlocked." )
                        else
                            error( str:fmt( "Unable to unlock virtual copy due to error: ^1", m ) )
                        end
                        
                        s, m = gui:switchModule( 1, true ) -- library required for reversion (metadata read menu item).
                        
                        if s then
                            app:logVerbose( "Send keys to switch to library module" )
                        else
                            error( str:fmt( "Unable to revert ^1, error message: ^2", photoPath, m ) )
                        end
                        -- local s, m = cat:selectOnePhoto( mostSelPhoto ) -- since it was just selected, it shouldn't need full on assurance, but maybe this is some smart collection and something changed...
                        if app:isVerbose() or app:isAdvDbgEna() then
                            assert( photoPath == mostSelPhoto:getRawMetadata( 'path' ), "photo path mixup" )
                        end
                        local s = cat:assurePhotoIsSelected( mostSelPhoto, photoPath ) -- since it was just selected, it shouldn't need full on assurance, but maybe this is some smart collection and something changed...
                        if s then
                            app:logVerbose( "Photo selected: ^1", photoPath )
                        else
                            -- app:error( "Unable to select photo, error message: ^1", m ) -- m includes path.
                            app:error( "Unable to select photo (see log file for details), path: ^1", photoPath ) -- m includes path.
                        end
                        s, m = Utils.revert( photo, photoPath, targ, photoName, true )
                        if s then
                            app:log( "Reverted: ^1", photoPath )
                            app:show{ info="Reverted: ^1", photoName, actionPrefKey="RevertedPrompt" }
                        else
                            app:error( "Unable to revert ^1, error message: ^2", photoPath, m )
                        end

                        s, m = cat:setSelectedPhotos( newPhoto, selPhotos, true ) -- make sure the newly created virtual copy is selected, but the other selections aren't lost.
                            -- true => assure-folder if need be.
                        if s then
                            app:logVerbose( "New virtual selected." )
                        else
                            app:logErr( "Unable to select new virtual copy, error message: ^1", m )
                        end
                        
                    elseif msg then
                        app:error( "Unable to create virtual copy due to error: ^1", msg )
                    else
                        -- virtual copy creation canceled.
                        call:cancel()
                    end
                end, finale=function(call, status, message)
                    if status then
                        if not call:isCanceled() then
                            Utils.restoreModule()
                        end
                    else
                        app:show{ error=message }
                        app:sleepUnlessShutdown( 3 )
                    end
                end } )
                -- end of "create virtual copy" clause.                
            else
                error( "Program failure - bad answer." )
            end
            
        elseif changed == nil then
            app:show{ error="Unable to ascertain change status of ^1, assuming not changed - try re-locking.", photoPathName }
            app:sleepUnlessShutdown( 3 )
        else -- changed == false
            --dbg( "not changed" )
            if not target then
                self:considerIdleProcessing( call )
            end
        end
    elseif locked == nil then
        if _PLUGIN.enabled then
            app:logVerbose( "*** This plugin just had a (hopefully temporary) problem - ^1. This often occurs when another plugin is loaded which has to update the catalog, or a photo being processed is deleted. If it occurs in any other situation, it may be a real problem.", str:to( lockMsg ) )
        else
            app:show{ warning="^1 - you need to enable this plugin.", str:to( lockMsg ) }
            app:sleepUnlessShutdown( 3 )
        end
    else -- locked == false
        -- not locked => nuthin' ta do...
        
        if targ and not exists then
            --Debug.pause( "Source file corresponding to unlocked photo is in catalog, but not on disk: ^1", photoPath ) - this happens often when photo is deleted.
        end
        
        if not target then
            self:considerIdleProcessing( call )
        end
    end
    if target and selPhotos then -- need to make sure one of the other functions does not, already 
        cat:restoreSelPhotos( selPhotos )
    end
    --dbg( "returning from process" )
    
end



return ExtendedBackground
