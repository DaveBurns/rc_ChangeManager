--[[
        Compare.lua
        
        Table of auto-publish functions.
        
        This can be upgraded to be a class if you prefer methods to static functions.
        Its generally not necessary though unless you plan to extend it, or create more
        than one...
--]]


local Compare = {}



local dbg, dbgf = Object.getDebugFunction( 'Compare' )



--- Get change details.
--
--  @return  change detected, or nil if trouble
--  @return  error message - remaining variables undefined if error...
--  @return  disp array
--
function Compare._getChangeDetails( photo1, photo2, dev1, dev2, devSetExcl, raw1, raw2, rawMetaExcl, fmt1, fmt2, fmtMetaExcl )

    --[[
    local devSetExcl, rawMetaExcl, fmtMetaExcl
    if full then
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.devSetExcl, Utils.rawMetaExcl, Utils.fmtMetaExcl
    else
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
    end
    --]]
    
    local disp = {}
    local ignoreUnids = app:getPref( "ignoreUnidentifiedChanges" )
    local changed = not ignoreUnids
    
    local devSettingsPrep = Utils.prepareSettings( dev2, devSetExcl )
    local devSettingsPrev = Utils.prepareSettings( dev1, devSetExcl )
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
        local rawMetadataPrep = Utils.prepareSettings( raw2, rawMetaExcl )
        local rawMetadataPrev = Utils.prepareSettings( raw1, rawMetaExcl )
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
    if type( fmtMetaExcl ) == 'table' or fmtMetaExcl ~= '*' then
        local fmtMetadataPrep = Utils.prepareSettings( fmt2, fmtMetaExcl )
        local fmtMetadataPrev = Utils.prepareSettings( fmt1, fmtMetaExcl )
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
    end
    return changed, nil, disp
end        



function Compare.compare( call, photo1, photo2, dev1, dev2, devExcl, raw1, raw2, rawExcl, fmt1, fmt2, fmtExcl, ui )

        local changedDetails, changeDetailsMsg, disp = Compare._getChangeDetails( photo1, photo2, dev1, dev2, devExcl, raw1, raw2, rawExcl, fmt1, fmt2, fmtExcl ) -- true => full comparison.
        
        if changeDetailsMsg then -- error
            if ui then
                app:show( { error=changeDetailsMsg } )
            else
                app:logWarning( changeDetailsMsg )
            end
            return
        end
        
        if not changedDetails then
            app:log( "No significant difference." )
            if ui then
                app:show( "No significant difference." )
            end
            return
        end
        
        --   P R O C E S S   C H A N G E S
        
        local changeDetailsCrLf = table.concat( disp, "\r\n" )
        local changeDetailsLf = table.concat( disp, "\n" )
        
        app:log( "Change Details:\n^1", changeDetailsLf )
        app:log()
        
        if not ui then
            return
        end
        
        local props = LrBinding.makePropertyTable( call.context )
        local args = {}
        args.title = app:getAppName() .. " - Presenting differences..."
        local mainItems = {}
        local fullPath = not app:getPref( 'justFilename' )
        if photo1 ~= photo2 then
            local name1 = cat:getPhotoNameDisp( photo1, fullPath )
            local name2 = cat:getPhotoNameDisp( photo2, fullPath )
            mainItems[#mainItems + 1] = 
                vf:static_text {
                    title = str:fmt( "First Photo: ^1\nSecond Photo: ^2\n \nDifferences:", name1, name2 ),
                }
        else
            local name = cat:getPhotoNameDisp( photo1, fullPath )
            mainItems[#mainItems + 1] = 
                vf:static_text {
                    -- title = str:fmt( "Photo: ^1\nNote: first item between bars is first selected state, second item is the comparison state.\n \nDifferences:", name2 ), -- too long when just filename
                    -- anyway, almost more confusing than just letting user figure it out(?)
                    title = str:fmt( "Photo: ^1\n \nDifferences:", name ),
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
        
        local answer = LrDialogs.presentModalDialog( args ) -- do comparison regardless of selection status.

end


return Compare
