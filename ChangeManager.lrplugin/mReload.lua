--[[
        Reload.lua
        
        Handles 'Reload' menu item.
        
        Note: Seems to work as async task or synchronous,
        and although Init.lua normally does NOT run as a task,
        I went with asynchronous, since reload needs to wait
        for background task.
--]]

reload:now()
