--[[
        Utils.lua
        
        Table of shared utility functions.
        
        This can be upgraded to be a class if you prefer methods to static functions.
        Its generally not necessary though unless you plan to extend it, or create more
        than one...
--]]


local Utils = {}


-- default exclusions:
Utils.devSetExcl = {
    CropConstrainAspectRatio=true,              -- Has no impact on true develop settings.
    LensProfileSetup=true,                      -- It only matters what the actual (other) lens settings are.
    LensProfileDigest=true,                     -- Sometimes newly done lens profiles changes the digest (e.g. new Lr version).
}
Utils.rawMetaExcl = { editCount=true, lastEditTime=true, fileSize=true, metadataDate=true, croppedDimensions=true, customMetadata=true }
Utils.fmtMetaExcl = { fileSize=true, metadataDate=true, artist=true, dateCreated=true }
-- Utils.photoCheckTimes = {} -- Indexed by Photo-ID, stores the lastEditTime of photos when they're checked, to avoid the problem with saving a last-checked time in metadata.
-- that then makes the photo look edited again...
-- Note: This could also be store in prefs, but it seems better to just check once after startup to be sure, but then not keep checking...
Utils.devSetDeps = { -- Develop settings change dependencies - if old & new value is in control value group, then dependent setting changes are ignored.
    -- *** REMINDER: nil value must not be last or it won't have any effect. ALSO: - Values must be string, since comparison is to prepared settings.
    DefringeGreenAmount = { values = { nil, "0" }, ignore = { 'DefringeGreenHueHi', 'DefringeGreenHueLo', 'DefringeGreenAmount' } },
    DefringePurpleAmount = { values = { nil, "0" }, ignore = { 'DefringePurpleHueHi', 'DefringePurpleHueLo', 'DefringePurpleAmount' } },
    ProcessVersion = { values = { "6.7", "6.6" }, ignore = { 'Brightness', 'Contrast', 'Exposure', 'Shadows', 'FillLight', 'HighlightRecovery', 'Clarity', 'ChromaticAberrationB', 'ChromaticAberrationR', 'ToneCurve', 'ToneCurveName' } },
    LuminanceSmoothing = { values = { nil, "0" }, ignore = { 'LuminanceNoiseReductionContrast', 'LuminanceNoiseReductionDetail', 'LuminanceSmoothing'} },
    GrainAmount = { values = { nil, "0" }, ignore = { 'GrainFrequency', 'GrainSize' } },
    ColorNoiseReduction = { values = { nil, "0" }, ignore = { 'ColorNoiseReductionSmoothness', 'ColorNoiseReductionDetail' } },
    ColorNoiseReductionSmoothness = { values = { nil, "50" } }, -- no ignore list, means ignore difference between values.
    IncrementalTemperature = { values = { nil, "0" } },
    IncrementalTint = { values = { nil, "0" } },
} -- @7/May/2012 15:58 - not complete set.


local dbg = Object.getDebugFunction( 'Utils' )

local md5Types = {}

local PaintTable = Table:newClass{ className = 'PaintTable' }

function PaintTable:new( t )
    return Table.new( self, t )
end

