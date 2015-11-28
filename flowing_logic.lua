-- This file provides the actual flow logic that makes liquids
-- move through the pipes.

local finite_liquids = minetest.setting_getbool("liquid_finite")
local pipe_liquid_shows_loaded = 1
local max_pressure = 4

if mesecon then
	pipereceptor_on = {
		receptor = {
			state = mesecon.state.on,
			rules = pipeworks.mesecons_rules
		}
	}

	pipereceptor_off = {
		receptor = {
			state = mesecon.state.off,
			rules = pipeworks.mesecons_rules
		}
	}
end

local get = vector.get_data_from_pos
local set = vector.set_data_to_pos
local remove = vector.remove_data_from_pos

-- returns touching pipes nodes
local function get_connected_pipe_stuff(z,y,x)
	local pipes,n = {},1
	for i = -1,1,2 do
		for _,p in pairs({
			{z+i, y, x},
			{z, y+i, x},
			{z, y, x+i},
		}) do
			local z,y,x = unpack(p)
			local node = get_node(z,y,x)
			if pipe_stuff(node.name) then
				pipes[n] = {{z,y,x}, node}
				n = n+1
			end
		end
	end
	return pipes
end

--[[nodename pressure y↓
air 0
air 0
liq 1
liq 2
cas 3
pip 4
]]

-- cast is not pupm, it's natural pressure
local function get_cast_pressure(pos, name)
	if get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= name then
		-- liquid doesn't flow to side, just down
		return 0
	end
	for i = 2,50 do
		if get_node({x=pos.x, y=pos.y+i, z=pos.z}).name ~= name then
			return i
		end
	end
	return 0
end

-- tests if there's a pipe where the liquid can flow in
local function can_flow(z,y,x, pressure, name)
	local pipe = get_pipe(z,y,x)
	return pipe
	and pipe.pressure < pressure
	and (not pipe.liquid or pipe.liquid == name)
end

-- calculates positions of pipes and devices connected to each other
local function liquid_flows(z,y,x, pressure, name)
	local pressure_y = y+pressure
	local todo = {{z,y,x}}
	local devices,d = {},1
	local tab_avoid = {}
	set(tab_avoid, z,y,x, true)
	local pipes,num = {{z,y,x}},2
	while next(todo) do
		for n,p in pairs(todo) do
			local z,y,x = unpack(p)
			for _,pips in pairs(get_connected_pipe_stuff(z,y,x)) do
				local z,y,x = unpack(pips[1])
				if y < pressure_y
				and not get(tab_avoid, z,y,x) then
					set(tab_avoid, z,y,x, true)
					local pressure = pressure_y - y
					if can_flow(z,y,x, pressure, name) then
						pipes[num] = {z,y,x}
						num = num+1
						table.insert(todo, {z,y,x})
					elseif device(z,y,x) then
						devices[d] = {z,y,x}
						d = d+1
					end
				end
			end
			todo[n] = nil
		end
	end
	return pipes, tab_avoid, devices
end

-- adds liquids to a pipe and/or changes its pressure
local function change_pipe(z,y,x, pressure, name)
	local pipe = get_pipe(z,y,x)
	if pipe.liquid ~= name then
		local node = get_node(z,y,x)
		node.name = pipe_liquid_name(node.name)
		set_node(z,y,x, node)
	end
	if pipe.pressure ~= pressure then
		meta_set_pressure(z,y,x, pressure)
	end
end

-- updates pipes and devices
local function flow_liquid(z,py,x, pressure, name)
	local pipes, pipes_ps, devices = liquid_flows(z,py,x, pressure, name)
	for _,p in pairs(pipes) do
		local z,y,x = unpack(p)
		local pressure = py-y
		change_pipe(z,y,x, pressure, name)
	end
	for _,p in pairs(devices) do
		local z,y,x = unpack(p)
		local pressure = py-y
		update_device(z,y,x, pressure, name)
	end
end


local function is_pipe(name)
	return string.find(dump(pipeworks.pipe_nodenames), name)
end

local function is_device(name)
	return string.find(dump(pipeworks.device_nodenames), name)
end

-- check if a valve, sensor, or other X-oriented device
-- has something connected at each end.

