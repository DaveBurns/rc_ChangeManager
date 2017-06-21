--[[
        SnapshotAndMark.lua
        
        *** Dependencies:
        
            - 'namedStyles' must be the name for the named styles in pref file backer.
            - 
--]]


local SnapshotAndMark, dbg, dbgf = Object:newClass{ className = 'SnapshotAndMark', register=true }



--- Constructor for extending class.
--
function SnapshotAndMark:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function SnapshotAndMark:new( t )
    local o = Object.new( self, t )
    return o
end



--  returns snapshot history text enable binding.
function SnapshotAndMark:_getHistoryPrefixForSnapshotEnableBinding()
    return LrView.bind{ 
        keys = { app:getGlobalPrefKey( 'snapAndMark' ) },
        operation = function( binder, value, toView )
            local snapshot = Utils.isSnapshot()
            local mark = Utils.isMark()
            if snapshot and mark then
                return true
            else
                return false
            end
        end }
end



-- returns mark checkbox enable binding.
function SnapshotAndMark:_getHistoryPrefixForMarkEnableBinding()
    return LrView.bind{
        keys = { app:getGlobalPrefKey( 'snapAndMark' ) },
        operation = function( binder, value, toView )
            local snapshot = Utils.isSnapshot()
            local mark = Utils.isMark()
            if mark and not snapshot then
                return true
            else
                return false
            end
        end }
end



