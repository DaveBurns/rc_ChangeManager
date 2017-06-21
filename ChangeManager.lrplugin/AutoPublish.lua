--[[
        AutoPublish.lua
        
        Table of auto-publish functions.
        
        This can be upgraded to be a class if you prefer methods to static functions.
        Its generally not necessary though unless you plan to extend it, or create more
        than one...
--]]


local AutoPublish = {}



local dbg = Object.getDebugFunction( 'AutoPublish' )


local _ps = {} -- index is photo, lookup value is array of tables containing published photo and associated publish service.
local _done = {} -- table of photos for each publish service, that have been done.
local _todo = {} -- table of exports to initiate.
local _pubSrvs = PublishServices:new()



function AutoPublish._recomputeLookup( call )
    local pubPhotos, pubServices = _pubSrvs:getPublishedPhotos( 0 ) -- get all photos from all publish services in Lightroom.
    _ps = {}
    for i, pp in ipairs( pubPhotos ) do
        local p = pp:getPhoto()
        if _ps[p] == nil then
            _ps[p] = { { pp, pubServices[i] } }
        else
            local a = _ps[p]
            a[#a + 1] = { pp, pubServices[i] }
        end
    end
end


function AutoPublish._autoPublish( ppTbl, photo, call, rawMeta )
    for i, pt in ipairs( ppTbl ) do
        repeat
            local pp = pt[1]
            local ps = pt[2]
            
            -- Debug.pause( ps:getName() )
            
            if _done[pp] then
                -- error
                error( "already done" )
            end
    
            local exclusions = app:getPref( 'autoPubExcl' )
            local inclusions = app:getPref( 'autoPubIncl' )
            local include
            local exclude
            local name = ps:getName()
            if not tab:isEmpty( inclusions ) then
                include = false
                for i, v in ipairs( inclusions ) do
                    if name:find( v, 1, true ) then
                        include = true
                        app:logVerbose( "Inclusion of '^1' based on '^2'", name, v )
                        break
                    else
                        app:logVerbose( "Not including ^1 because of ^2", name, v )
                    end
                end
            else
                include = true
            end
            if not tab:isEmpty( exclusions ) then
                exclude = false
                for i, v in ipairs( exclusions ) do
                    if name:find( v, 1, true ) then
                        exclude = true
                        app:logVerbose( "Exclusion of '^1' based on '^2'", name, v )
                        break
                    else
                        app:logVerbose( "Not excluding ^1 because of ^2", name, v )
                    end
                end
            else
                exclude = false
            end
            if include and not exclude then
                _done[pp] = true -- a little premature, but hey...
            else
                -- do not set done flag if not auto-published.
                break
            end
            
            if _todo[ps] then
                -- add photo.
                local photos = _todo[ps].photosToExport
                photos[#photos + 1] = photo
            else
                local ep = ps:getPublishSettings()['< contents >']
                assert( ep, "no ep" )
                ep.LR_exportServiceProvider = ps:getPluginId() -- critical...
                ep.LR_exportServiceProviderTitle = "Auto-publishing export liason..." -- write-only.
                ep.LR_exportServiceProviderUrl = "http://www.robcole.com/ProductsAndServices/" -- ditto.
                _todo[ps] = { photosToExport = { photo }, exportSettings = ep }
            end
        until true
    end
        
end


-- initiate accumulated exports
function AutoPublish._export()
    --Debug.lognpp( _todo )
    for ps, sesn in pairs( _todo ) do
        local session = LrExportSession( sesn )
        session:doExportOnNewTask() -- try to get through this method before user has a chance to issue another round of exports, since there is no throttling - it's a race...
        --Debug.logn( "Session export task started." )
    end
    local s, m = cat:update( 20, "Auto-publish - mark as up-to-date", function( context, phase )
        for pp, _ in pairs( _done ) do
            pp:setEditedFlag( false )
        end
    end )
    if s then
        app:log( "Auto-publish marked all as up-to-date." )
    else
        error( m )
    end
    --Debug.showLogFile()
end



-- initiate exporting of specified photos via their publish service settings (only works if publish-service supports ordinary exporting too, I assume).
-- raw-meta: 'uuid', 'path', 'lastEditTime', 'fileFormat', 'isVirtualCopy'.
function AutoPublish.autoPublish( photos, rawMeta, service )
    local s, m = app:call( Call:new{ name="Auto-Publish", async=true, main=function( call ) -- asynchronous, so locking is considered complete even before exports are finished.
        local recomp = false
        _done = {} -- none done.
        _todo = {}
        for i, photo in ipairs( photos ) do
            local ppTbl = _ps[photo]
            if not ppTbl then
                if not recomp then
                    AutoPublish._recomputeLookup( call )
                    recomp = true
                    ppTbl = _ps[photo]
                else
                    -- skip photo
                end
            end
            if ppTbl then
                AutoPublish._autoPublish( ppTbl, photo, call, rawMeta )
            else
                -- skipped
            end
        end
        if not tab:isEmpty( _todo ) then
            AutoPublish._export()
        else
            app:log( "Nothing to export for auto-publish." )
        end
    end, finale=function( call )
        if call.status then
            app:logv( "Auto-publishing service completed without any uncaught errors." )
            app:show{ info="Recently locked photos are being auto-published and marked as up-to-date, at your request. If there is an error in the publishing task/plugin, you may need to re-mark/re-publish.",
                actionPrefKey = "Auto-publish consideration",
            }
        else
            app:show{ info="There was an error auto-publishing recently locked photos: ^1\n\nYou may need to re-mark/re-publish them.", str:to( call.message ) }
        end
    end } )
    if s then -- reminder: auto-publish service is asynchronous, so status here is pretty-much always 'true'.
        app:log( "Auto-publish started." )
    else
        app:logError( "Auto-publish not started: ^1", m )
    end
end



return AutoPublish
