--[[
        AutotoneAndCompare.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local AutotoneAndCompare = {}


local dbg, dbgf = Object.getDebugFunction( 'AutotoneAndCompare' )


--- menu item handler
--
function AutotoneAndCompare.main()

    app:call( Service:new{ name="Autotone and Compare", async=true, guard=App.guardVocal, main=function( call ) 
    
        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to abide, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photo = catalog:getTargetPhoto()
        if not photo then
            app:show( { warning="Select photo first." } )
            return
        end

        local raw1 = photo:getRawMetadata()
        if raw1.fileFormat == 'VIDEO' then
            app:show{ warning="^1 not supported for video.", call.name }
            return
        end
        local dev1 = photo:getDevelopSettings()
        if dev1.ProcessVersion == '6.6' or dev1.ProcessVersion == '6.7' then
            -- good
        else
            app:show{ warning="Only works when PV2012 photo is most selected." }
            call:cancel()
            return
        end        
        local fmt1 = photo:getFormattedMetadata()
        
        local btn = app:show{ info="^1\n \nAuto-tone and compare?",
            subs = raw1.path,
            actionPrefKey = str:fmtx( "^1 confirmation", call.name ),
        }
        if btn == 'cancel' then
            call:cancel()
            return
        end
        app:log( raw1.path )
        
        local s, m = devSettings:adjustPhotos( { photo }, "Auto Tone", { AutoTone=true } )
        local dev2
        if s then
            local count = 0
            app:log( "Auto-tone'd" )
            repeat
                app:sleep( .2 ) -- typically takes from .1 to 2 seconds, total, so 1/5 second polling interval seems reasonable.
                dev2 = photo:getDevelopSettings()
                if dev2.Blacks2012 > -100 then
                    dbgf( "Settled after ^1 re-checks.", count )
                    break
                else -- Lr dev settings are "busy"
                    count = count + 1
                    if count == 100 then -- ten seconds => give up.
                        call:abort( "Auto-tone not settling." )
                        return
                    end
                end
            until false
        else
            app:logError( m )
            return
        end
        
        local raw2 = raw1
        local fmt2 = fmt1
        
        local ui = not app:getPref( 'bypassCompareDisp' )
        if ui then
            app:logVerbose( "Displaying UI" )
        else
            app:logVerbose( "Bypassing UI display, due to user preference." )
        end
        
        Compare.compare( call, photo, photo, dev1, dev2, Utils.devSetExcl, raw1, raw2, '*', fmt1, fmt2, '*', ui )

    
    end, finale = function( call )

        background:continue()
    
    end } )    
    
end



return AutotoneAndCompare.main()