--- Get combo-box items and associated lookup for defined styles.
--
--  @usage      has side-effect of registering change handlers for snapshot and mark prefs, <br>
--              which keeps them from both being de-selected.
--
--  @return table containing: <br>
--  - comboBoxItems (array of strings) first item will not have a lookup if the items would have otherwise been empty) <br>
--  - comboBoxLookup (table) keys are item elements, values are named-styles <br>
--  - historyPrefixForSnapshotEnableBinding (binding for enable view property) <br>
--  - historyPrefixForMarkEnableBinding (binding for enable view property) <br>
--
function SnapshotAndMark:getUiElements()
    local namedStyles = app:getPref( 'namedStyles' )
    local items = {}
    local lookup = {}
    for i, v in ipairs( namedStyles ) do
        if type( v ) == 'table' then
            if str:is( v.styleName ) then
                items[#items + 1] = v.styleName
                lookup[v.styleName] = v
            else
                app:logError( "styleName must be a text string" )
            end
        else
            app:logError( "named style must be a table, enclosed by '{' and '}'" )
        end
    end
    if #items == 0 then
        items[1] = "Configure styles by editing advanced settings in plugin manager."
        app:setGlobalPref( 'styleName', "" )
    else
        local prev = app:getGlobalPref( 'styleName' )
        if not lookup[prev] then
            app:setGlobalPref( 'styleName', items[1] )
        end
    end
    local _r = { comboBoxItems=items, comboBoxLookup=lookup, historyPrefixForSnapshotEnableBinding=self:_getHistoryPrefixForSnapshotEnableBinding(), historyPrefixForMarkEnableBinding=self:_getHistoryPrefixForMarkEnableBinding() }
    return _r
end



--- Snapshot & mark one photo.
--
--  @param          namedParams (table, required) parameter members:<br>
--                      - photo (lr-photo, required)<br>
--                      - photoPath (string, required)<br>
--                      - style ( table, default=nil ) style if not style-name or plain name<br>
--                      - styleName ( string, default = nil) style name if not other.<br>
--                      - name (string, default = nil) name text if no other.<br>
--                      - historyPrefixForSnapshot( string, default = nil ) required if not style and snapshot+mark.<br>
--                      - historyPrefixForMark( string, default = nil ) required if not style and just marking.<br>
--                      - snapshot (boolean, default = false) snapshot and/or mark must be true<br>
--                      - mark (boolean, default = false) snapshot and/or mark must be true<br>
--                      - call( object, required ) call object wrapping
--                      - extraMarks( table, optional ) for extra mark style-names, or styles, or plain names (only tested with style-names).
-- 
--  @usage          namedStyles local pref must have names to support style-name parameter.
--  @usage          must be wrapped externally for catalog access and error handling.
--
function SnapshotAndMark:snapshotAndMarkPhoto( namedParams )

    local photo = namedParams.photo
    local photoPath = namedParams.photoPath
    local rawMeta = namedParams.rawMeta -- if passed, include "everything".
    local fmtMeta = namedParams.fmtMeta -- ditto
    local devSettings = namedParams.devSettings
    local style = namedParams.style
    local styleName = namedParams.styleName
    local historyPrefixForSnapshot = namedParams.historyPrefixForSnapshot
    local historyPrefixForMark = namedParams.historyPrefixForMark
    local name = namedParams.name or ""
    local snapshot = namedParams.snapshot
    local mark = namedParams.mark
    local call = namedParams.call -- not used yet, but could be at some point.
    local extraMarks -- initialized after main-style.

    if not snapshot and not mark then
        app:logVerbose( "*** Neither snapshot nor mark specified, doing neither..." )
        return
    end
    
    assert( photo ~= nil, "need photo" )
    assert( photoPath ~= nil, "need photo-path" )

    local custMetaLookup = {}
    local filename
    local time
    local timeFmt
    local mainStyle
    local mainHistoryPrefix
    local namedStyles
    local markSeqNo = 1

    -- local functions

    local function getStyleAndHistoryPrefix( _styleName, _snapshot, _mark )
        local _style
        local _historyPrefix
        if not namedStyles then
            namedStyles = app:getPref( 'namedStyles' )
        end
        if namedStyles then
            for i, v in ipairs( namedStyles ) do
                if v.styleName == _styleName then
                    _style = v -- convert name to style
                    break
                end
            end
        else
            error( "no named styles" )
        end
        if not _style then
            error( "Style not found: " .. str:to( _styleName ) )
        end
        assert( _style ~= nil, "no style" )
        if _snapshot and _mark then
            _historyPrefix = _style.historyPrefixForSnapshot
        elseif _snapshot then
            _historyPrefix = ""
        elseif _mark then
            _historyPrefix = _style.historyPrefixForMark
        else
            error( "no operation specified" )
        end
        return _style, _historyPrefix
    end
    
    local function getSub( v )
        local sub
        if v.type == 'raw' then -- hopefully not so many that onezies is significantly slower.
            if v.name then
                sub = cat:getRawMetadata( photo, v.name, rawMeta )
            else
                error( "raw metadata items must be specified by name" )
            end
        elseif v.type == 'formatted' then -- hopefully not so many that onezies is significantly slower.
            if v.name then
                sub = cat:getFormattedMetadata( photo, v.name, fmtMeta )
            else
                error( "formatted metadata items must be specified by name" )
            end
        elseif v.type == 'devsettings' then
            if devSettings == nil then -- init first use.
                devSettings = photo:getDevelopSettings()
            end
            if v.name then
                sub = devSettings[v.name]
            else
                sub = devSettings
            end
        elseif v.type ~= nil then
            if v.name then
                --[[ commented out 21/Nov/2011 in favor of more optimized version (see below).
                if customMetadata==nil then -- initialize upon first use.
                    customMetadata = photo:getRawMetadata( 'customMetadata' )
                end
                if customMetadata then
                    for i2, v2 in ipairs( customMetadata ) do
                        if v.name == v2.id then
                            if v.type == v2.sourcePlugin then
                                sub = v2.value
                                break
                            end
                        end
                    end
                end
                --]]
                -- ###1 - test this:
                if custMetaLookup[v.pluginId] == nil then
                    custMetaLookup[v.pluginId] = custMeta:getMetadata( photo, v.pluginId, rawMeta ) -- custom metadata for specified this plugin only, this photo only.
                end
                if custMetaLookup[v.pluginId] then
                    for id, value in pairs( custMetaLookup[v.pluginId] ) do
                        if v.name == id then
                            sub = value
                            break -- break statement added 5/Sep/2013 9:22 for v5.10.4 release, seems to have been missing.
                        end
                    end
                end
                if sub == nil then
                    app:logVerbose( "no plugin metadata for ^1 from ^2", str:to( v.name ), str:to( v.pluginId ) )
                end
            else
                error( str:fmt( "type (^1) assumed to be custom metadata must accompanied by name", str:to( v.type ) ) )
            end
        else
            error( "variable type required" )
        end
        if sub == nil then -- this happens regularly, when metadata item is missing - don't trip.
            sub = "" -- otherwise, variables will be missing from the parameter list.
        end
        return sub
    end

    -- compute name prefix from style, name, and photo metadata and settings.
    local function getNamePrefix( _style )
        if _style then
            -- step 0: handle possibly wonky style members.
            local locFormatString = _style.locFormatString
            if locFormatString == nil then
                app:logVerbose( "locFormatString is nil, are you sure that's what you want?" )
                return ""
            end
            if locFormatString == "" then
                app:logVerbose( "locFormatString is blank - returning blank name prefix" )
                return ""
            end
            if type( locFormatString ) ~= 'string' then -- locFormatString could conceivably be an intelligent object computed based on god knows what (checking for availbility of certain plugins?).
                if type( locFormatString ) == 'table' and locFormatString.toString ~= nil and type( locFormatString.toString ) == 'function' then
                    app:logVerbose( "locFormatString is not a string - converting it to one..." )
                    locFormatString = locFormatString:toString()
                else
                    error( "locFormatString must be string or have a toString method" )
                end
            end                
            local subs = { }
            if _style.substitutions == nil then
                app:logVerbose( "style has no substitutions - returning locFormatString verbatim" ) -- somebody could conceivably define a style with no substitutions, just for a selecteable canned name.
                return locFormatString
            end
            if type( _style.substitutions ) ~= 'table' then
                error( "substitutions must be a table (enclosed by '{' and '}')" )
            end
            for i, v in ipairs( _style.substitutions ) do
                if type( v ) ~= 'table' then
                    error( "style substitutions must be tables, enclosed by '{' and '}'" )
                end
                local sub = {}
                if v.variables then -- variables for tranformation function
                    assert( type( v.variables ) == 'table', "variables not table" )
                    local vars = {}
                    for i2, v2 in ipairs( v.variables ) do
                        vars[#vars + 1] = getSub( v2 )
                    end
                    assert( v.transform ~= nil, "need transform function" )
                    assert( #vars == #v.variables, "variable is missing" )
                    sub[1], sub[2], sub[3], sub[4], sub[5], sub[6], sub[7], sub[8], sub[9], sub[10] = v.transform( { photo=photo, time=time, customText=name }, unpack( vars ) )
                elseif v.transform then -- transformation without variables is perfectly legal
                    sub[1], sub[2], sub[3], sub[4], sub[5], sub[6], sub[7], sub[8], sub[9], sub[10] = v.transform( { photo=photo, time=time, customText=name } )
                else
                    sub[1] = getSub( v )
                end
                if sub ~= nil then
                    -- dbg( "got sub", sub, "for", v.name )
                    for j, var in ipairs( sub ) do
                        subs[#subs + 1] = var
                    end
                else
                    -- dbg( "no got", v.name )
                    subs[#subs + 1] = "" -- keeps from displaying ^1, ^2, ... in the snap-shot and/or mark.
                end
            end
            --app:show( locFormatString, unpack( subs ) )
            local ret = str:fmt( locFormatString, unpack( subs ) )
            if not _style.letMeHandleTime then
                ret = ret .. " " -- default is not to have space
            end
            return ret
        else
            if str:is( name ) then
                return name .. " "
            else
                return ""
            end
        end
    end    

    local function getPresetName( _style, _pfx )
        local _presetName
        if _style then
            if _style and _style.letMeHandleTime then
                _presetName = _pfx -- includes time if user wanted it.
            else
                _presetName = str:fmt( "^1^2", _pfx, timeFmt )
            end
        else
           _presetName = str:fmt( "^1^2", _pfx, timeFmt )
        end
        return _presetName
    end
    
    -- depends on presetName
    local function markEditHistory( _presetName, _ehPfx )
        if _ehPfx then
            _presetName = _ehPfx .. _presetName
        end
        local wrapWidth = app:getPref( 'wrapWidth' )
        assert( wrapWidth ~= nil, "why no wrap-width?" )
        wrapWidth = tonumber( wrapWidth )
        if wrapWidth < 20 then
            wrapWidth = 20 -- set to something sane.
        end
        if wrapWidth > 120 then
            wrapWidth = 120 -- set to something sane.
        end
        local wrappedComment = dia:autoWrap( _presetName, wrapWidth )
        local buf = str:split( wrappedComment, "\n" )
        for i = #buf, 1, -1 do
            local v = buf[i]
            local markSettings = { [str:fmt("NoEdit^1",markSeqNo)]=true }
            markSeqNo = markSeqNo + 1
            -- dbg( "markSeqNo", markSeqNo )
            local preset = LrApplication.addDevelopPresetForPlugin( _PLUGIN, v, markSettings )
            if not preset then
                error( "Unable to create preset" )
            end
            photo:applyDevelopPreset( preset, _PLUGIN ) -- timestamped.
            app:logVerbose( "Marked edit history of ^1 with ^2", photoPath, v )
        end
    end

    -- end of local functions

    -- compute main-style, & main-history-prefix:
    if style then
        if str:is( historyPrefixForSnapshot ) or str:is( historyPrefixForMark )  then
            app:logVerbose( "history prefixes are generally defined by style - being overridden by named parameter." )
        end    
        if type( style ) == 'table' then
            mainStyle = style
            -- no style, just name.
            if snapshot and mark then
                mainHistoryPrefix = historyPrefixForSnapshot or mainStyle.historyPrefixForSnapshot
            elseif snapshot then
                mainHistoryPrefix = ""
            elseif mark then
                mainHistoryPrefix = historyPrefixForSnapshot or mainStyle.historyPrefixForMark
            else
                error( "no operation specified" )
            end
        else
            error( "style must be table" )
        end
    elseif str:is( styleName ) then -- presume style-spec is style-name
        mainStyle, mainHistoryPrefix = getStyleAndHistoryPrefix( styleName, snapshot, mark )        
        app:logVerbose( "Main style: ^1", str:to( mainStyle.styleName ) )
    else
        -- no style, just name.
        app:logVerbose( "Main name: ^1", str:to( name ) )
        if snapshot and mark then
            mainHistoryPrefix = historyPrefixForSnapshot
        elseif snapshot then
            mainHistoryPrefix = ""
        elseif mark then
            mainHistoryPrefix = historyPrefixForMark
        else
            error( "no operation specified" )
        end
    end

    if mainStyle then
        extraMarks = tab:mergeArrays( mainStyle.extraMarks, namedParams.extraMarks ) -- handles nil params fine, excludes duplicates.
    else
        extraMarks = namedParams.extraMarks
    end
    time = LrDate.currentTime()
    timeFmt = LrDate.timeToUserFormat( time, "%Y-%m-%d %H:%M:%S" )
    filename = LrPathUtils.leafName( photoPath )
    local mainPfx = getNamePrefix( mainStyle ) -- if main-style nil just returns name followed by space.
    assert( mainPfx ~= nil, "no main pfx" )
    local mainPresetName = getPresetName( mainStyle, mainPfx )
    assert( mainPresetName ~= nil, "no main preset name" )
    local snapshotName = mainPresetName
    if snapshot then
        photo:createDevelopSnapshot( snapshotName, false ) -- new preset same name as mark.
        app:logVerbose( "Snapshotted ^1 with ^2", photoPath, snapshotName )
    end
    if extraMarks ~= nil and #extraMarks > 0 then
        for i2 = #extraMarks, 1, -1 do
            local style, ehPfx = getStyleAndHistoryPrefix( extraMarks[i2], false, true )
            local pfx = getNamePrefix( style )
            local presetName = getPresetName( style, pfx )
            -- app:show( "extra marking ^1: ^2", presetName, ehPfx )
            markEditHistory( presetName, ehPfx )
        end
    end
    if mark then
        -- app:show( "main marking ^1: ^2", mainPresetName, mainHistoryPrefix )
        markEditHistory( mainPresetName, mainHistoryPrefix )
    end
end



return SnapshotAndMark