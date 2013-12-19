reactors = {}
function reactors.get_formspec(pos, meta)
	formspec = "size[14,9]"..
	"list[context;charge;2,1;1,1;]"..
	"list[current_player;main;0,5;8,4;]"
	local meta = minetest.env:get_meta(pos)
	local node = minetest.env:get_node(pos)
	local percent = meta:get_int("energy")/get_node_field(node.name,meta,"max_energy")*100
	local chrbar="image[3,2;2,1;itest_charge_bg.png^[lowpart:"..
			percent..":itest_charge_fg.png^[transformR270]"
	return formspec..chrbar.."list[context;main;6,0;8,4;]"..
					"label[3,1;"..meta:get_int("heat").."]"..
					"label[3.5,2;"..meta:get_int("energy").."]"
end

function reactors.on_construct(pos)
	local meta = minetest.env:get_meta(pos)
	meta:set_int("energy",0)
	meta:set_int("on",0)
	local inv = meta:get_inventory()
	inv:set_size("main", 8*4)
	inv:set_width("main", 8)
	reactors.set_fs(pos, meta)
	generators.on_construct(pos)
end
function reactors.set_fs(pos, meta)
	meta:set_string("formspec", reactors.get_formspec(pos), meta)
end
function reactors.inventory(pos, listname, stack, power)
	if listname=="charge" then
		local chr = get_item_field(stack:get_name(),"charge_tier")
		if chr~=nil and chr <= power then
			return stack:get_count()
		end
		return 0
	end
end
reactors.node = {
	on_construct = function(pos)
		reactors.on_construct(pos)
	end,
	can_dig = function(pos,player)
		local meta = minetest.env:get_meta(pos);
		local inv = meta:get_inventory()
		if not inv:is_empty("main") then
			return false
		end
		return generators.can_dig(pos,player)
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "main" then
			return stack:get_count()
		end
		return reactors.inventory(pos, listname, stack, 3)
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.env:get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack(from_list, from_index)
		if to_list == "main" then
			return stack:get_count()
		end
		return reactors.inventory(pos, to_list, stack, 3)
	end,
	mesecons = {effector = {
		rules = lightstone_rules,
		action_off = function (pos, node)
			local meta = minetest.env:get_meta(pos)
			meta:set_int("on", 0)
		end,
		action_on = function (pos, node)
			local meta = minetest.env:get_meta(pos)
			meta:set_int("on", 1)
		end,
	}},
}

-------------------------------------
function reactors.get_table_for_item(name)
	return minetest.registered_items[name]
end

function reactors.get_max_heat(pos)
	return 10000
end

function reactors.emit(heat, eng, inv, x, y)
	if x < 1 then						return heat, eng end
	if y < 1 then						return heat, eng end
	if x > inv:get_width("main") then	return heat, eng end
	if y > 8 then						return heat, eng end
	local i = x + y * inv:get_width("main")
	local stack = inv:get_stack("main", i)
	if stack:get_name()=="itest_reactors:uranium_cell" then
		return heat + reactors.dissipateHeatFromCell(5, inv, x, y), eng + 10
	end
	return heat, eng
end

function reactors.dissipateHeatCellIsOK(inv, x, y)
	if x < 1 then						return false end
	if y < 1 then						return false end
	if x > inv:get_width("main") then	return false end
	if y > 8 then						return false end
	local i = x + y * inv:get_width("main")
	local stack = inv:get_stack("main", i)
	local item = reactors.get_table_for_item(stack:get_name())
	if item~=nil
			and item.itest_reactor~=nil
			and item.itest_reactor.acceptsHeat~=nil
			and item.itest_reactor.acceptsHeat.flag==true then
		return true
	end
	return false
end

function reactors.addHeatToCell(heat, inv, x, y)
	if x < 1 then						return false end
	if y < 1 then						return false end
	if x > inv:get_width("main") then	return false end
	if y > 8 then						return false end
	
	local i = x + y * inv:get_width("main")
	local item = reactors.get_table_for_item(inv:get_stack("main", i):get_name())
	if item==nil or item.itest_reactor==nil or item.itest_reactor.max_heat==nil then return end
	reactors.addWearToCell(heat * 65535 / item.itest_reactor.max_heat, inv, x, y, true)
end

function reactors.addWearToCell(wear, inv, x, y, doRemove)
	if x < 1 then						return false end
	if y < 1 then						return false end
	if x > inv:get_width("main") then	return false end
	if y > 8 then						return false end
	local i = x + y * inv:get_width("main")
	
	local stack = inv:get_stack("main", i):to_table()
		if stack~=nil then
		if stack.wear + wear < 65535 then
			stack.wear = math.max(stack.wear + wear, 0)
			inv:set_stack("main", i, stack)
			return
		end
		if doRemove==true then
			inv:set_stack("main", i, nil)
		else
			stack.wear = 65534
			inv:set_stack("main", i, stack)
		end
	end
