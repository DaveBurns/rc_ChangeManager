--[[
        Metadata.lua
        
        Note: Metadata module must be edited to taste after plugin generator copies to destination.
--]]

local metadataTable = {} -- return table
local photoMetadata = {} -- photo metadata definition table

--[[
        Uncomment/add metadata here:
        
        id - used by plugin code only.
        version - only need to bump this if Lightroom isn't taking your changes, OR you want to use it in the update function.
        
        title => add to library panel with this name/label (pre-requisite for searchable)
        searchable => add to library filters (pre-requisite for browsable)
        browsable => add to smart collections
        
        dataType - string or enum are the only things that make sense @LR3.3.
            Hopefully Adobe will add boolean, number, and date soon.
            Mostly I set to string/enum if I know I will always want it to be a string/enum,
            and leave it off if I really want it to be numeric, or date. (Booleans are mostly being handled as enums at this point).
            
        *** IMPORTANT NOTE: Always convert browsable data (except enum) to string before writing, else smart collections will appear broken to the user.            
--]]
         
photoMetadata[#photoMetadata + 1] = { id='locked', title='Lock State', version=1, dataType='enum', values={{value="yes",title="Locked"},{value="no",title="Un-Locked"},{value=nil,title="Not Locked"}}, searchable=true, browsable=true, readOnly=true }
photoMetadata[#photoMetadata + 1] = { id='lockDate', title='Lock Change Date', version=3, dataType='string', searchable=true, browsable=true, readOnly=true }
photoMetadata[#photoMetadata + 1] = { id='lockDate_', version=1 }
photoMetadata[#photoMetadata + 1] = { id='devSettings', version=1, dataType='string' }
photoMetadata[#photoMetadata + 1] = { id='rawMetadata', version=1, dataType='string' }
photoMetadata[#photoMetadata + 1] = { id='fmtMetadata', version=1, dataType='string' }



--[[
        Update metadata from previous schema to new schema, if need be.
        
        No sense of having this until if/when schema version is bumped...
--]]        
-- local function updateFunc( catalog, previousSchemaVersion )
-- end

metadataTable.metadataFieldsForPhotos = photoMetadata
metadataTable.schemaVersion = 1
-- metadataTable.updateFromEarlierSchemaVersion = updateFunc

return metadataTable
    

