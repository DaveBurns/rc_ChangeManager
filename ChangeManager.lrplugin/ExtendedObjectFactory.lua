--[[
        ExtendedObjectFactory.lua
        
        Creates special objects used in the guts of the framework.
        
        This is what you edit to change the classes of non-global objects,
        that you have extended.
--]]
local ExtendedObjectFactory, dbg, dbgf = ObjectFactory:newClass{ className = 'ExtendedObjectFactory', register = false }


function ExtendedObjectFactory:newClass( t )
    return ObjectFactory.newClass( self, t )
end

function ExtendedObjectFactory:new( t )
    local o = ObjectFactory.new( self, t )
    return o
end

function ExtendedObjectFactory:newObject( class, ... )
    if type( class ) == 'table' then
        --if class == Manager then
        --   return ExtendedManager:new( ... )
        --end
    elseif type( class ) == 'string' then
        if class == 'Manager' then
            return ExtendedManager:new( ... )
        elseif class == 'ExportDialog' then
            return ExtendedExport:newDialog( ... )
        elseif class == 'Export' then
            return ExtendedExport:newExport( ... )
        end
    end
    return ObjectFactory.newObject( self, class, ... )
end

return ExtendedObjectFactory 