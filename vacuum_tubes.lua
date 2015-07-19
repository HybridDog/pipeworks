if not pipeworks.enable_sand_tube
and not pipeworks.enable_mese_sand_tube then
	return
end

-- radius of the not adjustable tube
local radius_normal = 2

-- maximum radius of the adjustable tube
local radius_max = 8

-- every <update_interval> seconds unloaded vacuum tubes are searched
local update_interval = 4

-- it takes <vacuuming_speed> seconds until a fresh item gets picked up
local vacuuming_speed = 0.5


-- remembers known tube positions and their radians
local known_vacuumings = {}
local function get_vacuuming(pos)
	if not known_vacuumings[pos.z] then
		return false
	end
	if not known_vacuumings[pos.z][pos.y] then
		return false
	end
	return known_vacuumings[pos.z][pos.y][pos.x] or false
end

-- vacuum function is used if a sand pipe becomes constructed
local tube_inject_item = pipeworks.tube_inject_item
local get_objects_inside_radius = minetest.get_objects_inside_radius
local function vacuum(pos, radius)
	for _, object in pairs(get_objects_inside_radius(pos, radius)) do
		local lua_entity = object:get_luaentity()
		if not object:is_player()
		and lua_entity
		and lua_entity.name == "__builtin:item" then
			local obj_pos = object:getpos()
			local x1, y1, z1 = pos.x, pos.y, pos.z
			local x2, y2, z2 = obj_pos.x, obj_pos.y, obj_pos.z

			if  x1 - radius <= x2 and x2 <= x1 + radius
			and y1 - radius <= y2 and y2 <= y1 + radius
			and z1 - radius <= z2 and z2 <= z1 + radius then
				if lua_entity.itemstring ~= "" then
					tube_inject_item(pos, pos, vector.new(0, 0, 0), lua_entity.itemstring)
					lua_entity.itemstring = ""
				end
				object:remove()
			end
		end
	end
end

-- begins knowing a tube
local function set_vacuuming(pos, r)
	known_vacuumings[pos.z] = known_vacuumings[pos.z] or {}
	known_vacuumings[pos.z][pos.y] = known_vacuumings[pos.z][pos.y] or {}
	known_vacuumings[pos.z][pos.y][pos.x] = r
	vacuum(pos, r+0.5)
end

-- a known tube disappeared
local function remove_vacuuming(pos)
	known_vacuumings[pos.z][pos.y][pos.x] = nil
	if next(known_vacuumings[pos.z][pos.y]) then
		return
	end
	known_vacuumings[pos.z][pos.y] = nil
	if next(known_vacuumings[pos.z]) then
		return
	end
	known_vacuumings[pos.z] = nil
end


if pipeworks.enable_sand_tube then
	pipeworks.register_tube("pipeworks:sand_tube", {
		description = "Vacuuming Pneumatic Tube Segment",
		inventory_image = "pipeworks_sand_tube_inv.png",
		short = "pipeworks_sand_tube_short.png",
		noctr = { "pipeworks_sand_tube_noctr.png" },
		plain = { "pipeworks_sand_tube_plain.png" },
		ends = { "pipeworks_sand_tube_end.png" },
		node_def = {
			groups = {vacuum_tube = 1},
			on_construct = function(pos)
				set_vacuuming(pos, radius_normal)
			end,
			on_destruct = function(pos)
				if get_vacuuming(pos) then
					remove_vacuuming(pos)
				end
			end,
		},
	})

	minetest.register_craft( {
		output = "pipeworks:sand_tube_1 2",
		recipe = {
			{ "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" },
			{ "group:sand", "group:sand", "group:sand" },
			{ "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" }
		},
	})

	minetest.register_craft( {
		output = "pipeworks:sand_tube_1",
		recipe = {
			{ "group:sand", "pipeworks:tube_1", "group:sand" },
		},
	})
end

