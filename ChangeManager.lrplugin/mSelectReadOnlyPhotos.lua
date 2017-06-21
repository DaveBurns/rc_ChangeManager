app:call( Service:new{ name="Select Read-Only Photos", async=true, progress={ caption="Dialog box needs your attention..." }, main=function( call )
    local photos = catalog:getMultipleSelectedOrAllPhotos()
    if #photos == 0 then
        app:show{ warning="No photos." }
        call:cancel()
        return
    end
    local button = app:show{ confirm="Assess read-only attributes within ^1",
        subs = { str:nItems( #photos, "photos" ) },
        actionPrefKey = "proceed to assess",
    }
    if button == 'cancel' then
        call:cancel()
        return
    end
    call:initStats{ 'photoRo', 'xmpRo', 'totalPhotos', 'missing' }
    local function assess( file )
        -- local ro = fso:isReadOnly( photoPath ) -- obsolete/deprecated.
        local readable = LrFileUtils.isReadable( file )
        local writable = LrFileUtils.isWritable( file )
        if readable then
            if not writable then -- read-only
                app:log( "Read-only: ^1", file )
                -- photosRo[#photosRo + 1] = photo
                return true
            else
                app:log( "Read-write: ^1", file )
            end
        else
            app:log( "Not readable: ^1", file )
        end      
    end
    call:setCaption( "Working..." )
    local cache = lrMeta:createCache{ photos=photos, rawIds={ 'path', 'fileFormat', 'isVirtualCopy' }, fmtIds={ 'copyName' } }
    local photosRo = {}
    for i, photo in ipairs( photos ) do
        call:setPortionComplete( i - 1, #photos )
        repeat
            local photoPath = cache:getRawMetadata( photo, 'path' )
            local photoName = cat:getPhotoNameDisp( photo, true, cache ) -- true => full-path
            local virt = cache:getRawMetadata( photo, 'isVirtualCopy' )
            app:log( "Considering ^1", photoName )
            call:incrStat( 'totalPhotos' )
            if virt then
                app:logv( "Ignoring virtual copy" )
                break
            end
            if fso:existsAsFile( photoPath ) then
                -- local ro = fso:isReadOnly( photoPath ) -- obsolete/deprecated.
                local photoRo = assess( photoPath )
                if photoRo then
                    photosRo[#photosRo + 1] = photo
                    call:incrStat( 'photoRo' )
                end
                local xmp = xmpo:getXmpFile( photo, cache )
                if xmp == photo then
                    -- nada
                else
                    local xmpRo = assess( xmp )
                    if xmpRo then
                        call:incrStat( 'xmpRo' )
                    end
                end
            else
                call:logWarning( "Missing: ^1", photoPath )
                call:incrStat( 'missing' )
            end
        until true
        if call:isQuit() then
            return
        end
    end
    call:setPortionComplete( 1 ) -- all
    if #photosRo > 0 then
        local s, m = cat:selectPhotos( nil, photosRo, true, cache )
        if s then
            app:show{ info="Read-only photos should be selected now.", actionPrefKey="Read-only photos are selected" }
        else
            app:logErr( "Unable to select read-only photos - ^1", m )
        end
    else
        local b = app:show{ info="None of ^1 are read-only.",
            subs={ str:nItems( #photos, "considered photos" ) },
            actionPrefKey="None read-only"
        }
        if b == 'cancel' then
            call:cancel()
        end
    end

end, finale=function( call )
    
    app:log()
    app:log( "^1 considered", str:nItems( call:getStat( 'totalPhotos' ), "total photos" ) )
    app:log( "^1", str:nItems( call:getStat( 'photoRo' ), "read-only photo files" ) )
    app:logStat( "^1", call:getStat( 'xmpRo' ), "read-only sidecars" )
    app:logStat( "^1", call:getStat( 'missing' ), "missing photo source files" )
    app:log()

end } )
