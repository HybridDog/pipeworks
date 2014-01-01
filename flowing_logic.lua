-- This file provides the actual flow logic that makes liquids
-- move through the pipes.

local finite_liquids = minetest.setting_getbool("liquid_finite")
local pipe_liquid_max = 8
local pipe_liquid_shows_loaded = 2

-- Evaluate and balance liquid in all pipes

minetest.register_abm({
	nodenames = pipeworks.pipe_nodenames, 
	interval = 2,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local coords = {
			{x = pos.x,   y = pos.y,   z = pos.z},
			{x = pos.x,   y = pos.y-1, z = pos.z},
			{x = pos.x,   y = pos.y+1, z = pos.z},
			{x = pos.x-1, y = pos.y,   z = pos.z},
			{x = pos.x+1, y = pos.y,   z = pos.z},
			{x = pos.x,   y = pos.y,   z = pos.z-1},
			{x = pos.x,   y = pos.y,   z = pos.z+1},
		}

		local num_connections = 0
		local connection_list = {}
		local total_level = 0
		
		for _,adjacentpos in ipairs(coords) do
			local adjacent_node = minetest.get_node(adjacentpos)
			if adjacent_node and string.find(dump(pipeworks.pipe_nodenames), adjacent_node.name) then

				local node_level = (minetest.get_meta(adjacentpos):get_float("liquid_level")) or 0
				if node_level < 0 then node_level = 0 end

				total_level = total_level + node_level
				num_connections = num_connections + 1
				table.insert(connection_list, adjacentpos)
			end
		end

		local average_level = total_level / num_connections

		for _, connected_pipe_pos in ipairs(connection_list) do

			local newnode
			local connected_pipe = minetest.get_node(connected_pipe_pos)
			local pipe_name = string.match(connected_pipe.name, "pipeworks:pipe_%d.*_")

			if connected_pipe and pipe_name then
				minetest.get_meta(connected_pipe_pos):set_float("liquid_level", average_level)

				if average_level > pipe_liquid_shows_loaded then
					newnode = pipe_name.."loaded"
				else
					newnode = pipe_name.."empty"
				end
			end

			if newnode and connected_pipe.name ~= newnode then 
				minetest.swap_node(connected_pipe_pos, {name = newnode, param2 = connected_pipe.param2})
			end
		end
	end
})

-- Process all pumps in the area

minetest.register_abm({
	nodenames = {"pipeworks:pump_on", "pipeworks:pump_off"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local minp =		{x = pos.x-1, y = pos.y-1, z = pos.z-1}
		local maxp =		{x = pos.x+1, y = pos.y, z = pos.z+1}
		local pos_above =	{x = pos.x, y = pos.y+1, z = pos.z}
		local node_above = minetest.get_node(pos_above)
		if not node_above then return end

		local meta = minetest.get_meta(pos_above)
		local node_level_above = meta:get_float("liquid_level")
		if node_level_above == nil then node_level_above = 0 end
		local pipe_name = string.match(node_above.name, "pipeworks:pipe_%d.*_")

		if pipe_name then
			if node.name == "pipeworks:pump_on" then
				local water_nodes = minetest.find_nodes_in_area(minp, maxp, 
									{"default:water_source", "default:water_flowing"})
				if (node_level_above < pipe_liquid_max) and #water_nodes > 1 then
					meta:set_float("liquid_level", node_level_above + 4) -- add water to the pipe
				end
			else
				if node_level_above > 0 then
					meta:set_float("liquid_level", node_level_above - 1) -- leak the pipe down
				end
			end
		end
	end
})

-- Process all fountainheads in the area

minetest.register_abm({
	nodenames = {"pipeworks:fountainhead"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local pos_above = {x = pos.x, y = pos.y+1, z = pos.z}
		local node_above = minetest.get_node(pos_above) 
		if not node_above then return end

		local pos_below = {x = pos.x, y = pos.y-1, z = pos.z}
		local node_below = minetest.get_node(pos_below)
		if not node_below then return end

		local node_level_below = (minetest.get_meta(pos_below):get_float("liquid_level")) or 0
		print(node_level_below)
		print(dump(node_above.name))

		if node_level_below > 2
		  and (node_above.name == "air" or node_above.name == "default:water_flowing") then
			minetest.set_node(pos_above, {name = "default:water_source"})
		elseif node_level_below < 1 and node_above.name == "default:water_source" then
			minetest.set_node(pos_above, {name = "air"})
		end

		if node_level_below > 1
		  and (node_above.name == "air" or node_above.name == "default:water_source") then
			minetest.get_meta(pos_below):set_float("liquid_level", node_level_below - 1)
		end
	end
})

-- Process all spigots in the area

minetest.register_abm({
	nodenames = {"pipeworks:spigot","pipeworks:spigot_pouring"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local pos_below = {x = pos.x, y = pos.y-1, z = pos.z}
		local below_node = minetest.get_node(pos_below)
		if not below_node then return end

		if below_node.name == "air" or below_node.name == "default:water_flowing"
		  or below_node.name == "default:water_source" then 
			local fdir = node.param2
			local fdir_to_pos = {
				{x = pos.x,   y = pos.y, z = pos.z+1},
				{x = pos.x+1, y = pos.y, z = pos.z  },
				{x = pos.x,   y = pos.y, z = pos.z-1},
				{x = pos.x-1, y = pos.y, z = pos.z  }
			}

			local pos_adjacent = fdir_to_pos[fdir+1]
			local adjacent_node = minetest.get_node(pos_adjacent)
			if not adjacent_node then return end
			local adjacent_node_level = (minetest.get_meta(pos_adjacent):get_float("liquid_level")) or 0
			local pipe_name = string.match(adjacent_node.name, "pipeworks:pipe_%d.*_")

			if pipe_name and adjacent_node_level > 2
			  and (below_node.name == "air" or below_node.name == "default:water_flowing") then
				minetest.set_node(pos, {name = "pipeworks:spigot_pouring", param2 = fdir})
				minetest.set_node(pos_below, {name = "default:water_source"})
			end

			if (pipe_name and adjacent_node_level < 1)
			  or (node.name ~= "pipeworks:spigot" and not pipe_name) then
				minetest.set_node(pos,{name = "pipeworks:spigot", param2 = fdir})
				if below_node.name == "default:water_source" then
					minetest.set_node(pos_below, {name = "air"})
				end
			end

			if adjacent_node_level > 1
			  and (below_node.name == "air" or below_node.name == "default:water_source") then
				minetest.get_meta(pos_adjacent):set_float("liquid_level", adjacent_node_level - 1)
			end
		end
	end
})

--[[
other nodes that need processed separately:
table.insert(pipeworks.pipe_nodenames,"pipeworks:valve_on_empty")
table.insert(pipeworks.pipe_nodenames,"pipeworks:valve_off_empty")
table.insert(pipeworks.pipe_nodenames,"pipeworks:entry_panel_empty")
table.insert(pipeworks.pipe_nodenames,"pipeworks:flow_sensor_empty")
table.insert(pipeworks.pipe_nodenames,"pipeworks:valve_on_loaded")
table.insert(pipeworks.pipe_nodenames,"pipeworks:entry_panel_loaded")
table.insert(pipeworks.pipe_nodenames,"pipeworks:flow_sensor_loaded")
]]--
