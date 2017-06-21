--[[
        CompareCatalog.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local CompareCatalog = {}


local dbg = Object.getDebugFunction( 'CompareCatalog' )



--- Get change details.
--
--  @return  change detected, or nil if trouble
--  @return  error message - remaining variables undefined if error...
--  @return  disp array
--
function CompareCatalog.getChangeDetails( photo, full )

    local devSetExcl, rawMetaExcl, fmtMetaExcl
    if full == nil then
        devSetExcl, rawMetaExcl, fmtMetaExcl = {}, {}, {}
    elseif full then
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.devSetExcl, Utils.rawMetaExcl, Utils.fmtMetaExcl
    else
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
    end
    
    local disp = {}
    local ignoreUnids = app:getPref( "ignoreUnidentifiedChanges" )
    local changed = not ignoreUnids
    
    local devSettingsPrep = Utils.prepareSettings( CompareCatalog.devSettings, devSetExcl )
    local devSettingsPrev = Utils.prepareSettings( Utils.devSettings, devSetExcl )
    if devSettingsPrev == nil then
        disp[#disp + 1] = 'No dev settings to check.'
    else
        disp[#disp + 1] = "Develop Settings Changes:"
        local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( devSettingsPrev, devSettingsPrep, disp, 100, devSetExcl, nil, true ) -- not passing deps, so all nitty gritty dev diffs will show up.
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
        local rawMetadataPrep = Utils.prepareSettings( CompareCatalog.rawMetadata, rawMetaExcl )
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
    local fmtMetadataPrep = Utils.prepareSettings( CompareCatalog.fmtMetadata, fmtMetaExcl )
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




--- CompareCatalog menu item handler
--
function CompareCatalog.ToDisk()

    local xmpFile
    local xmpFileToRestore
    local xmpFileFromCatalog
    local selPhotos
    local restoreXmp
    local restoreCat
    
    app:call( Service:new{ name="Compare Catalog To Disk", async=true, guard=App.guardVocal, main=function( call ) 

        local s, m = background:pause()
        if not s then
            app:show{ error="Unable to compare, error message: ^1", m }
            call:cancel()
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photo = catalog:getTargetPhoto()
        if not photo then
            app:show( { warning="Select photo first." } )
            call:cancel()
            return
        end

        local photoPath = photo:getRawMetadata( 'path' )
        local isVirt = photo:getRawMetadata( 'isVirtualCopy' )
        local photoFile = LrPathUtils.leafName( photoPath )
        local fmt = photo:getRawMetadata( 'fileFormat' )
        
        if isVirt then
            app:show{ warning="Select non-virtual copy instead." }
            call:cancel()
            return
        end
        
        if fmt == 'VIDEO' then
            app:show{ warning="Doesn't work on videos." }
            call:cancel()
            return
        end
        
        local locked, lockMsg = Utils.isLocked( photo )
        if locked then
            app:show{ warning="^1 is locked.\n\nComparison of catalog to disk only works with unlocked photos.", photoFile }
            call:cancel()
            return
        end            

        if MAC_ENV then
            local m = {}
            m[#m + 1] = "This feature is a little rough on the Mac platform because saving of metadata programmatically is sometimes problematic, and reading of metadata programmatically is not supported at all."
            app:show{ info = table.concat( m, "\n" ),
                actionPrefKey = "Compare catalog to disk is rough on Mac",
            }
        end            
        
        local answer = app:show{ confirm="Compare settings and metadata in catalog to those on disk (xmp), for most selected photo?\nFilename: ^1",
            subs = photoFile,
            buttons = { dia:btn( "Yes - No exclusions", 'noExcl' ), dia:btn( "Yes - Minimal exclusions", 'other' ), dia:btn( "Yes - Normal exclusions", 'ok' ) },
            actionPrefKey = "Pre-compare prompt - catalog against disk",
        }
        
        local full
        
        if answer == 'ok' then
            full = false
        elseif answer == 'other' then
            full = true
        elseif answer == 'noExcl' then
            full = nil
        elseif answer == 'cancel' then
            call:cancel()
            return
        else
            app:error( "bad answer" )
        end
        
        -- here we go...
        app:log( "Comparing catalog to disk, photo: ^1", photoPath )
        
        selPhotos = cat:saveSelPhotos()
        
        if fmt == 'RAW' then -- raw not dng. Beware, if you don't want to save metadata for cooked nefs (which are considered "raw")..., then check before calling.
            xmpFile = LrPathUtils.replaceExtension( photoPath, "xmp" )
        else
            xmpFile = photoPath
        end
        xmpFileToRestore = LrPathUtils.addExtension( xmpFile, "_to-restore_" )
        xmpFileFromCatalog = LrPathUtils.addExtension( xmpFile, "_from-catalog_" )

        -- Save catalog setting as baseline.
        Utils.devSettings = photo:getDevelopSettings()        
        Utils.rawMetadata = photo:getRawMetadata()
        Utils.fmtMetadata = photo:getFormattedMetadata()
        
        local s, m = fso:copyFile( xmpFile, xmpFileToRestore, false, true ) -- directory already there, but do overwrite if necessary.
        if not s then
            app:show{ error=m }
            call:cancel()
            return
        end

        restoreXmp = true -- assume xmp overwritten after this point.
        local s, m = cat:savePhotoMetadata( photo, photoPath, xmpFile, call, false ) -- false => *do* validate.
        if not s then
            app:show{ error=m }
            call:cancel()
            return
        end
        
        local s, m = fso:copyFile( xmpFile, xmpFileFromCatalog, false, true ) -- directory already there, but do overwrite if necessary.
        if not s then
            app:show{ error=m }
            call:cancel()
            return
        end

        local s, m = fso:copyFile( xmpFileToRestore, xmpFile, false, true ) -- directory already there, but do overwrite if necessary.
        if s then
            app:log( "xmp has been restored to its original contents." )
            restoreXmp = false
        else
            app:show{ error=m }
            call:cancel()
            return
        end

        restoreCat = true
        local manualPrompt = "Reading Lightroom Metadata so settings can be assigned from xmp on disk."
        local s, m = cat:readPhotoMetadata( photo, photoPath, false, call, manualPrompt ) -- false => don't assume already in library module.
        if s then
            --[[ *** this does not work, save in case of inspiration...
            local inDevMod = false
            repeat
                local answer = app:show{ info="You can take a few seconds to do visual comparison now if you want.",
                    buttons = { dia:btn( "Yes - 5 seconds", 'ok' ), dia:btn( "No - continue", 'cancel' ) },
                    actionPrefKey = "Offer to do visual compare",
                }
                if answer == 'ok' then
                    if not inDevMod then
                        local s, m = gui:switchModule( 2 )
                        if s then
                            inDevMod = true
                        else
                            app:show{ error=m }
                        end
                    end
                    if inDevMod then
                        app:sleepUnlessShutdown( 5 )
                    end
                elseif answer == 'cancel' then
                    break
                end
            until false
            --]]
            -- log?
        else
            if not call:isCanceled() then -- user canceled without reading metadata suppposedly.
                app:show{ error=m }
                call:cancel()
            end
            return
        end
        
        -- these settings are disk settings - slight misnomer...
        CompareCatalog.devSettings = photo:getDevelopSettings()
        CompareCatalog.rawMetadata = photo:getRawMetadata()
        CompareCatalog.fmtMetadata = photo:getFormattedMetadata()

        local s, m = fso:copyFile( xmpFileFromCatalog, xmpFile, false, true ) -- directory already there, but do overwrite if necessary.
        if s then
            restoreXmp = true
        else
            app:show{ error=m }
            call:cancel()
            return
        end

        local manualPrompt = "Again, reading Lightroom metadata, this time so original catalog settings can be restored."
        local s, m = cat:readPhotoMetadata( photo, photoPath, false, call, manualPrompt ) -- false => don't assume already in library module.
        if s then
            restoreCat = false
            app:log( "Photo settings have been restored to their original values." )
        else
            if not call:isCanceled() then -- user canceled without reading metadata suppposedly.
                app:show{ error=m }
                call:cancel()
            end
            return
        end
        
        local s, m = fso:copyFile( xmpFileToRestore, xmpFile, false, true ) -- directory already there, but do overwrite if necessary.
        if s then
            app:log( "xmp has been restored to its original contents." )
            restoreXmp = false
        else
            app:show{ error=m }
            call:cancel()
            return
        end

        local changedDetails, changeDetailsMsg, disp = CompareCatalog.getChangeDetails( photo, full ) -- full => minimal exclusions.
        
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
        
        app:log( "Catalog vs Disk:\n^1", changeDetailsLf )
        app:log()
        
        local props = LrBinding.makePropertyTable( call.context )
        local args = {}
        args.title = app:getAppName() .. " - Presenting differences..."
        local mainItems = {}
        local name
        if app:getPref( 'justFilename' ) then
            name = LrPathUtils.leafName( photoPath )
        else
            name = photoPath
        end
        mainItems[#mainItems + 1] = 
            vf:static_text {
                title = str:fmt( "Photo: ^1\nNote: first item between bars is from catalog, second is from xmp on disk.\n \nDifferences:", name ),
            }
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
        args.cancelVerb = '< exclude >'
        -- args.resizable = true
        args.save_frame = 'PhotoComparisonPrompt'
        
        local answer = LrDialogs.presentModalDialog( args ) -- do comparison regardless of selection status.
        
    end, finale = function( call, status, message )

        if restoreCat then -- catalog settings do not, or may not have original values.
            if fso:existsAsFile( xmpFileFromCatalog ) then
                if fso:existsAsFile( xmpFileToRestore ) then
                    app:show{ error="Unable to restore catalog settings - you'll have to do it yourself - they're in '^1'. The original xmp is in '^2'.", xmpFileFromCatalog, xmpFileToRestore }
                else
                    app:show{ error="Unable to restore catalog settings - you'll have to do it yourself - they're in '^1'.", xmpFileFromCatalog }
                end
            else
                if fso:existsAsFile( xmpFileToRestore ) then
                    app:show{ error="Unable to restore catalog settings - the original xmp is in '^1'", xmpFileToRestore }
                else
                    app:show{ error="Unable to restore catalog settings." }
                end
            end
            -- don't delete original xmp either in this case.
        else
            if fso:existsAsFile( xmpFileToRestore ) then
                if restoreXmp then -- xmp does not (or may not) have original contents.
                    local s, m = fso:copyFile( xmpFileToRestore, xmpFile, false, true ) -- directory already there, but do overwrite if necessary.
                    if s then
                        app:log( "Xmp restored." )
                        LrFileUtils.delete( xmpFileToRestore )
                    else
                        app:show{ error="Unable to restore xmp - you'll have to do it yourself - its in '^1'. Error message: ^2", xmpFileToRestore, str:to ( m ) }
                    end
                else
                    LrFileUtils.delete( xmpFileToRestore )
                end
            -- else dont trip
            end
            if fso:existsAsFile( xmpFileFromCatalog ) then
                LrFileUtils.delete( xmpFileFromCatalog )
            end
        end
        cat:restoreSelPhotos( call.selPhotos )
        background:continue()
    
    end } )    
    
end



CompareCatalog.ToDisk() -- initiate asynchronously.
return true -- indicates to debugger that it completed the initiation.