function pipeworks.is_device_connected(pos, node, axisdir, fdir_mod4, rotation)
	local fdir = node.param2
	local fdir_mod4_p2 = (fdir+2) % 4

	if rotation == "z" then
		fdir_mod4    = (fdir+1) % 4
		fdir_mod4_p2 = (fdir+3) % 4
	end

	local fdir_to_pos = {
		{x = pos.x+1, y = pos.y, z = pos.z  },
		{x = pos.x,   y = pos.y, z = pos.z-1},
		{x = pos.x-1, y = pos.y, z = pos.z  },
		{x = pos.x,   y = pos.y, z = pos.z+1},
	}

	local pos_adjacent1 = fdir_to_pos[fdir_mod4    + 1]
	local pos_adjacent2 = fdir_to_pos[fdir_mod4_p2 + 1]

	if rotation == "y" then
		pos_adjacent1 = { x=pos.x, y=pos.y+1, z=pos.z }
		pos_adjacent2 = { x=pos.x, y=pos.y-1, z=pos.z }
	end

	local adjacent_node1 = minetest.get_node(pos_adjacent1)
	local adjacent_node2 = minetest.get_node(pos_adjacent2)

	local set1
	local set2

	if is_pipe(adjacent_node1.name)
	or (is_device(adjacent_node1.name)
		and
			(adjacent_node1.param2 == fdir_mod4 or adjacent_node1.param2 == fdir_mod4_p2)
	) then
		set1 = true
	end

	if is_pipe(adjacent_node2.name)
	or (is_device(adjacent_node2.name)
		and
		(adjacent_node2.param2 == fdir_mod4 or adjacent_node2.param2 == fdir_mod4_p2)
	) then
		set2 = true
	end
	return {set1=set1, set2=set2, pos_adjacent1=pos_adjacent1, pos_adjacent2=pos_adjacent2}
end

-- Evaluate and balance liquid in all pipes

minetest.register_abm({
	nodenames = pipeworks.pipe_nodenames,
	interval = 1,
	chance = 1,
	action = function(pos, node)
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
			if adjacent_node and is_pipe(adjacent_node.name) then

				local node_level = minetest.get_meta(adjacentpos):get_float("liquid_level") or 0
				if node_level < 0 then node_level = 0 end

				total_level = total_level + node_level
				num_connections = num_connections + 1
				connection_list[num_connections] = adjacentpos
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
	action = function(pos, node)
		local minp =		{x = pos.x-1, y = pos.y-1, z = pos.z-1}
		local maxp =		{x = pos.x+1, y = pos.y, z = pos.z+1}
		local pos_above =	{x = pos.x, y = pos.y+1, z = pos.z}
		local node_above = minetest.get_node(pos_above)
		if not node_above then return end

		local meta = minetest.get_meta(pos_above)
		local node_level_above = meta:get_float("liquid_level") or 0
		local pipe_name = string.match(node_above.name, "pipeworks:pipe_%d.*_")
						  or (node_above.name == "pipeworks:entry_panel" and node_above.param2 == 13)

		if not pipe_name then
			return
		end
		if node.name == "pipeworks:pump_on" then
			local water_nodes = minetest.find_nodes_in_area(minp, maxp,
								{"default:water_source", "default:water_flowing"})

			if node_level_above < max_pressure
			and #water_nodes > 1 then
				meta:set_float("liquid_level", node_level_above + 4) -- add water to the pipe
			end
		else
			if node_level_above > 0 then
				meta:set_float("liquid_level", node_level_above - 0.5 ) -- leak the pipe down
			end
		end
	end
})

-- Process all spigots and fountainheads in the area

minetest.register_abm({
	nodenames = {"pipeworks:spigot", "pipeworks:spigot_pouring", "pipeworks:fountainhead"},
	interval = 2,
	chance = 1,
	action = function(pos, node)

		local fdir = node.param2 % 4
		if fdir ~= node.param2 then
			minetest.set_node(pos,{name = node.name, param2 = fdir})
		end

		local pos_below = {x = pos.x, y = pos.y-1, z = pos.z}
		local below_node = minetest.get_node(pos_below)
		if not below_node then
			return
		end

		if node.name == "pipeworks:fountainhead" then
			local pos_above = {x = pos.x, y = pos.y+1, z = pos.z}
			local node_above = minetest.get_node(pos_above)
			if not node_above then
				return
			end

			local node_level_below = minetest.get_meta(pos_below):get_float("liquid_level") or 0

			if node_level_below > 1
			  and (node_above.name == "air" or node_above.name == "default:water_flowing") then
				minetest.set_node(pos_above, {name = "default:water_source"})
			elseif node_level_below < 0.95 and node_above.name == "default:water_source" then
				minetest.remove_node(pos_above)
			end

			if node_level_below >= 1
			  and (node_above.name == "air" or node_above.name == "default:water_source") then
				minetest.get_meta(pos_below):set_float("liquid_level", node_level_below - 1)
			end
			return
		end

		if below_node.name ~= "air"
		and below_node.name ~= "default:water_flowing"
		and below_node.name ~= "default:water_source" then
			return
		end

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

		if pipe_name and adjacent_node_level > 1
		  and (below_node.name == "air" or below_node.name == "default:water_flowing") then
			minetest.set_node(pos, {name = "pipeworks:spigot_pouring", param2 = fdir})
			minetest.set_node(pos_below, {name = "default:water_source"})
		end

		if (pipe_name and adjacent_node_level < 0.95)
		  or (node.name ~= "pipeworks:spigot" and not pipe_name) then
			minetest.set_node(pos,{name = "pipeworks:spigot", param2 = fdir})
			if below_node.name == "default:water_source" then
				minetest.set_node(pos_below, {name = "air"})
			end
		end

		if adjacent_node_level >= 1
		  and (below_node.name == "air" or below_node.name == "default:water_source") then
			minetest.get_meta(pos_adjacent):set_float("liquid_level", adjacent_node_level - 1)
		end
	end
})

