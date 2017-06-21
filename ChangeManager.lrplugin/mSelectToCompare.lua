--[[
        SelectToCompare.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local SelectToCompare = {}


local dbg = Object.getDebugFunction( 'SelectToCompare' )


--- menu item handler
--
function SelectToCompare.main()

    app:call( Call:new{ name="SelectToCompare", async=true, progress=true, guard=App.guardVocal, main=function( call )
    
        local s, m = background:pause()
        if not s then
            call:setCaption( "Dialog box needs your attention..." )
            app:show( { error="Unable to select for compare, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local photo = catalog:getTargetPhoto()
        if not photo then
            call:setCaption( "Dialog box needs your attention..." )
            app:show( { warning="Select photo to compare." } )
            return
        end

        Utils.rawMetadata = photo:getRawMetadata()
        if Utils.rawMetadata.fileFormat == 'VIDEO' then
            call:setCaption( "Dialog box needs your attention..." )
            app:show( { warning="Comparison not supported for video." } )
            return
        end
        Utils.devSettings = photo:getDevelopSettings()        
        Utils.fmtMetadata = photo:getFormattedMetadata()
        
        Utils.photo = photo
        Utils.photoPath = Utils.rawMetadata.path
        call:setCaption( "Dialog box needs your attention..." )
        app:show{ info="^1\n \nPresent state of photo is selected for comparison.\n \nAfter dismissing this dialog box, select a different photo, or change state of selected photo (e.g. using 'Edit History'), then invoke 'Compare To Selected State'.",
            subs = Utils.photoPath,
            actionPrefKey = "State of present photo is selected for comparison",
        }
        
    end, finale = function( call )
        background:continue()
        if call.status then
            app:logv( "State selected for comparison" )
        else -- service would have logged an error, and thus a final error dialog box would be presented, but plain vanilla call: does nothing by default.      
            app:show{ error="Unable to select photo state for comparison - ^1", call.message }
        end
    end } )    
    
end



return SelectToCompare.main()