end

function reactors.getHeatInCell(inv, x, y)
	if x < 1 then						return false end
	if y < 1 then						return false end
	if x > inv:get_width("main") then	return false end
	if y > 8 then						return false end
	local i = x + y * inv:get_width("main")
	
	local stack = inv:get_stack("main", i):to_table()
	local i = x + y * inv:get_width("main")
	local item = reactors.get_table_for_item(inv:get_stack("main", i):get_name())
	if item==nil or item.itest_reactor==nil or item.itest_reactor.max_heat==nil then return 0 end
	return stack.wear * item.itest_reactor.max_heat / 65535
end

function reactors.dissipateHeatFromCellFinderSides(heat, inv, x, y, sides)
	
	local count = 0
	
	
	for name, val in pairs(sides) do
		if reactors.dissipateHeatCellIsOK(inv, val.x, val.y)==false then
			sides[name] = nil
		else
			count = count + 1
		end
	end
	
	return sides, count
end

function reactors.dissipateHeatFromCellFinder(heat, inv, x, y)
	
	local sides = {
		t={x=x, y=y - 1}, -- top
		b={x=x, y=y + 1}, -- bottom
		l={x=x - 1, y=y}, -- left
		r={x=x + 1, y=y}, -- right
	}
	
	local sides, count = reactors.dissipateHeatFromCellFinderSides(heat, inv, x, y, sides)
	
	return sides, count
end

function reactors.dissipateHeatFromCell(heat, inv, x, y)
	local sides, count = reactors.dissipateHeatFromCellFinder(heat, inv, x, y)
	if count == 0 then
		return heat
	end
	for name, val in pairs(sides) do
		reactors.addHeatToCell(heat / count, inv, val.x, val.y)
	end
	return 0
end

function reactors.merge_heat(levels, inv, x, y)
	
	local sides = {
		r={x=x, y=y}, -- middle
		t={x=x, y=y - 1}, -- top
		b={x=x, y=y + 1}, -- bottom
		l={x=x - 1, y=y}, -- left
		r={x=x + 1, y=y}, -- right
	}
	local count = 0
	sides, count = reactors.dissipateHeatFromCellFinderSides(heat, inv, x, y, sides)
	
	local totalheat = 0
	
	for name, val in pairs(sides) do
		totalheat = totalheat + reactors.getHeatInCell(inv, val.x, val.y)
	end
	
	print(totalheat)
end
-------------------------------------

minetest.register_node("itest_reactors:reactor", {
	description = "Reactor",
	tiles = {"itest_generator_side.png", "itest_generator_side.png", "itest_generator_side.png",
		"itest_generator_side.png", "itest_generator_side.png", "itest_generator_front.png"},
	paramtype2 = "facedir",
	groups = {energy=1, cracky=2},
	legacy_facedir_simple = true,
	sounds = default.node_sound_stone_defaults(),
	itest = {max_energy=40000,max_psize=512},
	-----------------
	on_construct						= reactors.node.on_construct,
	can_dig								= reactors.node.can_dig,
	allow_metadata_inventory_put		= reactors.node.allow_metadata_inventory_put,
	allow_metadata_inventory_move		= reactors.node.allow_metadata_inventory_move,
	mesecons							= reactors.node.mesecons,
})

minetest.register_node("itest_reactors:reactor_active", {
	description = "Reactor (active)",
	tiles = {"itest_generator_side.png", "itest_generator_side.png", "itest_generator_side.png",
		"itest_generator_side.png", "itest_generator_side.png", "itest_generator_front_active.png"},
	paramtype2 = "facedir",
	light_source = 8,
	drop = "itest:generator",
	groups = {energy=1, cracky=2, not_in_creative_inventory=1},
	legacy_facedir_simple = true,
	sounds = default.node_sound_stone_defaults(),
	itest = {max_energy=40000,max_psize=512},
	-----------------
	on_construct						= reactors.node.on_construct,
	can_dig								= reactors.node.can_dig,
	allow_metadata_inventory_put		= reactors.node.allow_metadata_inventory_put,
	mesecons							= reactors.node.mesecons,
})

minetest.register_tool("itest_reactors:uranium_cell", {
	description = "Uranium cell",
	inventory_image = "itest_reactors_uranium_cell.png",
})

minetest.register_tool("itest_reactors:heat_vent_std", {
	description = "Heat Vent",
	inventory_image = "itest_reactors_heat_vent.png",
	itest_reactor = {
		dissipatesHeat = {
			self = 6,
		},
		acceptsHeat = {
			flag = true,
		},
		max_heat = 1000,
	},
})

minetest.register_tool("itest_reactors:heat_vent_core", {
	description = "Core Heat Vent",
	inventory_image = "itest_reactors_heat_vent_core.png",
	itest_reactor = {
		dissipatesHeat = {
			self = 5,
		},
		acceptsHeat = {
			flag = true,
		},
		coreheat = {
			fromcore = 5,
		},
		max_heat = 1000,
	},
})

