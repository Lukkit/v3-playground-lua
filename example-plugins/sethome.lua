local lukkit = require("lukkit")

local homestore_opts = {
  store_type: lukkit.store.type.JSON,
  overwrite_oncorrupt: false
}


-- Runs when the plugin is enabled
function lukkit.plugin:enable()
  local plugin_name = self.info.name
  self.logger:info("Enabling {}", plugin_name)
end

-- Runs when the plugin is disabled (shutdown, reload etc.)
function lukkit.plugin:disable()
  local plugin_name = self.info.name
  self.logger:info("Disabling {}", plugin_name)
end

-- Runs when the plugin is loaded (before enabled, on file read, can stop loading)
function lukkit.plugin:load(load_context)
  -- Can load a SQLite DB, JSON doc or YAML
  local home_storage = self.store:load("home", homestore_opts)

  -- do setup with store

  if (home_storage:is_read_only()) then
    -- Stop the plugin from continuining with a load
    load_context:reject("Home store cannot be written to")
  end
end


function lukkit.plugin:command(cmd, sender, args)
  -- Handles any case permutation of "home" (e.g. "home", "Home", "HOME" etc.)
  if (cmd:equals_lower("home")) then

    -- Functional wrapper to only execute if the sender is a player, no-op if not
    sender:if_player(function(player)
        -- Gets the player's current display name. May or may not be the account name
        local name = player.display_name
        -- Fetch the home store. If not found the resulting LOption will not have a value
        local home_store = self.store:get("homes")

        -- Will throw an exception & fail the current command (safely)
        -- When in dev mode debug data will also be shown
        -- This should only be used when something SHOULD NEVER be false (such as a
        --   store which was loaded in the 'load' lifecycle stage)
        lukkit.assert(home_store:has_value(), "No home store was created before read")

        -- Gets the player's UUID which is the home value's key
        local home_key = player:uuid()

        -- Do a store lookup using the UUID as a key
        local player_home = home_store:get(home_key)

        player_home:if_exists(function(value)
        	-- Teleport in local world, maybe allow vectors?
        	player:teleport(value.x, value.y, value.z)
        	player:message("Thanks for flying with us, {}", name)

            cmd:succeed("Teleported player {} to position {} {} {x,y,z}", name, value)
        end)

        -- Safely handle a missing home value
        player_home:if_missing(function()
          	player:message("You don't have a home, use /sethome to set it!")

          	cmd:fail("No home set for player {}", name)
        end)
    end)

    -- Tell the server the command was a success, optional
    -- Ideally this would show in TRACE logs, idk
    return cmd:succeed("Command worked perfectly")
  end

  if (cmd:equals_lower("sethome"))
    sender:if_player(function(player)
        -- Get the current XYZ position of the player, without eye co-ords
    	local current_pos = player:location():position()

        local home_store = self.store:get("homes")
        lukkit.assert(home_store:has_value(), "No home store was created before read")

        local home_key = player:uuid()
        home_store:set(home_key, current_pos)

        player:message("Your home has bee set at {x,y,z}!", current_pos)
        cmd:succeed("Set home for player {}", player.display_name)
    end)
  end
end
