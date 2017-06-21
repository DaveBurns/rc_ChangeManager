--[[
        ExtendedManager.lua
--]]


local ExtendedManager, dbg, dbgf = Manager:newClass{ className='ExtendedManager' }



--[[
        Constructor for extending class.
--]]
function ExtendedManager:newClass( t )
    return Manager.newClass( self, t )
end



--[[
        Constructor for new instance object.
--]]
function ExtendedManager:new( t )
    return Manager.new( self, t )
end



--- Initialize global preferences.
--
function ExtendedManager:_initGlobalPrefs()
    Utils.initGlobalSnapAndMarkPref()
    app:initGlobalPref( 'historyPrefixForSnapshot', "snap: " )    
    app:initGlobalPref( 'historyPrefixForMark', "mark: " )
    app:initGlobalPref( 'styleName', "RC Finished, Summarized" ) -- ### change if changed.
    app:initGlobalPref( 'autoPublish', false )
    Manager._initGlobalPrefs( self )
end



--- Static method for initializing prefs.
--  Must be called during initialization, and
--  whenever preset changes.
function ExtendedManager:_initPrefs( presetName )
    -- Reminder: do not init named-styles pref, else it will come from prefs instead of backing file.
    app:initPref( 'background', true, presetName )
    app:initPref( 'processTargetPhotosInBackground', true, presetName ) -- hopefully, this will be reliable and light enough to be a desirable default.
    app:initPref( 'processAllPhotosInBackground', true, presetName )
    app:initPref( 'ignoreUnidentifiedChanges', true, presetName )
    app:initPref( 'ignoreBuried', true, presetName )
    app:initPref( 'lockedLabel', "", presetName )
    app:initPref( 'wrapWidth', 60, presetName )
    app:initPref( 'saveMetadataMode', 'auto', presetName )
    if WIN_ENV then
        app:initPref( 'readMetadataMode', 'auto', presetName )
    else
        app:setPref( 'readMetadataMode', 'manual', presetName ) -- this may be ignored in Mac env.
    end
    app:initPref( 'testData', "initial test data", presetName )
    -- base prefs:
    Manager._initPrefs( self, presetName ) -- not much there yet, but hey...
end



--- Start dialog method.
--
--  @usage      *** IMPORTANT: The base class method is critical and must be called by derived class,
--              <br>AFTER initializing all the pref values, so they get loaded into props.
--
function ExtendedManager:startDialogMethod( props )
    Manager.startDialogMethod( self, props )
end



--- Preference change handler.
--
--  <p>Handles change to preferences that are associated with a property table in the plugin manager UI.<br>
--  Examples: adv-dbg-ena, pref-set-name.</p>
--
--  @param      props       Properties associated with value change.
--  @param      prefs       Preferences associated with value change.
--  @param      name        Preference name.
--  @param      value       New preference value.
--
--  @usage      *** IMPORTANT: The base class method is critical and must be called by derived class.
--  @usage      Changed items are typically changed via the UI and are bound directly to lr-prefs.
--              <br>props are not bound to prefs explicitly/directly, but need to be reloaded if the pref set name changes.
--
function ExtendedManager:prefChangeHandlerMethod( _id, _prefs, name, value )
    --dbg( 'ExtendedManager:prefChangeHandlerMethod' )
    Manager.prefChangeHandlerMethod( self, _id, _prefs, name, value )
end



--- Property change handler
--
--  @param      props       property-table
--  @param      name        name of changed property
--  @param      value       new value of changed property
--
function ExtendedManager:propChangeHandlerMethod( props, name, value )
    --   A U T O   U P D A T E
    if app.prefMgr and (app:getPref( name ) == value) then -- eliminate redundent calls.
        return
    end
    if name == 'background' then
        app:setPref( 'background', value )
        if value then
            local started = background:start()
            if started then
                app:show( "Auto-check started." )
            else
                app:show( "Auto-check already started." )
            end
        elseif value ~= nil then
            app:call( Call:new{ name = 'Stop Background Task', async=true, guard=App.guardVocal, main=function( call )
                local stopped
                repeat
                    stopped = background:stop( 10 ) -- give it some seconds.
                    if stopped then
                        app:logVerbose( "Auto-check was stopped by user." )
                        app:show( "Auto-check is stopped." ) -- visible status wshould be sufficient.
                    else
                        if dialog:isOk( "Auto-check stoppage not confirmed - try again? (auto-check should have stopped - please report problem; if you cant get it to stop, try reloading plugin)" ) then
                            -- ok
                        else
                            break
                        end
                    end
                until stopped
            end } )
        end

        -- change handled.        
        return
    elseif name == 'lockedLabel' then -- ###2 needs more thought.
        --if value ~= app:getPref( 'lockedLabel' ) then
        --    app:show{ info="Consider using 'Update Labels' button to bring locked photos up to date based on 'Lock Label'." }
        --end
    end
    Manager.propChangeHandlerMethod( self, props, name, value )
