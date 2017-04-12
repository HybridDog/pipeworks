local axistomainexit = {3, 1, 2, 5, 6, 4}
local function get_main_exit(param2)
	return axistomainexit[math.floor(param2 / 4)+1]
end

local dirinvert = {2,1, 4,3, 6,5}
local param2tosideexit = {
	1,5,2,6,
	4,5,3,6,
	3,5,4,6,
	1,4,2,3,
	1,3,2,4,
	1,6,2,5
}
local function get_side_exit(param2)
	return param2tosideexit[param2+1]
end


local function get_entering_dir(vel)
	vel = vector.apply(vel, function(v)
		return v < 0 and 1 or v > 0 and -1 or 0
	end)
	for i = 1,6 do
		if vector.equals(vel, pipeworks.meseadjlist[i]) then
			return i
		end

	end
	print"couldn't find entering dir"
	return -1
end


minetest.register_node("pipeworks:flipflop", {
	description = "Flip-Flop Tube",
	tiles = {
		"pipeworks_tube_noctr.png",
		"pipeworks_one_way_tube_top.png^[transformR90",
		"pipeworks_tube_noctr.png^pipeworks_flipflop.png^[transformFX",
		"pipeworks_tube_noctr.png^pipeworks_flipflop.png",
		"pipeworks_tube_noctr.png",
		"pipeworks_tube_noctr.png",
	},
	drawtype = "nodebox",
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = {
			{-9/64, -9/64, -.5, 9/64, 9/64, .5},
			{-9/64, 9/64, -9/64, 9/64, .5, 9/64}
		}
	},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy = 3, tubedevice = 1, tube = 1},
	tube = {
		can_go = function(pos, node, vel)
			local main_exit = get_main_exit(node.param2)
			local side_exit = get_side_exit(node.param2)
			local entered = get_entering_dir(vel)
			local exit = entered == main_exit and dirinvert[side_exit]
				or entered == side_exit and main_exit
			if not exit then
				return {}
			end
			node.param2 = node.param2 + (node.param2 % 4 < 2 and 2 or -2)
			minetest.swap_node(pos, node)
			return {pipeworks.meseadjlist[exit]}
		end,
		--~ insert_object = function(pos, node, stack, direction)
			--~ return ItemStack("")
		--~ end,
		connect_sides = {front = 1, back = 1, top = 1},
		priority = 38,
	},
	after_place_node = pipeworks.after_place,
	after_dig_node = pipeworks.after_dig,
})

--~ minetest.register_craft({
	--~ output = "pipeworks:flipflop",
	--~ recipe = {
		--~ { "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" },
		--~ { "default:steel_ingot", "", "default:steel_ingot" },
		--~ { "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
	--~ },
--~ })