minetest.register_tool("itest_reactors:heat_vent_adv", {
	description = "Advanced Heat Vent",
	inventory_image = "itest_reactors_heat_vent_adv.png",
	itest_reactor = {
		dissipatesHeat = {
			self = 12,
		},
		acceptsHeat = {
			flag = true,
		},
		max_heat = 1000,
	},
})

minetest.register_tool("itest_reactors:heat_vent_comp", {
	description = "Component Heat Vent",
	inventory_image = "itest_reactors_heat_vent_comp.png",
	itest_reactor = {
		dissipatesHeat = {
			side = {
				[{x = 1, y= 0}] = 4,
				[{x =-1, y= 0}] = 4,
				[{x = 0, y= 1}] = 4,
				[{x = 0, y=-1}] = 4,
			},
		},
		acceptsHeat = {
			flag = true,
		},
		max_heat = 1000,
	},
})

minetest.register_tool("itest_reactors:heat_vent_overc", {
	description = "Overclocked Heat Vent",
	inventory_image = "itest_reactors_heat_vent_overc.png",
	itest_reactor = {
		dissipatesHeat = {
			self = 20,
		},
		acceptsHeat = {
			flag = true,
		},
		coreheat = {
			fromcore = 32,
		},
		max_heat = 1000,
	},
})

------------------------------------------

minetest.register_tool("itest_reactors:heat_exc_std", {
	description = "Heat Exchanger",
	inventory_image = "itest_reactors_heat_exc.png",
	itest_reactor = {
		max_heat = 1000,
	},
	moves_heat = {
	},
})



minetest.register_abm({
	nodenames = {"itest_reactors:reactor","itest_reactors:reactor_active"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.env:get_meta(pos)
		local inv = meta:get_inventory()
		
		if meta:get_string("heat") == "" then
			meta:set_int("heat", 0)
		end
		
		local heat = meta:get_int("heat")
		local eng = 0
		
		--for i=1, inv:get_size("main") do
		for x=1, inv:get_width("main") do
		for y=1, inv:get_size("main") / inv:get_width("main") do
--			local x = ((i - 1) % inv:get_width("main")) + 1
--			local y = math.floor(i / inv:get_width("main")) + 1
			local i = x + y * inv:get_width("main")
--			print(x .. "," .. y)
			local stack = inv:get_stack("main", i)
			if meta:get_int("on")==1 and stack:get_name()=="itest_reactors:uranium_cell" then
					heat, eng = reactors.emit(heat, eng, inv, x, y) -- middle
					heat, eng = reactors.emit(heat, eng, inv, x, y - 1) -- top
					heat, eng = reactors.emit(heat, eng, inv, x, y + 1) -- bottom
		 			heat, eng = reactors.emit(heat, eng, inv, x - 1, y) -- left
					heat, eng = reactors.emit(heat, eng, inv, x + 1, y) -- right	
					reactors.addWearToCell(200000, inv, x, y)
			end
			local item = reactors.get_table_for_item(stack:get_name())
			if item~=nil
					and item.itest_reactor~=nil then
				------------
				if item.itest_reactor.moves_heat~=nil then	
					reactors.merge_heat(inv, x, y)
				end
				------------
				if item.itest_reactor.dissipatesHeat~=nil then
					if item.itest_reactor.dissipatesHeat.self~=nil then
						reactors.addHeatToCell(-item.itest_reactor.dissipatesHeat.self, inv, x, y)
					end
					if item.itest_reactor.dissipatesHeat.side~=nil then
						for ofsetpos, cooler_heat_count in pairs(item.itest_reactor.dissipatesHeat.side) do
							reactors.addHeatToCell(-cooler_heat_count, inv, x + ofsetpos.x, y + ofsetpos.y)
						end
					end
				end
				if item.itest_reactor.coreheat~=nil
						and item.itest_reactor.coreheat.fromcore~=nil then
					local moveheat = math.min(5, heat)
					heat = heat - moveheat
					reactors.addHeatToCell(moveheat, inv, x, y)
				end
				-----------
			end
		end
		end
		
		heat = math.max(0, heat - 10)
		
		meta:set_int("heat", heat)
--		print("energy: " .. eng .. " heat: " .. heat)
		
		local m = get_node_field(node.name,meta,"max_energy")
		local e = meta:get_int("energy")
		meta:set_int("energy", math.min(m,eng+e))
		for i=1, 3 do
			e = meta:get_int("energy")
			if e==0 then
				break
			end
			local psize = math.min(512,e)
			meta:set_int("energy", e-psize)
			generators.produce(pos, psize)
		end
		
		reactors.set_fs(pos, meta)
		
--		if eng~=0 then
--			minetest.swap_node(pos, "itest_reactors:reactor_active")
--		else
--			minetest.swap_node(pos, "itest_reactors:reactor")
--		end
	end,
})
