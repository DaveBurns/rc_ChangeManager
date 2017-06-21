--[[
        CreateUnlockedVirtualCopy.lua
        
        Handles file menu item.
        
        Note: this class may very well not be the base class of anything, but instead
        be clones and renamed..., in which case the constructors can be deleted,
        and it can be downgraded to a reglar table object instead of class.
--]]

local CreateUnlockedVirtualCopy = {}


local dbg = Object.getDebugFunction( 'CreateUnlockedVirtualCopy' )


--- menu item handler
--
function CreateUnlockedVirtualCopy.main()

    app:call( Call:new{ name="Create Unlocked Virtual Copy", async=true, guard=App.guardVocal, main=function( call ) 
    
        local s, m = background:pause()
        if not s then
            app:show( { error="Unable to create virtual copy, error message: ^1" }, m )
            return
        end
        assert( background.state ~= 'running', "how running?" )

        local selPhotos = cat:getSelectedPhotos()
        local mostSelPhoto = catalog:getTargetPhoto()
        -- reminder: creation of virtual copy must precede reversion, since we want the virtual copy to have
        -- the changes made by the user.
        local newPhoto, msg = cat:createVirtualCopy( mostSelPhoto, true ) -- true => prompt
        if newPhoto then
            local name = cat:getPhotoNameDisp( mostSelPhoto ) 
            app:log( "Created virtual copy of ^1, copy name: ^2", name, newPhoto:getFormattedMetadata( 'copyName' ) )
            selPhotos[#selPhotos + 1] = newPhoto
            local s, m = Utils.unlockPhoto( newPhoto, newPhoto:getRawMetadata( 'path' ), false, newPhoto:getFormattedMetadata( 'copyName' ) ) -- dont think last param is used, but its called for so...
            -- *** false => dont try and make xmp read/write.
            if s then
                app:log( "Above mentioned virtual copy has been successfully unlocked." )
            else
                error( str:fmt( "Unable to unlock virtual copy due to error: ^1", m ) )
            end

            s, m = cat:setSelectedPhotos( newPhoto, selPhotos ) -- make sure the newly created virtual copy is selected, but the other selections aren't lost.
            if s then
                app:logVerbose( "Unlocked virtual copy selected." )
            else
                app:logVerbose( "Unable to select unlocked virtual copy, error message: ^1", m )
            end
            
        elseif msg then -- user didn't cancel
            error( str:fmt( "Unable to create virtual copy due to error: ^1", msg ) )
        -- else user canceled.
        end
    
    end, finale = function( call, status, message )

        if not status then
            app:show( { error=message } )
        end
        background:continue()
    
    end } )    
    
end



return CreateUnlockedVirtualCopy.main()
