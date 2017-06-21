--[[
        Info.lua
--]]

return {
    appName = "Change Manager",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.ChangeManager",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc Change Manager",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/ChangeManagerLrPlugin",
    LrPluginInfoProvider = "ExtendedManager.lua",
    LrToolkitIdentifier = "com.robcole.lightroom.ChangeManager",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    LrEnablePlugin = "Enable.lua",
    LrDisablePlugin = "Disable.lua",
    LrMetadataProvider = "Metadata.lua",
    LrExportMenuItems = {
        {
            title = "&Lock",
            file = "mLock.lua",
        },
        {
            title = "&Batch Check",
            file = "mBatchCheck.lua",
        },        
        {
            title = "&Check for Changes",
            file = "mCheckForChanges.lua",
        },        
        {
            title = "&Unlock",
            file = "mUnLock.lua",
        },        
        {
            title = "&Select State For Compare",
            file = "mSelectToCompare.lua",
        },        
        {
            title = "&Compare To Selected State",
            file = "mCompareToSelected.lua",
        },
        {
            title = "&Compare Selected Photos",
            file = "mComparePhotos.lua",
        },
        {
            title = "&Auto-tone and Compare",
            file = "mAutotoneAndCompare.lua",
        },
        {
            title = "&Compare Catalog to Disk", -- actually vice-versa in the strictest sense, but I like the sound of this better.
            file = "mCompareCatalogToDisk.lua",
        },        
        {
            title = "Create Unlocked &Virtual Copy",
            file = "mCreateUnlockedVirtualCopy.lua",
        },        
        {
            title = "Select Read&-Only Photos",
            file = "mSelectReadOnlyPhotos.lua",
        },        
    },
    LrHelpMenuItems = { 
        --{ - quick tips moved to plugin manager.
        --    title = "&Quick Tips",
        --    file = "mHelpLocal.lua",
        --},
        {
            title = "&Reload",
            file = "mReload.lua",
        },
    },
    VERSION = { display = "5.12.5    Build: 2014-12-20 21:02:04" },
}
