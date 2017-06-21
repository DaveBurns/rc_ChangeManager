--[[
        ComparePhotos.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local ComparePhotos = {}


local dbg, dbgf = Object.getDebugFunction( 'ComparePhotos' )


--- menu item handler
--
function ComparePhotos.main()

    app:call( Service:new{ name="Compare Selected Photos", async=true, guard=App.guardVocal, main=function( call ) 
    
        local s, m = background:pause()
        if not s then
            app:logError( "Unable to pause background task, error message: ^1", m )
            call:abort( "Unable to pause background task." )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photo1 = catalog:getTargetPhoto()
        if not photo1 then
            app:show( { warning="Select photo first." } )
            call:cancel()
            return
        end
        local _photos = catalog:getTargetPhotos()
        local photos = {}
        if #_photos < 2 then
            app:show{ warning="Select 2 or more photos to compare." }
            call:cancel()
            return
        else
            for i, photo in ipairs( _photos ) do
                if photo ~= photo1 then
                    photos[#photos + 1] = photo
                end
            end
        end

        local raw1 = photo1:getRawMetadata()
        if raw1.fileFormat == 'VIDEO' then
            app:show{ warning="^1 not supported for video.", call.name }
            return
        end
        local dev1 = photo1:getDevelopSettings()        
        local fmt1 = photo1:getFormattedMetadata()

        local btn = app:show{ info="^1\n \nCompare ^1 to ^2?",
            subs = { str:nItems( #photos, "other photos" ), raw1.path },
            actionPrefKey = str:fmtx( "^1 confirmation", call.name ),
        }
        if btn == 'cancel' then
            call:cancel()
            return
        end

        local ui
        if #photos == 1 then -- one *other* photo.
            ui = not app:getPref( 'bypassCompareDisp' )
        else
            ui = false
        end
        if ui then
            app:logVerbose( "Displaying UI" )
        else
            app:logVerbose( "Bypassing UI display, due to user preference." )
        end
            
        app:log("\n")    
        --app:log( raw1.path )
        app:log( cat:getPhotoNameDisp( photo1, true ) )
        app:log()    
            
        for i, photo in ipairs( photos ) do
        
            local photo2 = photos[i]
    
            local dev2 = photo2:getDevelopSettings()
            local raw2 = photo2:getRawMetadata()
            local fmt2 = photo2:getFormattedMetadata()
            
            --app:log( raw2.path )
            app:log( cat:getPhotoNameDisp( photo2, true ) )
            
            Compare.compare( call, photo1, photo2, dev1, dev2, Utils.devSetExcl, raw1, raw2, Utils.rawMetaExcl, fmt1, fmt2, Utils.fmtMetaExcl, ui )
            app:log()
        end
        
        app:log()
        app:log( "^1 compared.", str:nItems( #photos, "photos" ) )
    
    end, finale = function( call )

        background:continue()
    
    end } )    
    
end



return ComparePhotos.main()