end



--- return sections for bottom of plugin manager dialog box.
--
function ExtendedManager:sectionsForBottomOfDialogMethod( vf, props)

    local appSection = {}
    if app.prefMgr then
        appSection.bind_to_object = props
    else
        appSection.bind_to_object = prefs
    end
    
	appSection.title = app:getAppName() .. " Settings"
	appSection.synopsis = bind{ key='presetName', object=prefs }

	appSection.spacing = vf:label_spacing()

	appSection[#appSection + 1] = 
		vf:row {
            vf:static_text {
                title = "Ignore unidentified changes",
                width = share 'label_width',
            },
			vf:checkbox {
			    title = 'Consider significant differences only (recommended).',
				value = bind( "ignoreUnidentifiedChanges" ),
				tooltip = "with this unchecked, every time anything detectable about the photo changes, you'll be notified - more of a curiosity than anything: you probably won't want to leave this enabled...",
                width = share 'data_width',
			},
		}
    appSection[#appSection + 1] = vf:spacer{ height = 2 }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Auto-check control",
                width = share 'label_width',
            },
            vf:checkbox {
                title = "Enable auto-check, and check most selected photo for changes.",
                value = bind( 'background' ),
				tooltip = "this will protect most-selected locked file from inadvertent changes. it won't protect other photos from changes made via quick-develop, menu, or auto-sync... - for those, you'll need to run a manual check, or enable additional auto-checking.",
                width = share 'data_width',
            },
        }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Auto-check selected photos",
                width = share 'label_width',
            },
            vf:checkbox {
                title = "Automatically check selected photos for changes since lockage.",
                value = bind( 'processTargetPhotosInBackground' ),
                enabled = bind( 'background' ),
				tooltip = "this will protect all selected photos from inadvertent changes made via quick-develop, auto-sync, menus..., in a leisurely and unobtrusive manner.",
                width = share 'data_width',
            },
        }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Auto-check whole catalog",
                width = share 'label_width',
            },
            vf:checkbox {
                title = "Automatically check all photos in catalog for changes.",
                value = bind( 'processAllPhotosInBackground' ),
                enabled = bind( 'background' ),
				tooltip = "this will protect all photos in catalog from inadvertent changes made via quick-develop, auto-sync, menus..., in a leisurely and unobtrusive manner, with priority given to presently selected photos.",
                width = share 'data_width',
            },
        }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Ignore if buried in stack",
                width = share 'label_width',
            },
            vf:checkbox {
                title = "Ignore changed photos when not top of collapsed stack.",
                value = bind( 'ignoreBuried' ),
                enabled = LrBinding.orAllKeys( 'processTargetPhotosInBackground', 'processAllPhotosInBackground' ),
				-- tooltip = "Applies ",
                width = share 'data_width',
            },
        }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Auto-check status",
                width = share 'label_width',
            },
            vf:edit_field {
                bind_to_object = prefs,
                value = app:getGlobalPrefBinding( 'backgroundState' ),
                width = share 'data_width',
                tooltip = 'auto-check status',
                enabled = false, -- disabled fields can't have tooltips.
            },
        }
    appSection[#appSection + 1] = vf:spacer{ height = 2 }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Save metadata manually",
                width = share 'label_width',
            },
            vf:checkbox {
                title = str:fmt( 'Check this box if there are problems saving metadata when locking.' ),
                tooltip = "If you've already edited the keystroke used to save metadata (in advanced settings) and are still getting errors, this is your out...",
                bind_to_object = props,
                value = bind 'saveMetadataMode',
                width = share 'data_width',
                checked_value = 'manual',
                unchecked_value = 'auto',
            },
        }
    if WIN_ENV then
        appSection[#appSection + 1] =
            vf:row {
                vf:static_text {
                    title = "Read metadata manually",
                    width = share 'label_width',
                },
                vf:checkbox {
                    title = str:fmt( 'Check this box if there are problems reading metadata when reverting.' ),
                    tooltip = "If you've already edited the keystrokes used to read metadata (in advanced settings) and are still getting errors, this is your out...",
                    bind_to_object = props,
                    value = bind 'readMetadataMode',
                    width = share 'data_width',
                    checked_value = 'manual',
                    unchecked_value = 'auto',
                },
            }
    end
    
    appSection[#appSection + 1] = vf:spacer{ height = 2 }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "Lock Label",
                width = share 'label_width',
            },
            vf:edit_field {
                value = bind 'lockedLabel',
                width_in_chars = 20,
                tooltip = "Text for lock label (if desired), or blank to not disturb existing labeling.",
            },
            vf:push_button {
                title = "Update Lock Labels",
                tooltip = "Modify label of locked photos to match 'Lock Label'",            
                action = function( button )
                    Utils.updateLabels()                    
                end,
            }
        }
        
    appSection[#appSection + 1] = vf:spacer{ height = 2 }
    appSection[#appSection + 1] =
        vf:row {
            vf:static_text {
                title = "History wrap width",
                width = share 'label_width',
            },
            vf:edit_field {
                bind_to_object = props,
                value = bind 'wrapWidth',
                tooltip = "\"marking\" entries in edit history will wrap to the next line if longer than this - set to 1000 to always truncate.",
                precision=0, -- integer
                min=20,   -- really needs to be at least 30 or 40...
                max=1000, -- essentially "never" wrap.
                width_in_chars = 7,
            },
            vf:static_text {
                title = "Refers to note in edit history - an option when locking.",
            },
        }
	appSection[#appSection + 1] = 
	    vf:separator{ fill_horizontal = 1 }
	    
	
	-- ###2 move to base class?    
	appSection[#appSection + 1] = 
		vf:row {
			vf:push_button {
				title = "Edit Additional Settings",
				width = share 'label_width',
				action = function( button )
				    app:call( Call:new{ name=button.title, async=true, guard=App.guardVocal, main=function( call )
    
                        local viewItems, viewLookup, errm = systemSettings:getViewItemsAndLookup( call )
                
                        if tab:isNotEmpty( viewItems ) then
                        
                            --Debug.lognpp( viewItems, viewLookup )
                        
                            local button = app:show{ info="Additional Settings",
                                viewItems = viewItems,
                            }
                
                            if button == 'ok' then
                                -- ok
                            else
                                call:cancel()
                                return
                            end
                            
                        else
                            app:show{ warning="no view items" }
                            call:cancel()
                            return
                        end
                        
                    end, finale=function( call )
                        if not call:isCanceled() then
                            --Debug.showLogFile()
                        end
                    end } )
				end
			},
			vf:static_text {
				title = str:format( "Edit additional preference settings" ),
			},
		}
	    
	
	appSection[#appSection + 1] = 
		vf:row {
		    vf:push_button {
		        title = 'Quick Tips',
		        action = function( button )
                    app:call( Call:new{ name = "HelpLocal", main=function( call )
                    
                        local p = {}
                        
                        p[#p + 1] = app:getAppName() .. " protects your photos from inadvertent changes."
                        p[#p + 1] = "Step 1: Select photos that you've finished editing, then select 'Lock' from File Menu -> Plugin Extras -> " .. app:getPluginName() .. "..."
                        p[#p + 1] = "Note: the 'Revert' function reads metadata (including develop settings) from the locked xmp file into the catalog - the photo will still be locked."
                        p[#p + 1] = "Note: the 'Collect' function simply adds changed photos to the change collection. Auto-check won't prompt you anymore about it, once its in the change collection, so make sure you do something about it after accumulating one or more photos in the change collection."
                        p[#p + 1] = "To have most selected file auto-checked for changes since lockage, check the auto-check box in the plugin manager."
                        p[#p + 1] = "To compare two photos, or two states of the same photo, invoke 'Select To Compare', then select a different photo, or change states of the same photo (e.g. via edit-history or snapshot), then invoke 'Compare To Selection'."
                
                        dialog:quickTips( p ) -- presents the quick-tips with button to click to get for more info on web.
                        
                    end } )
                end
            },
        }
	if not app:isRelease() then
    	appSection[#appSection + 1] = vf:spacer{ height = 20 }
    	appSection[#appSection + 1] = vf:static_text{ title = 'Plugin Author Only' }
    	appSection[#appSection + 1] = vf:separator{ title = 'Developer Only', fill_horizontal = 1 }
	    appSection[#appSection + 1] = 
    		vf:row {
    			vf:edit_field {
    				value = bind( "testData" ),
    			},
    			vf:static_text {
    				title = str:format( "Test data" ),
    			},
    		}
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:push_button {
    				title = "Set Debug Func Breakpoint",
    				action = Debug.showErrors( function( button )
    				    App.getPref = Debug.breakFunc( App.getPref )
    				    -- Debug.pause( myFunc, orNot )
    				end ),
    			},
    			vf:static_text {
    				title = str:format( "Perform tests." ),
    			},
    		}
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:push_button {
    				title = "Test",
    				action = function( button )
    				    app:call( Call:new{ name='Test', async=true, main=function( call )

                              --app:show( "^1: ^2", app.prefMgr:getPresetName(), app:getPref( 'testData' ) )
                              local code = app:getPref( 'saveMetadataKeyChar' )
                              Debug.pause( code )
    				        
    				    end } )
    				end,
    			},
    			vf:static_text {
    				title = str:format( "Perform tests." ),
    			},
    		}
    end
		
    local sections = Manager.sectionsForBottomOfDialogMethod ( self, vf, props ) -- fetch base manager sections.
    tab:appendArray( sections, { appSection } ) -- put app-specific prefs after.
    return sections
end



return ExtendedManager