if pipeworks.enable_mese_sand_tube then
	pipeworks.register_tube("pipeworks:mese_sand_tube", {
		description = "Adjustable Vacuuming Pneumatic Tube Segment",
		inventory_image = "pipeworks_mese_sand_tube_inv.png",
		short = "pipeworks_mese_sand_tube_short.png",
		noctr = { "pipeworks_mese_sand_tube_noctr.png" },
		plain = { "pipeworks_mese_sand_tube_plain.png" },
		ends = { "pipeworks_mese_sand_tube_end.png" },
		node_def = {
			groups = {vacuum_tube = 1},
			on_construct = function(pos)
				set_vacuuming(pos, 0)
				local meta = minetest.get_meta(pos)
				meta:set_int("dist", 0)
				meta:set_string("formspec", "size[2.1,0.8]"..
					"image[0,0;1,1;pipeworks_mese_sand_tube_inv.png]"..
					"field[1.3,0.4;1,1;dist;radius;${dist}]"..
					default.gui_bg..
					default.gui_bg_img)
				meta:set_string("infotext", "Adjustable Vacuuming Pneumatic Tube Segment")
			end,
			on_receive_fields = function(pos,_,fields,sender)
				if not pipeworks.may_configure(pos, sender) then
					return
				end
				local dist = tonumber(fields.dist)
				if not dist then
					return
				end
				dist = math.min(radius_max, math.max(0, dist))
				set_vacuuming(pos, dist)
				local meta = minetest.get_meta(pos)
				meta:set_int("dist", dist)
				meta:set_string("infotext", ("Adjustable Vacuuming Pneumatic Tube Segment (%dm)"):format(dist))
			end,
			on_destruct = function(pos)
				if get_vacuuming(pos) then
					remove_vacuuming(pos)
				end
			end,
		},
	})

	minetest.register_craft( {
		output = "pipeworks:mese_sand_tube_1 2",
		recipe = {
			{ "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" },
			{ "group:sand", "default:mese_crystal", "group:sand" },
			{ "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" }
		},
	})

	minetest.register_craft( {
		type = "shapeless",
		output = "pipeworks:mese_sand_tube_1",
		recipe = {
			"pipeworks:sand_tube_1",
			"default:mese_crystal_fragment",
			"default:mese_crystal_fragment",
			"default:mese_crystal_fragment",
			"default:mese_crystal_fragment"
		},
	})
end

minetest.register_abm({
	nodenames = {"group:vacuum_tube"},
	interval = update_interval,
	chance = 1,
	label = "Vacuum tubes",
	action = function(pos, node, active_object_count, active_object_count_wider)
		if get_vacuuming(pos) then
			return
		end
		local radius
		if string.find(node.name, "pipeworks:sand_tube") then
			radius = radius_normal
		elseif string.find(node.name, "pipeworks:mese_sand_tube") then
			radius = tonumber(minetest.get_meta(pos):get_int("dist")) or 0
		else
			minetest.log("error", "[pipeworks] unknown vacuum pipe node: "..node.name)
			return
		end
		set_vacuuming(pos, radius)
	end
})

-- searches sand tubes near the object and puts it into it if one is found
local maxradius = radius_max
local function get_vacuumed(obj)
	local lua_entity = obj:get_luaentity()
	if not lua_entity or lua_entity.itemstring == "" then
		return false
	end
	local pos = obj:getpos()
	for z = math.floor(pos.z-maxradius), math.ceil(pos.z+maxradius) do
		if known_vacuumings[z] then
			for y = math.floor(pos.y-maxradius), math.ceil(pos.y+maxradius) do
				if known_vacuumings[z][y] then
					for x = math.floor(pos.x-maxradius), math.ceil(pos.x+maxradius) do
						local r = known_vacuumings[z][y][x]
						if r then
							local tpos = {x=x, y=y, z=z}
							local objtotube = vector.subtract(tpos, pos)
							if math.max(math.abs(objtotube.x), math.abs(objtotube.y), math.abs(objtotube.z)) <= r
							and vector.length(objtotube) <= r then
								tube_inject_item(tpos, tpos, vector.new(0, 0, 0), lua_entity.itemstring)
								lua_entity.itemstring = ""
								obj:remove()
								return true
							end
						end
					end
				end
			end
		end
	end
	return false
end


-- override the item entity that items become vacuumed if they were dropped
local item_entity = minetest.registered_entities["__builtin:item"]
local old_on_step = item_entity.on_step or function()end
local old_on_activate = item_entity.on_activate or function()end

item_entity.on_activate = function(self, ...)
	old_on_activate(self, ...)
	self.pipeworks_timer = update_interval-vacuuming_speed
end

item_entity.on_step = function(self, dtime)
	local timer = self.pipeworks_timer
	timer = timer+dtime
	if timer >= update_interval then
		if get_vacuumed(self.object) then
			return
		end
		timer = vector.length(self.object:getvelocity())
	end
	self.pipeworks_timer = timer
	old_on_step(self, dtime)
end

minetest.register_entity(":__builtin:item", item_entity)

--[[ doing it in the first on_step is enough
local spawn_item = minetest.add_item
function minetest.add_item(...)
	local obj = spawn_item(...)
	if obj then
		get_vacuumed(obj)
		return obj
	end
end--]]
