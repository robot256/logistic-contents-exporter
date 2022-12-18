


--local event = require("__flib__.event")
--local gui = require("__flib__.gui")

--require("gui.gui")


--event.register({ "lnav-toggle-gui", defines.events.on_lua_shortcut }, function(e)
--  if (e.input_name or e.prototype_name) == "lnav-toggle-gui" then
--    local player = game.players[e.player_index]
--    if player then
--      makePlayerGui(player)
--    end
--  end
--end)

--[[
Inventory data structure:

inv.force.total, inv.force.by_surface


For a given force.

inv.total[item] = #
inv.chest[item] = #
inv.logistic[item] = #
inv.logisitic_basic[item] = #
inv.logistic_high[item] = #

inv.bysurface[surface] = inv_structure

inv.bynetwork[netid] = inv_structure




Need a list of all the storage entities



--]]


Listing = {}

function Listing.new()
  return {
    total={},
    chest={},
    logistic={
      all={},
      available={},
      ["passive-provider"]={},
      ["active-provider"]={},
      storage={},
      buffer={},
      requester={}
    },
    entities={}
  }
end

function Listing.add(list, container)
  if container and container.valid and (container.type == "container" or container.type == "logistic-container") then
    local inventory = container.get_inventory(defines.inventory.chest)
    if inventory and inventory.valid and not inventory.is_empty() then
      local contents = inventory.get_contents()
      list.entities[container.name] = (list.entities[container.name] or 0) + 1
      for name, count in pairs(contents) do
        list.total[name] = (list.total[name] or 0) + count
        if container.type == "logistic-container" then
          local logistic_mode = container.prototype.logistic_mode
          list.logistic.all[name] = (list.logistic.all[name] or 0) + count
          list.logistic[logistic_mode][name] = (list.logistic[logistic_mode][name] or 0) + count
          if logistic_mode ~= "buffer" and logistic_mode ~= "requester" then
            list.logistic.available[name] = (list.logistic.available[name] or 0) + count
          end
        else
          list.chest[name] = (list.chest[name] or 0) + count
        end
      end
    end
  end
end


function Listing.mergeInventories(a, b)
  for name, count in pairs(b) do
    a[name] = (a[name] or 0) + count
  end
  return a
end

function Listing.merge(list, new)
  Listing.mergeInventories(list.total, new.total)
  Listing.mergeInventories(list.chest, new.chest)
  Listing.mergeInventories(list.entities, new.entities)
  for name, _ in pairs(list.logistic) do
    list.logistic[name] = Listing.mergeInventories(list.logistic[name], new.logistic[name])
  end
  return list
end



function surfaceInventory(force, surface)
  local list = Listing.new()
  for _, e in pairs(surface.find_entities_filtered{force=force, type={"container","logistic-container"}}) do
    Listing.add(list, e)
  end
  return list
end


function allInventory(force)
  local allsurfaces = Listing.new()
  local bysurface = {}
  for name, surface in pairs(game.surfaces) do
    bysurface[name] = surfaceInventory(force, surface)
    Listing.merge(allsurfaces, bysurface[name])
  end
  bysurface["__all__"] = allsurfaces
  return bysurface
end


function spairs(t)
    local order = function(t,a,b) return t[b] < t[a] end
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end


function makeSpreadsheet(bysurface, player_index)
  -- Write a CSV file with one row for each item, and one column for each surface (total first)
  -- Only use the totals for each surface
  -- Sort items by total count of that item
  -- Sort surfaces by total count of all items
  
  local surface_totals = {}
  for sname, slist in pairs(bysurface) do
    local stotal = 0
    for iname, icount in pairs(slist.total) do
      stotal = stotal + icount
    end
    if stotal > 0 then
      surface_totals[sname] = stotal
    end
  end
  
  local sorted_surfaces = {}
  for sname, stotal in spairs(surface_totals) do
    sorted_surfaces[#sorted_surfaces+1] = sname
  end
  
  local sorted_items = {}
  for iname, itotal in spairs(bysurface["__all__"].total) do
    sorted_items[#sorted_items+1] = iname
  end
  
  local FILENAME = "inventory_all_table.csv"
  --game.write_file(FILENAME, "All Surface Inventory\n", false, player_index)
  local line = ",All,,,"
  for i=2,#sorted_surfaces do
    line = line..sorted_surfaces[i]..",,,"
  end
  game.write_file(FILENAME, line.."\n", false, player_index)
  
  line = "Item,"
  for i=1,#sorted_surfaces do
    line = line.."Total,Storage,Buffer,"
  end
  game.write_file(FILENAME, line.."\n", true, player_index)
  
  for j=1, #sorted_items do
    line = sorted_items[j]..","
    for i=1, #sorted_surfaces do
      local t = bysurface[sorted_surfaces[i]].total[sorted_items[j]]
      local a = bysurface[sorted_surfaces[i]].logistic.available[sorted_items[j]]
      local b = bysurface[sorted_surfaces[i]].logistic.buffer[sorted_items[j]]
      if t then
        line = line..tostring(t)..","
      else
        line = line..","
      end
      if a then
        line = line..tostring(a)..","
      else
        line = line..","
      end
      if b then
        line = line..tostring(b)..","
      else
        line = line..","
      end
    end
    game.write_file(FILENAME, line.."\n", true, player_index)
  end
  
  --[[
  game.write_file(FILENAME, "\n", true, player_index)
  local sorted_entities = {}
  for ename, etotal in spairs(bysurface["__all__"].entities) do
    sorted_entities[#sorted_entities+1] = ename
  end
  
  for k=1, #sorted_entities do
    line = sorted_entities[k]..","
    for i=1, #sorted_surfaces do
      local c = bysurface[sorted_surfaces[i] ].entities[sorted_entities[k] ]
      if c then
        line = line..tostring(c)..",,,"
      else
        line = line..",,,"
      end
    end
    game.write_file(FILENAME, line.."\n", true, player_index)
  end
  --]]
end


function lnav_surface(command)
  local player
  if command.player_index ~= nil then
    player = game.players[command.player_index]
  end
  if player then
    local surface = (command.parameter and game.surfaces[command.parameter]) or player.surface
    local inv = surfaceInventory(player.force, surface)
    game.write_file("inventory_"..surface.name..".txt", serpent.block(inv))
    player.print("Inventory written to file.")
  else
    game.print("Called lnav_surface command without a valid player handle.")
  end
end
commands.add_command("lnav_surface", "Writes a file with the items stored on this surface", lnav_surface)


function lnav_all(command)
  local player
  if command.player_index ~= nil then
    player = game.players[command.player_index]
  end
  if player then
    local inv = allInventory(player.force)
    game.write_file("inventory_all.txt", serpent.block(inv))
    makeSpreadsheet(inv, player.index)
    player.print("Inventory written to file.")
  else
    game.print("Called lnav_all command without a valid player handle.")
  end
end
commands.add_command("lnav_all", "Writes a file with the items stored on all surfaces", lnav_all)