pipeworks.device_nodenames = {}

table.insert(pipeworks.device_nodenames,"pipeworks:valve_on_empty")
table.insert(pipeworks.device_nodenames,"pipeworks:valve_off_empty")
table.insert(pipeworks.device_nodenames,"pipeworks:valve_on_loaded")
table.insert(pipeworks.device_nodenames,"pipeworks:flow_sensor_empty")
table.insert(pipeworks.device_nodenames,"pipeworks:flow_sensor_loaded")
table.insert(pipeworks.device_nodenames,"pipeworks:entry_panel")

minetest.register_abm({
	nodenames = pipeworks.device_nodenames,
	interval = 2,
	chance = 1,
	action = function(pos, node)

		local fdir			= node.param2
		local axisdir		= math.floor(fdir/4)
		local fdir_mod4		= fdir % 4
		local rotation

		if string.match(node.name, "pipeworks:valve_off") then
			return
		end

		if node.name == "pipeworks:entry_panel" then
			rotation = "z"
			fdir_mod4 = (fdir+1) % 4

			-- reset the panel's facedir to predictable values, if needed

			if axisdir == 5 then
				minetest.swap_node(pos, {name = node.name, param2 = fdir_mod4 })
				return
			elseif axisdir ~= 0 and axisdir ~= 3 then
				minetest.swap_node(pos, {name = node.name, param2 = 13 })
				return
			end

			if node.param2 == 13 then
				rotation = "y"
			end
		elseif axisdir ~= 0 and axisdir ~= 5 then -- if the device isn't horizontal, force it.
			minetest.swap_node(pos, {name = node.name, param2 = fdir_mod4})
			return
		end

		local connections = pipeworks.is_device_connected(pos, node, axisdir, fdir_mod4, rotation)

		local num_connections = 1
		local my_level = (minetest.get_meta(pos):get_float("liquid_level")) or 0
		local total_level = my_level

		if not connections.set1 and not connections.set2 then return end

		if connections.set1 then
			num_connections = num_connections + 1
			total_level = total_level + (minetest.get_meta(connections.pos_adjacent1):get_float("liquid_level")) or 0
		end

		if connections.set2 then
			num_connections = num_connections + 1
			total_level = total_level + (minetest.get_meta(connections.pos_adjacent2):get_float("liquid_level")) or 0
		end

		local average_level = total_level / num_connections

		minetest.get_meta(pos):set_float("liquid_level", average_level)

		if connections.set1 then
			minetest.get_meta(connections.pos_adjacent1):set_float("liquid_level", average_level)
		end

		if connections.set2 then
			minetest.get_meta(connections.pos_adjacent2):set_float("liquid_level", average_level)
		end

		if node.name ~= "pipeworks:flow_sensor_empty"
		and node.name ~= "pipeworks:flow_sensor_loaded" then
			return
		end

		local sensor = string.match(node.name, "pipeworks:flow_sensor_")
		local newnode

		if my_level > 1 and (connections.set1 or connections.set2) then
			newnode = sensor.."loaded"
		else
			newnode = sensor.."empty"
		end

		if newnode == node.name then
			return
		end
		minetest.swap_node(pos, {name = newnode, param2 = node.param2})
		if mesecon then
			if newnode == "pipeworks:flow_sensor_empty" then
				mesecon.receptor_off(pos, rules)
			else
				mesecon.receptor_on(pos, rules)
			end
		end
	end
})

