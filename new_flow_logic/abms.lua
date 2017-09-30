-- reimplementation of new_flow_logic branch: processing functions
-- written 2017 by thetaepsilon



local flowlogic = {}
pipeworks.flowlogic = flowlogic



-- borrowed from above: might be useable to replace the above coords tables
local make_coords_offsets = function(pos, include_base)
	local coords = {
		{x=pos.x,y=pos.y-1,z=pos.z},
		{x=pos.x,y=pos.y+1,z=pos.z},
		{x=pos.x-1,y=pos.y,z=pos.z},
		{x=pos.x+1,y=pos.y,z=pos.z},
		{x=pos.x,y=pos.y,z=pos.z-1},
		{x=pos.x,y=pos.y,z=pos.z+1},
	}
	if include_base then table.insert(coords, pos) end
	return coords
end



-- local debuglog = function(msg) print("## "..msg) end



-- new version of liquid check
-- accepts a limit parameter to only delete water blocks that the receptacle can accept,
-- and returns it so that the receptacle can update it's pressure values.
local check_for_liquids_v2 = function(pos, limit)
	local coords = make_coords_offsets(pos, false)
	local total = 0
	for index, tpos in ipairs(coords) do
		if total >= limit then break end
		local name = minetest.get_node(tpos).name
		if name == "default:water_source" then
			minetest.remove_node(tpos)
			total = total + 1
		end
	end
	return total
end
flowlogic.check_for_liquids_v2 = check_for_liquids_v2



local label_pressure = "pipeworks.water_pressure"
local label_haspressure = "pipeworks.is_pressure_node"
flowlogic.balance_pressure = function(pos, node)
	-- debuglog("balance_pressure() "..node.name.." at "..pos.x.." "..pos.y.." "..pos.z)
	-- check the pressure of all nearby nodes, and average it out.
	-- for the moment, only balance neighbour nodes if it already has a pressure value.
	-- XXX: maybe this could be used to add fluid behaviour to other mod's nodes too?

	-- unconditionally include self in nodes to average over
	local meta = minetest.get_meta(pos)
	local currentpressure = meta:get_float(label_pressure)
	meta:set_int(label_haspressure, 1)
	local connections = { meta }
	local totalv = currentpressure
	local totalc = 1

	-- then handle neighbours, but if not a pressure node don't consider them at all
	for _, npos in ipairs(make_coords_offsets(pos, false)) do
		local neighbour = minetest.get_meta(npos)
		local haspressure = (neighbour:get_int(label_haspressure) ~= 0)
		if haspressure then
			local n = neighbour:get_float(label_pressure)
			table.insert(connections, neighbour)
			totalv = totalv + n
			totalc = totalc + 1
		end
	end

	local average = totalv / totalc
	for _, targetmeta in ipairs(connections) do
		targetmeta:set_float(label_pressure, average)
	end
end



flowlogic.run_input = function(pos, node, maxpressure, intakefn)
	-- intakefn allows a given input node to define it's own intake logic.
	-- this function will calculate the maximum amount of water that can be taken in;
	-- the intakefn will be given this and is expected to return the actual absorption amount.

	local meta = minetest.get_meta(pos)
	local currentpressure = meta:get_float(label_pressure)
	local intake_limit = maxpressure - currentpressure
	if intake_limit <= 0 then return end

	local actual_intake = intakefn(pos, intake_limit)
	if actual_intake <= 0 then return end
	if actual_intake >= intake_limit then actual_intake = intake_limit end

	local newpressure = actual_intake + currentpressure
	-- debuglog("oldpressure "..currentpressure.." intake_limit "..intake_limit.." actual_intake "..actual_intake.." newpressure "..newpressure)
	meta:set_float(label_pressure, newpressure)
end



flowlogic.run_spigot_output = function(pos, node)
	-- try to output a water source node if there's enough pressure and space below.
	local meta = minetest.get_meta(pos)
	local currentpressure = meta:get_float(label_pressure)
	if currentpressure > 1 then
		local below = {x=pos.x, y=pos.y-1, z=pos.z}
		local name = minetest.get_node(below).name
		if (name == "air") or (name == "default:water_flowing") then
			minetest.set_node(below, {name="default:water_source"})
			meta:set_float(label_pressure, currentpressure - 1)
		end
	end
end
