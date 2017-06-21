--[[
        CompareToSelected.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local CompareToSelected = {}


local dbg = Object.getDebugFunction( 'CompareToSelected' )



--- Get change details.
--
--  @return  change detected, or nil if trouble
--  @return  error message - remaining variables undefined if error...
--  @return  disp array
--
function CompareToSelected.getChangeDetails( photo, full )

    local devSetExcl, rawMetaExcl, fmtMetaExcl
    if full then
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.devSetExcl, Utils.rawMetaExcl, Utils.fmtMetaExcl
    else
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
    end
    
    local disp = {}
    local ignoreUnids = app:getPref( "ignoreUnidentifiedChanges" )
    local changed = not ignoreUnids
    
    local devSettingsPrep = Utils.prepareSettings( CompareToSelected.devSettings, devSetExcl )
    local devSettingsPrev = Utils.prepareSettings( Utils.devSettings, devSetExcl )
    if devSettingsPrev == nil then
        disp[#disp + 1] = 'No dev settings to check.'
    else
        disp[#disp + 1] = "Develop Settings Changes:"
        local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( devSettingsPrev, devSettingsPrep, disp, 100, devSetExcl, Utils.devSetDeps, true )
        if changesListed == 0 then
            disp[#disp] = "No develop setting changes."
        else
            changed = true
            if changesUnlisted > 0 then
                disp[#disp + 1] = "... " .. changesUnlisted .. " more develop setting changes unlisted."
            end
            disp[#disp + 1] = ""
        end
    end
    if type( rawMetaExcl ) == 'table' or rawMetaExcl ~= '*' then
        local rawMetadataPrep = Utils.prepareSettings( CompareToSelected.rawMetadata, rawMetaExcl )
        local rawMetadataPrev = Utils.prepareSettings( Utils.rawMetadata, rawMetaExcl )
        if rawMetadataPrev == nil then
            disp[#disp + 1] = 'No raw metadata to check.'
        else
            disp[#disp + 1] = "Raw Metadata Changes:"
            local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( rawMetadataPrev, rawMetadataPrep, disp, 50, rawMetaExcl )
            if changesListed == 0 then
                disp[#disp] = "No raw metadata changes."
            else
                changed = true
                if changesUnlisted > 0 then
                    disp[#disp + 1] = "... " .. changesUnlisted .. " more raw metadata changes unlisted."
                end
                disp[#disp + 1] = ""
            end
        end
    end
    local fmtMetadataPrep = Utils.prepareSettings( CompareToSelected.fmtMetadata, fmtMetaExcl )
    local fmtMetadataPrev = Utils.prepareSettings( Utils.fmtMetadata, fmtMetaExcl )
    if fmtMetadataPrev == nil then
        disp[#disp + 1] = 'No formatted metadata to check.'
    else
        if type( rawMetaExcl ) == 'table' or rawMetaExcl ~= '*' then
            disp[#disp + 1] = "Formatted Metadata Changes:"
        else
            disp[#disp + 1] = "Metadata Changes:"
        end
        local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( fmtMetadataPrev, fmtMetadataPrep, disp, 50, fmtMetaExcl )
        if changesListed == 0 then
            if type( rawMetaExcl ) == 'table' or rawMetaExcl ~= '*' then
                disp[#disp] = "No formatted metadata changes."
            else
                disp[#disp] = "No metadata changes."
            end
        else
            changed = true
            if changesUnlisted > 0 then
                disp[#disp + 1] = "... " .. changesUnlisted .. " more formatted metadata changes unlisted."
            end
            disp[#disp + 1] = ""
        end
    end
    return changed, nil, disp
end        




--- CompareToSelected menu item handler
--
function CompareToSelected.main()

    app:call( Service:new{ name="Photo Comparison", async=true, guard=App.guardVocal, main=function( call ) 
    
        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to compare, error message: ^1" }, m )
            call:cancel()
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photo = catalog:getTargetPhoto()
        if not photo then
            app:show( { warning="Select photo to compare." } )
            call:cancel()
            return
        end

        if Utils.devSettings == nil or Utils.rawMetadata == nil or Utils.fmtMetadata == nil then
            app:show( { warning="No photo selected for comparison." } )
            call:cancel()
            return
        end

        local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )
        if not form then
            app:show( { warning="Select photo (not video) to compare." } )
            call:cancel()
            return
        end

        -- Here we go...
        if Utils.photoPath ~= photoPath then -- two different photos.
            app:log( "Comparing ^1 to ^2", Utils.photoPath, photoPath )
        else
            app:log( "Comparing two states of ^1", photoPath )
        end
        
        CompareToSelected.devSettings = photo:getDevelopSettings()        
        CompareToSelected.rawMetadata = photo:getRawMetadata()
        CompareToSelected.fmtMetadata = photo:getFormattedMetadata()
        
        local changedDetails, changeDetailsMsg, disp = CompareToSelected.getChangeDetails( photo, true ) -- true => full comparison.
        
        if changeDetailsMsg then -- error
            app:show( { error=changeDetailsMsg } )
            return
        end
        
        if not changedDetails then
            app:log( "No significant difference." )
            app:show( "No significant difference." )
            call:cancel()
            return
        end
        
        --   P R O C E S S   C H A N G E S
        
        local changeDetailsCrLf = table.concat( disp, "\r\n" )
        local changeDetailsLf = table.concat( disp, "\n" )
        
        app:log( "Change Details:\n^1", changeDetailsLf )
        app:log()
        
        local props = LrBinding.makePropertyTable( call.context )
        local args = {}
        args.title = app:getAppName() .. " - Presenting differences..."
        local mainItems = {}
        local name1
        local name2
        if app:getPref( 'justFilename' ) then
            name1 = LrPathUtils.leafName( Utils.photoPath )
            name2 = LrPathUtils.leafName( photoPath )
        else
            name1 = Utils.photoPath
            name2 = photoPath
        end
        if Utils.photoPath ~= photoPath then
            mainItems[#mainItems + 1] = 
                vf:static_text {
                    title = str:fmt( "First Photo: ^1\nSecond Photo: ^2\n \nDifferences:", name1, name2 ),
                }
        else
            mainItems[#mainItems + 1] = 
                vf:static_text {
                    -- title = str:fmt( "Photo: ^1\nNote: first item between bars is first selected state, second item is the comparison state.\n \nDifferences:", name2 ), -- too long when just filename
                    -- anyway, almost more confusing than just letting user figure it out(?)
                    title = str:fmt( "Photo: ^1\n \nDifferences:", name2 ),
                }
        end
        local w = app:getPref( "compareWidth" ) or 70
        local h = app:getPref( "compareHeight" ) or 30
        mainItems[#mainItems + 1] = 
            vf:edit_field {
                value = changeDetailsCrLf,
                width_in_chars = w,
                height_in_lines = h,
            }
        args.contents = vf:column( mainItems )
        -- args.actionVerb = 'OK'
        -- args.cancelVerb = 'Cancel'
        -- args.resizable = true
        args.save_frame = 'PhotoComparisonPrompt'
        
        call.selPhotos = cat:saveSelPhotos()
        local s, m
        if Utils.photoPath ~= photoPath then -- two different photos
            s, m = cat:setSelectedPhotos( Utils.photo, { Utils.photo, photo } )
        else
            s, m = cat:assurePhotoIsSelected( photo )
        end
        if s then
            app:logVerbose( "Photos selected for comparison." )
        else
            app:logErr( "Unable to select photos for comparison, error message: ^1", m )
        end
        local answer = LrDialogs.presentModalDialog( args ) -- do comparison regardless of selection status.
        
    end, finale = function( call, status, message )

        cat:restoreSelPhotos( call.selPhotos )
        background:continue()
    
    end } )    
    
end



CompareToSelected.main()
return true