function PaintTable:_md5( t )

    if t == nil then return end
    
    if self.visited [t] then return end
    self.visited [t] = true
    
    if type( t ) ~= 'table' then
        local val = str:to( t )
        -- app:logInfo( "Paint: " .. val )
        self.md5str[#self.md5str + 1] = val
    else
        for k,v in tab:sortedPairs( t ) do
            repeat
                if type( v ) == 'table' then
                    -- app:logInfo( "Paint Table: " .. val )
                    self:_md5( v )
                else
                    if type( k ) == 'string' then
                        local p1, p2 = k:find( "ID" )
                        if p2 and p2 == #k then
                            -- app:logInfo( "Skipping Paint Key: " .. k )
                            break
                        end
                    end
                    -- fall-through => not skipping.
                    local val = str:to( v )
                    -- app:logInfo( "Paint, index: " .. str:to( k ) ) -- .. ", val: " .. val )
                    self.md5str[#self.md5str + 1] = val
                end
            until true
        end 
    end

end



local GradientTable = Table:newClass{ className = 'GradientTable' }

function GradientTable:new( t )
    return Table.new( self, t )
end

function GradientTable:_md5( t )

    if t == nil then return end
    
    if self.visited [t] then return end
    self.visited [t] = true
    
    if type( t ) ~= 'table' then
        local val = str:to( t )
        -- app:logInfo( "Gradient value: " .. val )
        self.md5str[#self.md5str + 1] = val
    else
        for k,v in tab:sortedPairs( t ) do
            repeat
                if type( v ) == 'table' then
                    self:_md5( v )
                else
                    if type( k ) == 'string' then
                        local p1, p2 = k:find( "ID" )
                        if p2 and p2 == #k then
                            -- app:logInfo( "Skipping Gradient Key: " .. k )
                            break
                        end
                    end
                    local val = str:to( v )
                    -- app:logInfo( "Gradient table value, key: " .. str:to( k ) .. ", val: " .. val )
                    self.md5str[#self.md5str + 1] = str:to( v ) -- val
                end
            until true
        end 
    end

end



local ToneCurveTable = Table:newClass{ className = 'ToneCurveTable' }

function ToneCurveTable:new( t )
    return Table.new( self, t )
end

function ToneCurveTable:_md5( t )

    if t == nil then return end
    
    for i,v in ipairs( t ) do
        if type( v ) == 'table' then
            if app:getUserName() == '_RobCole_' then
                app:show( { error="Unexpected table in ToneCurve - being ignored." } )
            else
                app:logWarning( "Unexpected table in ToneCurve - being ignored." )
            end
        else
            local val = str:to( v )
            -- app:logInfo( "tonecurve, i: " .. i .. ", val: " .. val )
            self.md5str[#self.md5str + 1] = str:to( v ) -- val
        end
    end

end



local RedEyeTable = Table:newClass{ className = 'RedEyeTable' }

function RedEyeTable:new( t )
    return Table.new( self, t )
end

function RedEyeTable:_md5( t )

    if t == nil then return end
    
    if self.visited [t] then return end
    self.visited [t] = true
    
    for k,v in tab:sortedPairs( t ) do
        repeat
            if type( v ) == 'table' then
                self:_md5( v )
                break
            end
            if type( k ) == 'string' then
                local p1, p2 = k:find( "ID" )
                if p2 and p2 == #k then
                    -- app:logInfo( "Skipping RedEye setting, key: " .. k .. ", val: " .. str:to( v ) )
                    break
                end
            end
            
            local val = str:to( v )
            --app:logInfo( "RedEye, k: " .. str:to( k ) .. ", val: " .. val .. ", val-type: " .. type( v ) )
            self.md5str[#self.md5str + 1] = str:to( v ) -- val

        until true
    end

end



local RetouchTable = Table:newClass{ className = 'RetouchTable' }

function RetouchTable:new( t )
    return Table.new( self, t )
end

function RetouchTable:_md5( t )

    if t == nil then return end
    
    if self.visited [t] then return end
    self.visited [t] = true
    
    for k,v in tab:sortedPairs( t ) do
        repeat
            if type( v ) == 'table' then
                self:_md5( v )
                break
            end
            if type( k ) == 'string' then
                local p1, p2 = k:find( "ID" )
                if p2 and p2 == #k then
                    -- app:logInfo( "Skipping retouch, key: " .. k .. ", val: " .. str:to( v ) )
                    break
                end
            end
            
            local val = str:to( v )
            -- app:logInfo( "Retouch, key: " .. str:to( k ) .. ", val: " .. val )
            self.md5str[#self.md5str + 1] = str:to( v ) -- val

        until true
    end

end



local DimTable = Table:newClass{ className = 'DimTable' }

function DimTable:new( t )
    return Table.new( self, t )
end

--- Return (non-md5) representation of dimension table.
--
function DimTable:rep( t )

    if t == nil then return end

    return str:to( t.width ) .. ',' .. str:to( t.height )
    
end



local GpsTable = Table:newClass{ className = 'GpsTable' }

function GpsTable:new( t )
    return Table.new( self, t )
end

--- Return (non-md5) representation of dimension table.
--
function GpsTable:rep( t )

    if t == nil then return end

    return str:to( t.latitude ) .. ',' .. str:to( t.longitude )
    
end



local paintTable = PaintTable:new()
local toneCurveTable = ToneCurveTable:new()
local redEyeTable = RedEyeTable:new()
local retouchTable = RetouchTable:new()
local gradientTable = GradientTable:new()
-- local customMetadataTable = CustomMetadataTable:new() -- omission now hardcoded - not supported.
-- local cropDimTable = DimTable:new() -- omission hardcoded - supported in formatted metadata, not raw.
local dimTable = DimTable:new()
local gpsTable = GpsTable:new()



--- Get change details.
--
--  @return  change detected, or nil if trouble
--  @return  error message - remaining variables undefined if error...
--  @return  disp array
--
function Utils.getChangeDetails( photo, devSetExcl, rawMetaExcl, fmtMetaExcl, lastEditTime )
    assert( lastEditTime ~= nil, "no last edit time" )
    -- app:logInfo( "Getting change details" )
    if not devSetExcl then -- set to default tables if you want no extra exclusions, nil for standard change-check exclusions.
        assert( not rawMetaExcl and not fmtMetaExcl, "exclusions are all or nothing" ) 
        devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
    end
    local ignoreUnids = app:getPref( "ignoreUnidentifiedChanges" )
    local changed = not ignoreUnids
    local msg
    local disp = {}
    
    local devSettings = photo:getDevelopSettings()
    local devSettingsPrep = Utils.prepareSettings( devSettings, devSetExcl )
    local devSettingsPrev = photo:getPropertyForPlugin( _PLUGIN, 'devSettings' )
    if devSettingsPrev == nil then
        disp[#disp + 1] = 'No dev settings to check.'
    else
        disp[#disp + 1] = "Develop Settings Changes:"
        local t1_ = Utils.deserializeSettings( devSettingsPrev )
        local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( t1_, devSettingsPrep, disp, 100, devSetExcl, Utils.devSetDeps, true )
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
    local rawMetadataPrev = photo:getPropertyForPlugin( _PLUGIN, 'rawMetadata' )
    local rawMetadataPrep
    local rawMetadata
    if type( rawMetaExcl ) == 'table' or rawMetaExcl ~= '*' then
        rawMetadata = photo:getRawMetadata( nil ) -- all
        rawMetadataPrep = Utils.prepareSettings( rawMetadata, rawMetaExcl )
        rawMetadataPrev = photo:getPropertyForPlugin( _PLUGIN, 'rawMetadata' )
        if rawMetadataPrev == nil then
            disp[#disp + 1] = 'No raw metadata to check.'
        else
            disp[#disp + 1] = "Raw Metadata Changes:"
            local t1_ = Utils.deserializeSettings( rawMetadataPrev )
            local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( t1_, rawMetadataPrep, disp, 50, rawMetaExcl )
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
    local fmtMetadata = photo:getFormattedMetadata( nil ) -- all
    local fmtMetadataPrep = Utils.prepareSettings( fmtMetadata, fmtMetaExcl )
    local fmtMetadataPrev = photo:getPropertyForPlugin( _PLUGIN, 'fmtMetadata' )
    if fmtMetadataPrev == nil then
        disp[#disp + 1] = 'No formatted metadata to check.'
    else
        if type( rawMetaExcl ) == 'table' or rawMetaExcl ~= '*' then
            disp[#disp + 1] = "Formatted Metadata Changes:" -- to distinguish from raw-metadata changes.
        else
            disp[#disp + 1] = "Metadata Changes:" -- to simplify...
        end
        local t1_ = Utils.deserializeSettings( fmtMetadataPrev )
        local changesListed, changesUnlisted = Utils._appendDiffDispStringArr( t1_, fmtMetadataPrep, disp, 50, fmtMetaExcl )
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
    if devSettingsPrev == nil or rawMetadataPrev == nil or fmtMetadataPrev == nil then
        local s, m = cat:updatePrivate( 10, function( context, phase ) -- this rarely happens, since ordinarily 
            -- change details are not acquired unless photo is locked and changed - its more of a fail-safe in case something weird happened...
            -- best not to have the frequent change checks needing catalog write access, to avoid interference with other plugins like dev-meta.
            if devSettingsPrev == nil then
                local devSettingsSer = Utils.serializeSettings( devSettingsPrep )
                photo:setPropertyForPlugin( _PLUGIN, "devSettings", devSettingsSer )
            end
            if rawMetadataPrev == nil then
                local rawMetadataSer = Utils.serializeSettings( rawMetadataPrep ) -- nil input begets '' (blank) output.
                photo:setPropertyForPlugin( _PLUGIN, "rawMetadata", rawMetadataSer )
            end
            if fmtMetadataPrev == nil then
                local fmtMetadataSer = Utils.serializeSettings( fmtMetadataPrep )
                photo:setPropertyForPlugin( _PLUGIN, "fmtMetadata", fmtMetadataSer )
            end
        end )
        if s then
            --return changed, nil, disp
            msg = nil
        else
            --return nil, m
            changed = nil
            msg = m
            disp = nil
        end
    end
    if not changed and msg == nil then -- the whole thing has been checked, and nothing significant found.
        -- no reason to keep checking the same photo, unless last-edit-time changes again, since it would always be the same result.
        local id = cat:getRawMetadata( photo, "uuid", rawMetadata )
        assert( id ~= nil, "photo has no uuid" )
        --Utils.photoCheckTimes[id] = lastEditTime
        cat:setPropertyForPlugin( id .. "_lastEditTime", lastEditTime ) -- handles catalog access wrapper as necessary.
    end
    return changed, msg, disp
end        



function Utils.appendKeyValues( s, k, v1, v2, w, f, dev )
    local kLen = k:len()
    if v1 == nil then
        v1 = ""
    end
    if v2 == nil then
        v2 = ""
    end
    local len1 = v1:len()
    local len2 = v2:len()
    if kLen + len1 + len2 > w then
        s[#s + 1] = str:fmt( "^1:", k )
        s[#s + 1] = string.rep( "-", kLen * f )
        local dashLen
        if len1 > w then
            dashLen = w
        else
            dashLen = len1 * f
        end
        s[#s + 1] = str:fmt( "^1", v1 )
        s[#s + 1] = string.rep( "-", dashLen )
        if len2 > w then
            dashLen = w
        else
            dashLen = len2 * f
        end
        s[#s + 1] = str:fmt( "^1", v2 )
        s[#s + 1] = string.rep( "-", dashLen )
    elseif dev then
        local n1 = num:numberFromString( v1 ) -- better way? ###3
        if n1 then
            local n2 = num:numberFromString( v2 )
            if n2 then
                s[#s + 1] = str:fmt( "^1 | ^2 | ^3 | ^4", k, v1, v2, v2-v1 )
                return
            end
        end
        s[#s + 1] = str:fmt( "^1 | ^2 | ^3", k, v1, v2 )
    else
        s[#s + 1] = str:fmt( "^1 | ^2 | ^3", k, v1, v2 )
    end
end



--- Append difference between two tables of settings, to specified string array.
--
--  @param      t1      saved prepared settings.
--  @param      t2      newly acquired raw settings.
--
--  @usage      Make sure neither input is nil before calling.
--  @usage      nothing returned. Add header and save length before calling, test length upon return.
--
--  @return     number of listed changes.
--  @return     number of unlisted changes.
--
function Utils._appendDiffDispStringArr( t1_, t2_, s, m, e, deps, dev )
    local f = app:getPref( 'widthFactor' ) or 1.4
    local w = ( app:getPref( 'compareWidth' ) or 70 ) * f
    local diff
    
    local function equiv( t, v1, v2 )
        local e1, e2
        for i = 1, #t do
            if v1 == t[i] then
                e1 = true
            end
            if v2 == t[i] then
                e2 = true
            end
        end
        return e1 and e2
    end
    
    deps = deps or {}
    for k, v in pairs( deps ) do
        assert( #v.values > 0, "no values" )
        if v.ignore then -- check dependencies
            for i = 1, #v.values do -- must not use ipairs since nil is legal value
                local value = v.values[i]
                if t1_[k] == value then
                    for i2 = 1, #v.values do
                        local value2 = v.values[i2]
                        if t2_[k] == value2 then
                            for i3, v3 in ipairs( v.ignore ) do
                                -- e[v3] = true - not OK since it would make exclusion permanent (e array is passed by ref).
                                -- Debug.pause( v3 )
                                -- cheating by nilling out the settings instead of defining them as exclusions.
                                t1_[v3] = nil
                                t2_[v3] = nil
                            end
                            break
                        end
                    end
                    break
                end
            end
        else -- check equivalence
            if equiv( v.values, t1_[k], t2_[k] ) then
                t1_[k] = nil
                t2_[k] = nil
            end
        end
    end
    
    diff = Utils.compareSettings( t1_, t2_, e )
    local count = 0
    local count2 = 0
    if diff then
        for k, v in tab:sortedPairs( diff ) do
            count2 = count2 + 1
            if count < m then
                if md5Types[k] then -- cryptic
                    s[#s + 1] = md5Types[k] -- values dont matter.
                else
                    Utils.appendKeyValues( s, k, v[1], v[2], w, f, dev )
                end
                count = count + 1
            else
                app:logVerbose( "Omitting presentation of '^1'", k )
            end
        end
    else
        -- nothing added
    end
    return count, count2 - count
end



--- Append difference between two tables of settings, to specified string array.
--
--  @param      t1      saved serialized settings.
--  @param      t2      newly acquired raw settings.
--
--  @usage      Make sure neither input is nil before calling.
--  @usage      nothing returned. Add header and save length before calling, test length upon return.
--
--  @return     number of listed changes.
--  @return     number of unlisted changes.
--
function Utils.________appendDiffDispStringArr( t1, t2_, s, m, e, deps )
    local f = app:getPref( 'widthFactor' ) or 1.4
    local w = ( app:getPref( 'compareWidth' ) or 70 ) * f
    local diff
    local t1_ = Utils.deserializeSettings( t1 )
    
    deps = deps or {}
    for k, v in pairs( deps ) do
        assert( #v.values > 0, "no values" )
        for i = 1, #v.values do -- must not use ipairs since nil is legal value
            local value = v.values[i]
            if t1_[k] == value then
                --Debug.pause( k, value )
                for i2 = 1, #v.values do
                    local value2 = v.values[i2]
                    if t2_[k] == value2 then
                        --Debug.pause( k, value2 )
                        for i3, v3 in ipairs( v.ignore ) do
                            -- e[v3] = true - not OK since it would make exclusion permanent (e array is passed by ref).
                            --Debug.pause( v3 )
                            -- cheating by nilling out the settings instead of defining them as exclusions.
                            t1_[v3] = nil
                            t2_[v3] = nil
                        end
                        break
                    end
                end
                break
            --else
            --    Debug.pause( "No match", k, value, t1_[k] )
            end
        end
    end
    
    diff = Utils.compareSettings( t1_, t2_, e )
    local count = 0
    local count2 = 0
    if diff then
        for k, v in tab:sortedPairs( diff ) do
            count2 = count2 + 1
            if count < m then
                if md5Types[k] then -- cryptic
                    s[#s + 1] = md5Types[k] -- values dont matter.
                else
                    --s[#s + 1] = str:fmt( "^1 | ^2 | ^3", k, str:squeezeToFit( v[1] or '', 40 ), str:squeezeToFit( v[2] or '', 40 ) )
                    Utils.appendKeyValues( s, k, v[1], v[2], w, f )
                end
                count = count + 1
            else
                app:logVerbose( "Omitting presentation of '^1'", k )
            end
        end
    else
        -- nothing added
    end
    return count, count2 - count
end



--- Prepare settings for serialization, or comparison to deserialized settings.
--
--  @param t develop settings or metadata table.
--
--  @param excl @2011-01-09, exclusions are only passed when doing change detection, i.e. saved settings have no exclusions.
--              I'm considering revisiting this decision for performance reasons.
--
function Utils.prepareSettings( t, excl )
    local t2 = {}
    excl = excl or {}
    for k,v in tab:sortedPairs( t ) do
        repeat
            if excl[k] then
                break
            end
            if type( v ) ~= 'table' then
                t2[k] = tostring( v or false ) -- 2011-01-2X - added the "or false" clause, so things going from nil to false did not trigger changes.
            else
                -- app:logInfo( "\ntable key: " .. k )
                if k:find( "Paint" ) then -- by far the biggest table of settings.
                    md5Types[k] = "Adjustment Brush"
                    t2[k] = paintTable:md5( v )
                elseif k:find( "Tone" ) then
                    md5Types[k] = "Tone Curve"
                    t2[k] = toneCurveTable:md5( v )
                elseif k:find( "RedEye" ) then
                    md5Types[k] = "Red Eye Correction"
                    t2[k] = redEyeTable:md5( v )
                elseif k:find( "Retouch" ) then
                    md5Types[k] = "Spot Removal"
                    t2[k] = retouchTable:md5( v )
                elseif k:find( "Gradient" ) then
                    md5Types[k] = "Graduated Filter"
                    t2[k] = gradientTable:md5( v )
                elseif k:find( "customMeta" ) then
                    -- t2[k] = toneCurveTable:md5( v )
                    -- ignore custom-metadata.
                elseif k:find( "croppedDim" ) then
                    -- t2[k] = dimTable:rep( v ) - this is version from raw-metadata - just ignore and use fmt'd version.
                elseif k:find( "dimension" ) then
                    t2[k] = dimTable:rep( v )
                elseif k:find( "gps" ) then
                    t2[k] = gpsTable:rep( v )
                elseif k:find( "keywords" ) then
                    dbg( "keyword table in raw-metadata not handled via md5 - let formatted metadata handle it..." )
                elseif k:find( "stackInFolderMembers" ) then
                    dbg( "stack-in-folder-members is being excluded from change consideration - it's hardcoded." )
                elseif k:find( "virtualCopies" ) then
                    dbg( "virtual-copies is being excluded from change consideration - it's hardcoded." )
                elseif k:find( "smartPreviewInfo" ) then
                    dbg( "smart-preview-info is being excluded from change consideration - it's hardcoded." )
                else
--[[
 @Lr4b:
 ------
01/16/2012 13:45:05 WARN	****** WARNING #2: Unexpected table in settings (being handled as generic): keywords 
01/16/2012 13:45:05 WARN	****** WARNING #3: Unexpected table in settings (being handled as generic): stackInFolderMembers 
01/16/2012 13:45:05 WARN	****** WARNING #4: Unexpected table in settings (being handled as generic): virtualCopies 

 @Lr5.0:
 ------
01/16/2012 13:45:05 WARN	****** WARNING #1: Unexpected table in settings (being handled as generic): smartPreviewInfo 

Note:; RGB curve changes are being automatically flagged as "Tone Curve" changes - good, although might be worth discerning rgb vs. color... ###3.
--]]
                    local m = str:fmt( "Unexpected table in settings (being handled as generic): ^1", str:to( k ) )
                    if app:getUserName() == '_RobCole_' then
                        app:show{ warning=m }
                    else
                        app:logWarning( m )
                    end
                    md5Types[k] = k
                    t2[k] = tab:md5( v )
                end
                -- app:logInfo( "end of table: " .. k .. "\n\n" )
            end
        until true
        -- LrTasks.yield() -- reduces stuttering of scroll-bar in develop module. Only does change details one time now.    
    end
    return t2
end



--- Convert settings to string form suitable for saving as custom metadata.
--
--  @usage      ###2 may need to escape stuff that is not suitable(?)
--              another option would be to convert to lua and save as sidecar.
--
--              In fact, I could just skip custom metadata altogether and avoid the other pitfalls as well, hmmm...
--
function Utils.serializeSettings( t )
    if t == nil then
        return ''
    end
    local t2 = {}
    for k,v in pairs( t ) do
        t2[#t2 + 1] = k .. "_=_" .. tostring( v )
    end
    local s = table.concat( t2, '_;_' )
    return s
end



--- Convert settings from serialized string to table suitable for comparing to prepared settings.
--
--  @usage      Only works properly if chosen tokens are not present as data too.
--
function Utils.deserializeSettings( s )
    local t = str:split( s, '_;_' )
    local t2 = {}
    for i,v in ipairs( t ) do
        local s2 = str:split( v, '_=_' )
        if not tab:isEmpty( s2 ) then
            if s2[1] then
                t2[s2[1]] = s2[2]
            else
                error( "Unable to deserialize settings." )
            end
        --else
        end
    end
    return t2
end



--- Compare prepared settings to deserialized settings.
--
--  @param      t1      table one (previous settings I think).
--  @param      t2      table two (current settings I think).
--  @param      excl    exclusions: "excl[key] = true" to exclude...
-- 
--  @usage      value may be nil if non-existent in other table, or nil in other table.
--
--  @return     table: keyed by setting name; each entry contains an array with two items when differences are encountered:
--              <br>- value from first table.
--              <br>- value from second table.
--
function Utils.compareSettings( t1, t2, excl )
    local t3 = {}
    -- add items from t1 that are different or not found in t2.
    for k1, v1 in pairs( t1 ) do
        if not excl[k1] and v1 ~= t2[k1] then
            t3[k1] = { v1, t2[k1] }
        end
    end
    -- add items from t2 that are not found in t1.
    for k2, v2 in pairs( t2 ) do
        if not excl[k2] and v2 ~= t1[k2] then
            t3[k2] = { t1[k2], v2 }
        end
    end
    return t3
end



--- Unlock real photo
--
--  @usage  Set targ to read/write, and record metadata.
--
function Utils.unlockPhoto( photo, photoPath, targ, photoName )
    if targ then
        local s, m = fso:makeReadWrite( targ )
        if s then
            app:logVerbose( "Made read/write: " .. targ )
        else
            return false, "Unable to set xmp to read/write: " .. m -- path logged in calling context?
        end
    -- else virtual
    end
    local s, m = Utils._unlockCommon( photo, photoName )
    return s, m
end



--- Unlock real photo
--
--  @usage  Set targ to read/write, and record metadata.
--
function Utils._unlockPhoto( photo, photoPath, targ, photoName, clearLabel )
    if targ then
        local s, m = fso:makeReadWrite( targ )
        if s then
            app:logVerbose( "Made read/write: " .. targ )
        else
            return false, "Unable to set xmp to read/write: " .. m -- path logged in calling context?
        end
    -- else virtual
    end
    local s, m = Utils.__unlockCommon( photo, photoName, clearLabel )
    return s, m
end



--- Unlock stuff common to both real and virtual.
--
--  @usage  wrap for errors externally, cat wrap is internal.
--
function Utils._unlockCommon( photo, photoName )
    local skip, lockedLabel = Utils._checkLabel{ photo }
    if not skip then
        return false, "Unlock canceled"
    end
    local s, m = cat:update( 10, "Unlock " .. photoName, function( context, phase )
        Utils.__unlockCommon( photo, photoName, str:is( lockedLabel ) and not skip[photo] )
    end )
    return s, m
end



--- Unlock stuff common to both real and virtual.
--
--  @usage not wrapped at all.
--
function Utils.__unlockCommon( photo, photoName, clearLabel )
    if clearLabel then
        photo:setRawMetadata( 'label', "" ) -- clear it ( Lr throws error if nil ).
    end
    photo:setPropertyForPlugin( _PLUGIN, 'locked', "no" )
    local time = LrDate.currentTime()
    photo:setPropertyForPlugin( _PLUGIN, 'lockDate', LrDate.timeToUserFormat( time , "%Y-%m-%d %H:%M:%S" ) )
    changeColl:removePhotos{ photo } -- requires full write access
    -- photo:setPropertyForPlugin( _PLUGIN, 'lockDate_', time ) - presently a dont care if not locked - could conceivably be able to
    -- check changes since unlockage as well but thats not happening yet - uncomment if it does start to happen...
    return true
end



--- Determine if photo is changed or not.
--
--  @usage      File is expected to exist, although target may be being written asynchronously while this function is being called.
--
--  @return     status      true if changed, false if unchanged, nil if indeterminate.
--  @return     lock-time   lock status change date - formatted. nil if photo has not changed.
--  @return     edit-time   last edit date - raw. nil if photo has not changed.
--
function Utils.isChanged( photo, rawMeta )
    local id = cat:getRawMetadata( photo, 'uuid', rawMeta )
    local checkKey = id .. "_lastEditTime" -- id proper is reserved for background task, so all others must suffix. ***
    -- until 22/Sep/2011 18:05 - local checkTime = catalog:getPropertyForPlugin( _PLUGIN, checkKey )
    local checkTime = cat:getPropertyForPlugin( checkKey )
    local editTime = cat:getRawMetadata( photo, 'lastEditTime', rawMeta )
    if checkTime == editTime then -- Hopefully we can assume last-edit-time is never nil.
        --dbg( "Not changed: " .. photo:getRawMetadata( 'path' ) )
        -- uncomment to force change for testing purposes: if true then return true, (photo:getPropertyForPlugin( _PLUGIN, 'lockDate' ) or "unknown"), LrDate.currentTime() end
        return false -- editTime: could return edit-time, but shouldnt have to.
    end
    local time = photo:getPropertyForPlugin( _PLUGIN, 'lockDate' ) or "unknown"
    dbg( "Changed: " .. cat:getRawMetadata( photo, 'path', rawMeta ), "lock time:", checkTime, "edit time:", editTime  ) 
    return true, time, editTime 
end



--- Determine if photo is locked or not.
--
-- @return      true => locked, false => not locked, nil => bad metadata.
-- @return      nil => no issues, string => error message.
--
function Utils.isLocked( photo )
    local locked, message = photo:getPropertyForPlugin( _PLUGIN, 'locked', nil, true )
    if locked then
        if locked == 'yes' then
            return true
        elseif locked == 'no' then
            return false
        else
            return nil, "bad lock status for " .. photo:getRawMetadata( 'path' )
        end
    elseif message then
        return nil, message
    else
        return false -- convert nil to false.
    end
end



-- Clear metadata change flag.
--
--  @usage determination of whether change flag needs clearing should be done before calling.
--
--[[ *** Save for possible future resurrection.
function Utils.clearMetadataChangeFlag( photo, photoPath, targ )
    local s, m
    if targ then
        local readOnly, msg = fso:isReadOnly( targ )
        if msg then
            return false, msg
        end
        if readOnly then
            s, m = fso:makeReadWrite( targ )
            if not s then
                return false, m
            end
        end
        s, m = cat:savePhotoMetadata( photo, photoPath, targ ) -- flush changes from catalog to xmp, before sealing the deal...
        if not s then
            return false, m
        end
        if readOnly then
            s, m = fso:makeReadOnly( targ )
            if not s then
                return false, m
            end
        end
    else
        -- ###
    end
end
--]]



--- Lock a photo - real or virtual.
--
--  @usage If real, makes xmp read-write, selects single photo, saves metadata, optionally takes snapshot and saved metadata again, makes xmp read-only.
--         <br>If virtual, skips the xmp part.
--
function Utils.lockPhoto( photo, photoPath, targ, photoName, snapshotAndMarkParams )
    local s, m
    if targ then -- not a virtual copy
        s, m = fso:makeReadWrite( targ )
        if not s then
            return false, m
        end
        if not snapshotAndMarkParams.snapshot then
            if MAC_ENV then
                LrTasks.sleep( .1 )
            end
            s, m = cat:savePhotoMetadata( photo, photoPath, targ ) -- flush changes from catalog to xmp, before sealing the deal...
            if not s then
                return false, m
            end
        -- else skip saving metadata until after snapshot.
        end
    end
    s, m = Utils._lockCommon( photo, photoPath, nil, photoName, snapshotAndMarkParams ) -- lock metadata including snapshot (which changes metadata status).
    if not s then
        return false, m
    elseif MAC_ENV then
        LrTasks.sleep( .1 )
    end
    if targ then
        if snapshotAndMarkParams.snapshot then -- metadata changed again.
            s, m = cat:savePhotoMetadata( photo, photoPath, targ ) -- flush changes from catalog to xmp, before sealing the deal...
            if not s then
                return false, m
            elseif MAC_ENV then -- check whether mode is 'auto', since no need to sleep if manual mode 
                LrTasks.sleep( .5 ) -- takes mac a while to save metadata just after a snapshot for some reason.
            end
        end
        s, m = fso:makeReadOnly( targ )
        if not s then
            return false, m
        end
    end
    return true
end



--- Skip photo, meaning allow unresolved change to persist.
--
--  @param photo photo being skipped.
--
--  @usage  Just puts photo in change collection.
--
function Utils.collect( photo, photoName )
    local s, m = cat:update( 15, "Skip and Collect " .. photoName, function( context )
        changeColl:addPhotos{ photo } -- requires full write access.
    end )
    return s, m
end



function Utils._checkLabel( photos, forLocking )
    local lockedLabel = app:getPref( "lockedLabel" )
    if not str:is( lockedLabel ) then
        return true -- take care to not index as array upon return.
    end
    local skip = {}
    local n = 0
    for i, photo in ipairs( photos ) do
        local label = photo:getFormattedMetadata( 'label' )
        if str:is( label ) and label ~= lockedLabel then
            skip[photo] = true
            n = n + 1
        end
    end
    if n == 0 then
        return {}, lockedLabel
    end
    local actionPrefKey
    local tidbit
    if forLocking then
        actionPrefKey = "What to do about pre-existing labels when locking"
        tidbit = "Overwrite"
    else
        actionPrefKey = "What to do about pre-existing labels when unlocking"
        tidbit = "Clear"
    end
    local btn = app:show{ confirm="^1 with pre-existing label. What do you want to do?",
        subs = str:nItems( n, "photos" ),
        buttons = { dia:btn( str:fmt( "^1 Label", tidbit ), 'ok' ), dia:btn( "Leave Pre-existing Label", 'other' ) },
        actionPrefKey = actionPrefKey,
    }
    if btn == 'other' then
        return skip, lockedLabel
    elseif btn == 'ok' then
        return {}, lockedLabel
    else
        return nil -- cancel.
    end
end



function Utils.updateLabels()
    app:call( Service:new{ name="Update Labels", async=true, progress={ caption="Dialog box needs your attention..." }, main=function( call )
        local photo = catalog:getTargetPhoto()
        local photos = catalog:getTargetPhotos()
        if not photo or #photos == 0 then
            app:show{ warning="Select photo(s) first." }
            call:cancel()
            return
        end
        local s, m = background:pause()
        if not s then
            call:abort( "background task won't pause" )
            return
        end
        local sub = str:nItems( #photos, "selected photos" )
        local btn = app:show{ confirm="Update lock labels for up to ^1?",
            subs = { sub },
            -- buttons = { dia:btn( str:fmtx( "Yes - ^1", sub ), 'ok' ) }, -- ###3 needs more thought, dia:btn( "Whole Catalog", 'other' ) },
            buttons = { dia:btn( "Yes, but only if no label", 'ok' ), dia:btn( "Yes - overwrite existing labels", 'other' ) },
        }
        if btn == 'cancel' then
            call:cancel()
            return
        end
        local overwrite
        if btn == 'other' then
            --###3photos = catalog:getAllPhotos()
            overwrite = true
        end
        call:setCaption( "Preparing to update ^1", str:nItems( #photos, "photos" ) )
        --[[
        local skip, lockedLabel = Utils._checkLabel( photos, true ) -- for locking.
        if not skip then
            call:cancel()
            return
        end
        if str:is( lockedLabel ) then
            app:log( "Lock Label: ^1", lockedLabel )
        else
            app:logWarning( "To clear lock label, just re-lock" ) -- ###3
            return
        end
        --]]
        local lockedLabel = app:getPref( 'lockedLabel' ) or ""
        if str:is( lockedLabel ) then
            app:log( "Lock Label: ^1", lockedLabel )
        else
            app:log( "Clearing lock label" )
        end
        app:log()
        local cache = lrMeta:createCache{ photos=photos, rawIds={ 'path' } } -- , fmtIds={ 'fileName' } }
        local s, m = cat:update( 20, call.name, function( context, phase )
            local i1, i2 = ( phase - 1 ) * 1000 + 1, math.min( phase * 1000, #photos )
            for i = i1, i2 do
                local photo = photos[i]
                local photoPath = cache:getRawMetadata( photo, 'path' )
                local fileName = LrPathUtils.leafName( photoPath )
                call:setCaption( "#^1: ^2", i, fileName )
                app:log( "Considering ^1", photoPath )
                local oldLabel = photo:getFormattedMetadata( 'label' )
                if Utils.isLocked( photo ) then
                    if overwrite or not str:is( oldLabel ) then
                        if oldLabel ~= lockedLabel then
                            local fmtMetadata = photo:getFormattedMetadata( nil ) -- all
                            photo:setRawMetadata( 'label', lockedLabel )
                            fmtMetadata['label'] = lockedLabel
                            local fmtMetadataPrep = Utils.prepareSettings( fmtMetadata )
                            local fmtMetadataSer = Utils.serializeSettings( fmtMetadataPrep )
                            photo:setPropertyForPlugin( _PLUGIN, "fmtMetadata", fmtMetadataSer )
                            app:log( "Updated from '^1' to '^2'", oldLabel, lockedLabel )
                        else
                            app:logVerbose( "Label already up to date: ^1", lockedLabel )
                        end
                    elseif oldLabel == lockedLabel then
                        app:log( "Label OK as is: ^1", lockedLabel )
                    else
                        app:log( "Not overwriting pre-existing label: ^1", oldLabel )
                    end
                elseif str:is( oldLabel ) then
                    app:logVerbose( "Not locked - label to remain '^1', unless you lock, or use native Lr to clear or change.", oldLabel )
                else
                    app:logVerbose( "Not locked, and no label - no change." )
                end
                if call:isQuit() then
                    return true
                else
                    call:setPortionComplete( i, #photos )
                end
            end
            if i2 < #photos then
                return false
            end
        end )
    end, finale=function( call )
        background:continue()
        if call.status then
            app:log()
            app:log( "No uncaught errors." )
        else
            -- std err log.
        end
    end } )
end



--  Lock stuff common to both real and virtual copies - only called for single-photo lock via auto-check, or interactive-check.
--
--  @usage  Not sure why, but sometimes the table settings change unless re-read / re-computed just prior to saving.
--
function Utils._lockCommon( photo, photoPath, copyName, photoName, snapshotAndMarkParams )

    local skip, lockedLabel = Utils._checkLabel( { photo }, true ) -- for locking.
    if not skip then
        return false, "Lock canceled"
    end

    local s, m
    local lockFunc = function( context, phase )
        if phase == 1 and str:is( lockedLabel ) and not skip[photo] then
            photo:setRawMetadata( 'label', lockedLabel )
            return false
        end
        local time = LrDate.currentTime()
        local timeFmt = LrDate.timeToUserFormat( time , "%Y-%m-%d %H:%M:%S" )
        photo:setPropertyForPlugin( _PLUGIN, 'locked', "yes" )
        photo:setPropertyForPlugin( _PLUGIN, 'lockDate', timeFmt )
        
        -- settings, which theoretically should not change, seem to be changing.
        local devSettings = photo:getDevelopSettings()
        local devSettingsPrep = Utils.prepareSettings( devSettings )
        local devSettingsSer = Utils.serializeSettings( devSettingsPrep )
        photo:setPropertyForPlugin( _PLUGIN, "devSettings", devSettingsSer ) -- could use meta-update-custom_metadata, but not sure of the value in it, since last-edit-time is already to be modified.
        local rawMetadata = photo:getRawMetadata( nil ) -- all
        local rawMetadataPrep = Utils.prepareSettings( rawMetadata )
        local rawMetadataSer = Utils.serializeSettings( rawMetadataPrep )
        photo:setPropertyForPlugin( _PLUGIN, "rawMetadata", rawMetadataSer )
        local fmtMetadata = photo:getFormattedMetadata( nil ) -- all
        local fmtMetadataPrep = Utils.prepareSettings( fmtMetadata )
        local fmtMetadataSer = Utils.serializeSettings( fmtMetadataPrep )
        photo:setPropertyForPlugin( _PLUGIN, "fmtMetadata", fmtMetadataSer )
        if snapshotAndMarkParams.snapshot or snapshotAndMarkParams.mark then
            local p = tab:addItems( { photo=photo, photoPath=photoPath, rawMeta=rawMetadata, fmtMeta=fmtMetadata, devSettings=devSettings }, snapshotAndMarkParams )
            snapshotAndMark:snapshotAndMarkPhoto( p )
        end
        changeColl:removePhotos{ photo } -- requires full write access.
    end
    -- Note: with this new edit-time-func approach, I could return to the more efficient batch locking, instead of one-by-one.
    local lockTimeFunc = function()
        local t = photo:getRawMetadata( 'lastEditTime' ) -- ### raw-meta?
        local key = photo:getRawMetadata( 'uuid' ) .. "_lastEditTime"
        cat:setPropertyForPlugin( key, t )
    end
    local title
    if snapshotAndMarkParams.snapshot then
        title = "Snapshot and Lock  " .. photoName
    else
        title = "Lock " .. photoName
    end
    s, m = cat:update( 15, title, lockFunc )
    if s then
        lockTimeFunc() -- present incarnation (@22/Sep/2011 18:33) does not require with-do gate).
    end
    return s, m

end



--- Record lockage.
--
--  @usage  Assumes full write access because of the change collection.
--
--  @usage  Reminder: last-edit-time is set to time of catalog commission, not time of initial call!!!
--          <br>which is why catalog must be updated one photo at a time - so change detection works.
--
function Utils.recordLockage( photo, label )

    -- settings, which theoretically should not change, seem to be changing.
    local devSettings = photo:getDevelopSettings()
    local devSettingsPrep = Utils.prepareSettings( devSettings )
    local devSettingsSer = Utils.serializeSettings( devSettingsPrep )
    photo:setPropertyForPlugin( _PLUGIN, "devSettings", devSettingsSer )
    local rawMetadata = photo:getRawMetadata( nil ) -- all
    local rawMetadataPrep = Utils.prepareSettings( rawMetadata )
    local rawMetadataSer = Utils.serializeSettings( rawMetadataPrep )
    photo:setPropertyForPlugin( _PLUGIN, "rawMetadata", rawMetadataSer )
    local fmtMetadata = photo:getFormattedMetadata( nil ) -- all
    if str:is( label ) then
        photo:setRawMetadata( 'label', label )
        fmtMetadata['label'] = label
    end
    local fmtMetadataPrep = Utils.prepareSettings( fmtMetadata )
    local fmtMetadataSer = Utils.serializeSettings( fmtMetadataPrep )
    photo:setPropertyForPlugin( _PLUGIN, "fmtMetadata", fmtMetadataSer )
    
    changeColl:removePhotos{ photo } -- requires full write access.
    photo:setPropertyForPlugin( _PLUGIN, 'locked', "yes" ) -- redundent, but comforting...
    local time = LrDate.currentTime()
    local timeFmt = LrDate.timeToUserFormat( time , "%Y-%m-%d %H:%M:%S" )
    photo:setPropertyForPlugin( _PLUGIN, 'lockDate', timeFmt )
    -- photo:setPropertyForPlugin( _PLUGIN, 'lockDate_', time ) - obsolete @25/Aug/2011 2:40
end



--- Revert locked photo to locked state.
--
--  @usage      depends on only one target photo being selected - but does not check for it: be sure to select one-and-only-one before calling.
--
function Utils.revert( photo, photoPath, targ, photoName, alreadyInLib )

    -- assert targ? I mean, this should not be done for virtual copies.

    local time = LrDate.currentTime()
    local timeFmt = LrDate.timeToUserFormat( time, "%Y-%m-%d %H:%M:%S" )
    
    if dialog:isOkOrDontAsk( "The success of the reversion operation depends on you having answered the Lightroom 'Read Metadata' warning prompt, and checked the box \"Don't show again\".\n \nFeel free to proceed if you are uncertain - if the aformentioned warning prompt pops up, you'll need to answer it as described, and then retry this operation.\n \nProceed?", "Reversion requires reading metadata" ) then
        -- go
    else
        app:logInfo( "Reversion canceled by user." )
        return
    end
    
    local manualPrompt = "Reading Lightroom metadata, to revert photo."
    local s, m = cat:readPhotoMetadata( photo, photoPath, alreadyInLib, nil, manualPrompt ) -- false => may not already be in library module. nil => no call/service object (no progress no stats...)
        -- nil => no call/service object.
        -- Note: side-effect of this function is selection of single photo.
        -- Note: side-effect of this function is selection of single photo.
        -- Note: side-effect of this function is selection of single photo.
    if s then
        local s, m = cat:update( 15, "Revert " .. photoName, function( context, phase )
            Utils.revertLockage( photo )
        end )
        if s then
            Utils.revertLockage2( photo ) -- assures freshly reverted photos don't trigger change detector.
        end
        return s, m
    else
        -- app:logError( "Unable to use metadata menu to revert photo - probably in develop mode: switch to library mode to revert." )
        return false, "Unable to use metadata menu to revert photo - either because not in library mode, in which case: switch to library mode to revert. Or, because the Lr read metadata prompt came up, in which case: please check the 'Dont show again box', then click 'Read', and try again. Another possibility is that some other dialog box is up - all dialog boxes must be closed before reversion will succeed."
    end
    error( "should not reach here" )
end



--- record lock settings and remove photo from change collection
--
--  @usage not wrapped internally, so wrap externally (both kinds: error + cat-with-do).
--
function Utils.revertLockage( photo )
    local devSettings = photo:getDevelopSettings()
    local devSettingsPrep = Utils.prepareSettings( devSettings )
    local devSettingsSer = Utils.serializeSettings( devSettingsPrep )
    photo:setPropertyForPlugin( _PLUGIN, "devSettings", devSettingsSer )
    local rawMetadata = photo:getRawMetadata( nil ) -- all
    local rawMetadataPrep = Utils.prepareSettings( rawMetadata )
    local rawMetadataSer = Utils.serializeSettings( rawMetadataPrep )
    photo:setPropertyForPlugin( _PLUGIN, "rawMetadata", rawMetadataSer )
    local fmtMetadata = photo:getFormattedMetadata( nil ) -- all
    
    -- maybe should be passed in ###3
    local lockedLabel = app:getPref( 'lockedLabel' )
    if str:is( lockedLabel ) then
        photo:setRawMetadata( 'label', lockedLabel )
        fmtMetadata['label'] = lockedLabel
    end
    
    local fmtMetadataPrep = Utils.prepareSettings( fmtMetadata )
    local fmtMetadataSer = Utils.serializeSettings( fmtMetadataPrep )
    photo:setPropertyForPlugin( _PLUGIN, "fmtMetadata", fmtMetadataSer )
    changeColl:removePhotos{ photo }
end



function Utils.revertLockage2( photo, rawMeta )
    cat:setPropertyForPlugin( cat:getRawMetadata( photo, 'uuid', rawMeta ) .. "_lastEditTime", cat:getRawMetadata( photo, 'lastEditTime', rawMeta ) )
end



--- Get setting and metadata exclusions from preferences, plus added items.
--
function Utils.getExclusions()

    local devSetExcl = app:getPref( "devSetExcl" )
    if devSetExcl == nil then
        error( "Dev set exclusions not defined." )
    end
    tab:addItems( devSetExcl, Utils.devSetExcl )
    if devSetExcl == nil then
        error( "Dev set exclusion failure." )
    end
    
    local rawMetaExcl = app:getPref( "rawMetaExcl" )
    if rawMetaExcl == nil then
        error( "Raw metadata exclusions not defined." )
    end
    if type( rawMetaExcl ) == 'table' then
        tab:addItems( rawMetaExcl, Utils.rawMetaExcl )
        if rawMetaExcl == nil then
            error( "Raw metadata exclusion failure." )
        end
    end
    
    local fmtMetaExcl = app:getPref( "fmtMetaExcl" )
    if fmtMetaExcl == nil then
        error( "Formatted metadata exclusions not defined." )
    end
    tab:addItems( fmtMetaExcl, Utils.fmtMetaExcl )
    if fmtMetaExcl == nil then
        error( "Formatted metadata exclusion failure." )
    end
    
    return devSetExcl, rawMetaExcl, fmtMetaExcl
end



--- Get photo info.
--
--  @param photo the photo
-- 
--  @usage returns form, photoPath, targ, photoName, photoPathName, copyName
--         <br>if targ is nil its a virtual copy. copy-name is populated for all copy types.
--         <br>form is nil for video files only.
--
function Utils.getPhotoInfo( photo, rawMeta )
    local photoPath = cat:getRawMetadata( photo, 'path', rawMeta )
    local form = cat:getRawMetadata( photo, 'fileFormat', rawMeta )
    if form == 'VIDEO' then
        return nil, photoPath -- videos are always ignored anyway
    end
    local virt = cat:getRawMetadata( photo, 'isVirtualCopy', rawMeta )
    local copyName
    local photoPathName
    local photoName
    local targ -- stays nil if vc
    if virt then
        copyName = photo:getFormattedMetadata( 'copyName' )
        photoName = str:fmt( "^1 (^2)", LrPathUtils.leafName( photoPath ), copyName )
        photoPathName = str:fmt( "^1 (^2)", photoPath, copyName )
    else
        copyName = 'not virtual copy' -- shouldnt be used.
        photoName = LrPathUtils.leafName( photoPath )
        photoPathName = photoPath
        if form == 'RAW' then
            targ = LrPathUtils.replaceExtension( photoPath, "xmp" )
        else -- includes DNG.
            targ = photoPath
        end
    end
    return form, photoPath, targ, photoName, photoPathName, copyName
end



--- Get locked and significantly changed photos.
--
--  @param      photos      starting photos.
--  @param      index       optional starting index.
--
--  @usage      photo at index (if > 0) included for free...
--
function Utils.getChangedPhotos( photos, index )

    local chgPhotos = {}
    
    if index and index > 0 then
        chgPhotos[1] = photos[index]
    else
        index = 0
    end
    
    local devSetExcl, rawMetaExcl, fmtMetaExcl = Utils.getExclusions()
    
    local rawMeta = cat:getBatchRawMetadata( photos, { 'path' } )
    for i = index + 1, #photos do
    
        local photo = photos[i]
        local photoPath = rawMeta[photo].path
    
        local changed, lockTimeFmt, editTimeRaw = Utils.isChanged( photo )
        if changed then
            local sigChanged, err, content = Utils.getChangeDetails( photo, devSetExcl, rawMetaExcl, fmtMetaExcl, editTimeRaw )
            if err then
                app:logError( err )
            elseif sigChanged then
                chgPhotos[#chgPhotos + 1] = photo
                app:logVerbose( "Got changed photo" )
            else
                app:logVerbose( "No changed photo" )
            end
        else
            app:logVerbose( "Not changed photo: " .. photoPath )
        end
    
    end
    
    return chgPhotos

end



--- Revert multiple photos.
--
--  @usage  The purpose of this function, is to revert a bunch of photos reliably and efficiently.
--          <br>one-by-one is reliable if pausing for the user inbetween, but is not reliable and is
--          <br>slow to do bunches that way.
--
--  @usage  If I ever have a bulk-revert menu item, then this would be ripe for moving there,
--          <br>but that hardly seems necessary since the Check function has it covered.
--
function Utils.multiRevert( photos, service, rawMeta )

    -- step 1: read metadata for all.
    if not photos or #photos == 0 then
        error( "check photos before calling multi-revert" )
    end
    
    if not service.nReverted then
        service.nReverted = 0
    end

    local s, m
    
    if #photos == 1 then
        local photo = photos[1]
        local photoPath = cat:getRawMetadata( photo, 'path', rawMeta )
            -- check in calling context to avoid this as an error
        local isVirt = cat:getRawMetadata( photo, 'isVirtualCopy', rawMeta )
        if not isVirt then
            -- will select just one photo as side-effect:
            local manualPrompt = "Reading Lightroom metadata, to revert photos."
            s, m = cat:readPhotoMetadata( photo, photoPath, false, service, manualPrompt ) -- false => library module has not been assured, so assure internally.
        else
            app:logError( "Calling context should filter single virtual copy from multi-revert." )
            s, m = false, "Virtual copy can not be reverted."
        end
    else
        s, m = cat:readMetadata( photos, true, false, false, service ) -- pre-select, but dont post restore photo selections, and assure grid mode internally.
    end
    
    if not s then
        return s, m
    end

    -- fall-through => catalog in sync with xmp - just need to adjust bookeeping (there's no snapshot then revert...)

    service.scope:setCaption( str:fmt( "Reverting ^1...", str:plural( #photos, 'photo', true ) ) )
    local rev = {}
    s, m = cat:update( 60, str:fmt( "Revert ", str:plural( #photos, "photo" ) ), function( context, phase )
        local i1 = ( phase - 1 ) * 1000 + 1
        local i2 = math.min( phase * 1000, #photos )
        for i = i1, i2 do
            local photo = photos[i]
            local isVirt = cat:getRawMetadata( photo, 'isVirtualCopy', rawMeta )
            if not isVirt then
                Utils.revertLockage( photo ) -- doesn't need raw-meta
                rev[#rev + 1] = photo
                service.nReverted = service.nReverted + 1
            else
                local path = cat:getRawMetadata( photo, 'path', rawMeta )
                local copyName = photo:getFormattedMetadata( 'copyName' )
                app:logWarning( "Virtual copies can not be automatically reverted - you'll have to do this one manually: ^1 (^2)", path, copyName )
            end
            if service:isQuit() then
                return true
            else
                service.scope:setPortionComplete( i, #photos )
            end
        end
        if i2 < #photos then
            return false
        end
    end )

    service.scope:setCaption( str:fmt( "Clearing change detect ^1...", str:plural( #photos, 'photo', true ) ) )
    if s then    
        for i, photo in ipairs( rev ) do
            Utils.revertLockage2( photo, rawMeta ) -- simply sets last-edit-time to reverted last-edit-time.
            service.scope:setPortionComplete( i, #photos )
        end
    end
    
    return s, m

end



--- Put multiple photos in change collection.
--
function Utils.multiCollect( photos, service )

    if not service.nCollected then
        service.nCollected = 0
    end
    service.scope:setCaption( str:fmt( "Adding ^1 to change collection", str:plural( #photos, 'photo', true ) ) )
    -- service.scope:setIndeterminate() - not appropriate unless modal progress scope.
    local done = false
    LrTasks.startAsyncTask( function()
        local n = #photos
        local i = math.floor( service.scope:getPortionComplete() * n )
        while not service.scope:isDone() and not service.scope:isCanceled() and not done do
            LrTasks.sleep( .1 )
            service.scope:setPortionComplete( i, n )
            i = i + 1
        end
        service.scope:setPortionComplete( n, n )
    end )
    local s, m = cat:update( 50, str:fmt( "Collect ", str:plural( #photos, "photo" ) ), function( context, phase )
        changeColl:addPhotos( photos ) -- requires full write access.
    end )
    done = true
    if s then
        service.nCollected = service.nCollected + #photos
    end
    return s, m

end



--- Lock multiple photos.
--
--  @usage      force locks everything irrespective of previous status.
--
function Utils.multiLock( photos, snapshotAndMarkParams, rawMeta )

    local service = snapshotAndMarkParams.call
    local snapshotFlag = snapshotAndMarkParams.snapshot
    local markFlag = snapshotAndMarkParams.mark

    if not service.nLocked then
        service.nLocked = 0
    end
    if #photos == 0 then
        return
    end
    
    local photos2
    
    --   S N A P S H O T S   &   M A R K S
    if snapshotFlag or markFlag then
        app:logInfo( str:fmt( "^1 under consideration for snapshot and/or mark...", str:nItems( #photos, "photos" ) ) )
        if snapshotFlag and markFlag then
            service.scope:setCaption( "Creating snapshots and marking..." )
        elseif snapshotFlag then            
            service.scope:setCaption( "Creating snapshots..." )
        else
            service.scope:setCaption( "Marking edit histories..." )
        end
        photos2 = {}
        local catStatus, catError = cat:update( 60, str:fmt( "Pre-lock snapshotting of ^1", str:nItems( #photos, "photos" ) ), function( context, phase ) -- snapshotting is done in bulk for efficiency.
            local i1 = ( phase - 1 ) * 1000 + 1
            local i2 = math.min( phase * 1000, #photos )
            for i = i1, i2 do
                local photo = photos[i]
                repeat
                    local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo, rawMeta )
                    if not form then -- video
                        app:logInfo( "Video file ignored: " .. photoPath )
                        break
                    end
                    local p = tab:addItems( { photo=photo, photoPath=photoPath }, snapshotAndMarkParams )
                    local s, m = LrTasks.pcall( snapshotAndMark.snapshotAndMarkPhoto, snapshotAndMark, p )
                    if s then
                        app:logVerbose( "snapshotted and/or marked " .. photoPath )
                        photos2[#photos2 + 1] = photo
                    else
                        app:logError( "No can snapshot and/or mark " .. photoPath .. ", err: " .. str:to( m ) )
                    end
                    if service:isQuit() or service.scope:isCanceled() then -- is quit if cancel, abort, or shutdown.
                        break
                    end
                until true
                if service:isQuit() then
                    return true
                else
                    service.scope:setPortionComplete( i, #photos )
                end
            end -- for loop
            if i2 < #photos then
                return false
            end
        end ) -- of catalog
        if not catStatus then
            error( str:to( catError ) )
        end
        if service:isQuit() or service.scope:isCanceled() then
            return -- done
        end
        photos = photos2 -- reuse passed photo array variable. 
    end -- snapshots
    
    if #photos == 0 then -- this added 30/Jul/2012 15:32, to avoid misleading messages like "0 photos are being locked"...
        app:logWarning( "No photos were locked - due to problems hopefully elaborated above." )
        -- service:abort( "No photos were locked." ) - not sure this is needed or helpful, or won't hurt anything, and calling context is prepared to deal appropriately with return values.
        return false, "No photos were locked."
    end

    --   L O C K A G E  ( m a k e   r e a d - o n l y   a n d   r e c o r d   s t a t e )
    app:logInfo( str:fmt( "Recording lockage of ^1...", str:plural( #photos, "photo" ) ) )
    service.scope:setCaption( str:fmt( "Recording lockage of ^1...", str:plural( #photos, "photo" ) ) )
    
    local skip, lockedLabel = Utils._checkLabel( photos, true ) -- for locking.
    if not skip then
        return false, "Lock canceled"
    end

    photos2 = {}

    -- Once upon a time, I could swear that locking a photo cleared metadata flag, however recording lockage of photo sets the flag.
    -- Perhaps it would be better to record lockage, then save metadata and make read-only. The downside is that lockage gets recorded,
    -- even if error finalizing lockage, on the other hand as long as an error is logged...
    local s, m = cat:update( 60, "Record Lockage of " .. str:plural( #photos, "photo" ), function( context, phase )
        local i1 = ( phase - 1 ) * 1000 + 1
        local i2 = math.min( phase * 1000, #photos )
        for i = i1, i2 do
            local photo = photos[i]
            repeat
                local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )

                local label
                if str:is( lockedLabel ) and not skip[photo] then
                    label = lockedLabel
                end
                local s, m = LrTasks.pcall( Utils.recordLockage, photo, label ) -- no reason to deny lockage to all just because of one error writing to catalog...
                
                if s then
                    app:logInfo( "Locked: " .. photoPathName )
                    service.nLocked = service.nLocked + 1
                    photos2[#photos2 + 1] = photo
                else
                    app:logError( str:fmt( "Unable to lock ^1 because ^2", photoPathName, m ) )
                end
                
            until true
            
            if service:isQuit()then
                return true
            else
                service.scope:setPortionComplete( i, #photos )
            end
            
        end -- photos
        
        if i2 < #photos then
            return false
        end
        
    end ) -- catalog

    photos = photos2
    photos2 = {}

    --   S A V E   M E T A D A T A
    if #photos == 1 then
        service.scope:setCaption( "Saving metadata (one photo)..." )
        local photo = photos[1]
        local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )
        if form then
            if targ then -- not video and not virtual
                repeat
                    local s, m = fso:makeReadWrite( targ )
                    if s then
                        app:logVerbose( "Made read-write ^1", photoPathName )
                    else
                        app:logErr( "Unable to lock ^1 because ^2", photoPathName, m )
                        break
                    end
                    
                    --Debug.pause( "should be read-write ###3" ) -- there was some problem for a while, @29/Dec/2012: don't remember details.
                    
                    s, m = cat:savePhotoMetadata( photo, photoPath, targ )
                    
                    --Debug.pause( "metadata should be saved ###3" )
                    
                    
                    if s then
                        app:logVerbose( "Saved metadata for photo ^1", photoPathName )
                        photos2[#photos2 + 1] = photo
                    else
                        app:logErr( "Unable to lock ^1 because ^2", photoPathName, m )
                        break
                    end

                    local s, m = fso:makeReadOnly( targ )
                    if s then
                        app:logVerbose( "Made ^1 read-only.", targ )
                    else
                        app:logErr( "Unable to lock ^1 because cant make xmp read-only, error message: ^2", photoPathName, m )
                        break
                    end
                    
                until true
            else
                photos2[#photos2 + 1] = photo
            end
        else
            app:logInfo( "Video file ignored: " .. photoPath )
        end
        
    elseif #photos > 1 then
        -- need to assure read-write
        service.scope:setCaption( str:fmt( "Making xmp writeable (^1)...", str:plural( #photos, "photo" ) ) )
        for i, photo in ipairs( photos ) do
            repeat
                local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )
                if not form then -- video
                    app:logInfo( "Video file ignored: " .. photoPath )
                    break
                end
                if targ then
                    local s, m = fso:makeReadWrite( targ )
                    if s then
                        app:logVerbose( "Made read-write ^1", photoPathName )
                    else
                        app:logErr( "Unable to lock ^1 because ^2", photoPathName, m )
                    end
                -- else virtual
                end
            until true
            service.scope:setPortionComplete( i, #photos )
        end
        
        -- save-metadata updates caption.
        local s, m = cat:saveMetadata( photos, true, false, false, service ) -- pre-select: true, restore-select: false, grid-mode already: false.
        if s then
            -- continue on and put up next caption.
        else
            service.scope:setCaption( str:fmt( "*** Error saving metadata..." ) ) -- not sure if this'll ever be seen but cheap insurance...
            return false, m
        end

        for i, photo in ipairs( photos ) do
            service.scope:setCaption( str:fmt( "Making xmp read-only (^1)...", str:plural( #photos, "photo" ) ) )
            repeat
                local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )
                if not form then -- video
                    app:logInfo( "Video file ignored: " .. photoPath )
                    break
                end
                if targ then
                    local s, m = fso:makeReadOnly( targ )
                    if s then
                        app:logVerbose( "Made read-only ^1", photoPathName )
                    else
                        app:logErr( "Unable to lock ^1 because ^2", photoPathName, m )
                    end
                -- else virtual
                end
                photos2[#photos2 + 1] = photo
            until true
            service.scope:setPortionComplete( i, #photos )
        end
        
    end
    
    photos = photos2 -- could just use photos2 directly as photos, but for consistency...
    photos2 = {}

    --   R E C O R D   E D I T   T I M E ,   P E R S I S T E N T L Y   (@25/Aug/2011 3:01)
    --   Note: this does not set edit flag, nor change edit-timestamp of photo.
    if s then
        service.scope:setCaption( str:fmt( "Finalizing lockage (^1)...", str:plural( #photos, "photo" ) ) )
        for i, photo in ipairs( photos ) do
            local s, m = LrTasks.pcall( cat.setPropertyForPlugin, cat, cat:getRawMetadata( photo, 'uuid', rawMeta ) .. "_lastEditTime", cat:getRawMetadata( photo, 'lastEditTime', rawMeta ), true ) -- true => validate.
            -- This throws error when validation flag is passed, if validation fails.
            if s then
                app:logv( "Final lock recording as catalog property succeeded." )
                photos2[#photos2 + 1] = photo -- write-only @12/Oct/2012 18:10.
            else
                app:logWarning( m ) -- probably should not return true status when this happens, although it never does happen, and warning is logged, and only ill-effect,
                -- is on performance: plugin may keep checking for changes when it shouldn't, but won't *otherwise* malfunction.
            end
        end
    end
    
    service.scope:setCaption( "" )
    
    return s, m
end



--- Unlock multiple photos
--
--  @usage      error wrap externally. catalog wrapped internally.
--  @usage      stats kept in service and error log.
--
--  @return     status      true iff successful.
--  @return     message     string iff unsuccessful.
--
function Utils.multiUnlock( photos, service )
    if not service.nUnlocked then
        service.nUnlocked = 0
        -- service.nNotLocked = 0
    end
    if #photos == 0 then
        return
    end
    
    local skip, lockedLabel = Utils._checkLabel( photos )
    if not skip then
        return false, "Unlock canceled"
    end
    
    service.scope:setCaption( str:fmt( "Unlocking ^1...", str:plural( #photos, "photo", true ) ) )

    local status, message = cat:update( 50, str:fmt( "Unlock ^1", str:plural( #photos, "Photo" ) ), function( context, phase )
        local i1 = ( phase - 1 ) * 1000 + 1
        local i2 = math.min( phase * 1000, #photos )
        for i = i1, i2 do
            local photo = photos[i]
            repeat
                local form, photoPath, targ, photoName, photoPathName, copyName = Utils.getPhotoInfo( photo )
                
                if not form then
                    app:logInfo( "Ignoring video: " .. photoPath )
                    break
                end
                
                local clearLabel
                if str:is( lockedLabel ) then
                    clearLabel = not skip[photo]
                end
                
                local s, m = Utils._unlockPhoto( photo, photoPath, targ, photoName, clearLabel )
                if s then
                    app:logInfo( "Unlocked photo: " .. photoPathName )
                    service.nUnlocked = service.nUnlocked + 1
                else
                    app:logError( "Unable to unlock photo, error message: " .. str:to( m ) )
                    break
                end
                
            until true
            if service:isQuit() then
                break
            else
                service.scope:setPortionComplete( i, #photos )
            end
        end -- end photos
        if i2 < #photos then
            return false
        end
    end )
    
    return status, message
    
end



--- Sets ending module base on preference.
--
--  @usage      Just logs error if any.
--
function Utils.restoreModule()
    local moduleNumber = app:getGlobalPref( 'devMode' )
    local s, m = gui:switchModule( moduleNumber )
    if not s then
        app:logErr( "Unable to go to module number: ^1, error message: ^2", str:to( moduleNumber ), str:to( m ) )
    end
end



function Utils.initGlobalSnapAndMarkPref()
    local pref = app:getGlobalPref( 'snapAndMark' )
    if pref ~= nil then
        return -- its already initialized.
    else
        -- initialize based on previous indies, and migrate permanently.
        local snap = app:getGlobalPref( 'snapshot' )
        local mark = app:getGlobalPref( 'mark' )
        if snap ~= nil and mark ~= nil then
            if snap and mark then
                app:setGlobalPref( 'snapAndMark', 'both' )
            elseif snap then
                app:setGlobalPref( 'snapAndMark', 'snap' )
            elseif mark then
                app:setGlobalPref( 'snapAndMark', 'mark' )
            else
                app:setGlobalPref( 'snapAndMark', 'neither' )
            end
        else
            app:setGlobalPref( 'snapAndMark', 'both' )
        end
        app:setGlobalPref( 'snapshot', nil )
        app:setGlobalPref( 'mark', nil )
    end
end



function Utils.isSnapshot()
    local pref = app:getGlobalPref( 'snapAndMark' )
    return pref == 'snap' or pref == 'both'
end



function Utils.isMark()
    local pref = app:getGlobalPref( 'snapAndMark' )
    return pref == 'mark' or pref == 'both'
end



function Utils.getSnapshotAndMarkView( labelWidth )

    local mainItems = { bind_to_object = prefs }
    local uiElems = snapshotAndMark:getUiElements() -- reminder: sets style-name pref to something useful, so no need to otherwise init.
       
    mainItems[#mainItems + 1] = 
        vf:row {
            vf:static_text {
                title = str:fmt( "Snapshot && Mark Options\n(these only apply when locking)" ), -- actually, in this case, both may be deselected.
                width =  labelWidth,
            },
            vf:radio_button {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'snapAndMark' ),
                checked_value = 'snap',
                title = 'Snapshot',
                tooltip = "check this box to take a lock-state snapshot",
            },
            vf:radio_button {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'snapAndMark' ),
                title = 'Mark',
                checked_value = 'mark',
                tooltip = "check this box to make a lock-state mark in the edit history",
            },
            vf:radio_button {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'snapAndMark' ),
                title = 'Both',
                checked_value = 'both',
                tooltip = "check this box to take snapshot and mark in edit history",
            },
            vf:radio_button {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'snapAndMark' ),
                title = 'Neither',
                checked_value = 'neither',
                tooltip = "check this box to not snapshot nor mark in edit history",
            },
            vf:spacer { width=10 },
            vf:checkbox {
                title = "Auto-republish",
                value = app:getGlobalPrefBinding( 'autoPublish' ),
                tooltip = "If checked, target photos that are marked for republishing, will be re-published, unless service is excluded via 'Advanced Settings' (see Plugin Manager)",
            },
        }
    mainItems[#mainItems + 1] = vf:spacer{ height = 5 }
    mainItems[#mainItems + 1] = 
        vf:row {
            vf:static_text {
                title = str:fmt( "Snapshot && Mark Styles" ),
                width =  labelWidth,
            },
            vf:combo_box {
                bind_to_object = prefs,
                items = uiElems.comboBoxItems,
                value = app:getGlobalPrefBinding( 'styleName' ), -- reminder: no need to init this gbl pref.
                enabled = LrView.bind {
                    keys = { app:getGlobalPrefKey( 'snapAndMark' ) },
                    operation = function( binder, value, toView )
                        local snapshot = Utils.isSnapshot()
                        local mark = Utils.isMark()
                        if mark or snapshot then
                            return true
                        else
                            return false
                        end
                    end,
                },
                fill_horizontal = 1,
            },
        }
    mainItems[#mainItems + 1] = vf:spacer{ height = 5 }
    mainItems[#mainItems + 1] = 
        vf:row {
            vf:static_text {
                width =  labelWidth,
                title = str:fmt( "Additional Notes" ),
            },
            vf:edit_field {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'snapshotText' ),
                enabled = LrView.bind {
                    keys = { app:getGlobalPrefKey( 'snapAndMark' ) },
                    operation = function( binder, value, toView )
                        local snapshot = Utils.isSnapshot()
                        local mark = Utils.isMark()
                        if mark or snapshot then
                            return true
                        else
                            return false
                        end
                    end,
                },
                width_in_chars = 30,
                height_in_lines = 3,
            },
        }
    mainItems[#mainItems + 1] = vf:spacer{ height = 5 }
    mainItems[#mainItems + 1] = 
        vf:row {
            vf:static_text {
                title = str:fmt( "History Prefix for Snapshot" ),
                width =  labelWidth,
            },
            vf:edit_field {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'historyPrefixForSnapshot' ),
                enabled = uiElems.historyPrefixForSnapshotEnableBinding,
                width_in_chars = 20,
            },
        }
    mainItems[#mainItems + 1] = 
        vf:row {
            vf:static_text {
                title = str:fmt( "History Prefix for Mark" ),
                width =  labelWidth,
            },
            vf:edit_field {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'historyPrefixForMark' ),
                enabled = uiElems.historyPrefixForMarkEnableBinding,
                width_in_chars = 20,
            },
        }
    return vf:column( mainItems ) -- same as a default vf:view
end


return Utils
