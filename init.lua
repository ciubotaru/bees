--[[
File name: init.lua
Project name: Bees, a mod for Minetest game engine
URL: https://github.com/ciubotaru/bees
Author: see CONTRIBUTORS
License: General Public License, version 3 or later
Date: February 21, 2016
]]

minetest.log('action', 'MOD: Bees loading...')
bees_version = '3.0-dev'

--VARIABLES
--bees gather honey within this distance; swarms settle beyond this distance
  if minetest.setting_get("bees_radius") == nil then
    bees_radius = 10
  else
    bees_radius = tonumber(minetest.setting_get('bees_radius'))
  end

--swarms settle only in places with growth rate above this value
  if minetest.setting_get("bees_swarm_settle_threshold") == nil then
    bees_swarm_settle_threshold = 1
  else
    bees_swarm_settle_threshold = tonumber(minetest.setting_get('bees_swarm_settle_threshold'))
  end

--survival number of flowers per hive
  if minetest.setting_get("bees_flowers_per_hive") == nil then
    bees_flowers_per_hive = 4
  else
    bees_flowers_per_hive = tonumber(minetest.setting_get('bees_flowers_per_hive'))
  end

--action timers speedup ratio (mainly for testing)
  if minetest.setting_get("bees_speedup") == nil then
    bees_speedup = 1
  else
    bees_speedup = tonumber(minetest.setting_get('bees_speedup'))
  end

  local bees = {}
  local formspecs = {}

  local i18n --internationalization
  if minetest.get_modpath("intllib") then
    i18n = intllib.Getter()
  else
    i18n = function(s,a,...)
      a={a,...}
      local v = s:gsub("@(%d+)", function(n)
        return a[tonumber(n)]
      end)
      return v
    end
  end

--FUNCTIONS
  function formspecs.hive_wild(pos, grafting)
    local spos = pos.x .. ',' .. pos.y .. ',' ..pos.z
    local formspec =
      'size[8,9]'..
      'list[nodemeta:'.. spos .. ';combs;1.5,3;5,1;]'..
      'list[current_player;main;0,5;8,4;]'
    if grafting then
      formspec = formspec..'list[nodemeta:'.. spos .. ';colony;3.5,1;1,1;]'
    end
    return formspec
  end

  function formspecs.hive_artificial(pos)
    local spos = pos.x..','..pos.y..','..pos.z
    local formspec =
      'size[8,9]'..
      'list[nodemeta:'..spos..';colony;3.5,1;1,1;]'..
      'list[nodemeta:'..spos..';frames;0,3;8,1;]'..
      'list[current_player;main;0,5;8,4;]'
    return formspec
  end

  function bees.count_flowers_around(pos)
    local minp = {x = pos.x - bees_radius, y = pos.y - bees_radius, z = pos.z - bees_radius}
    local maxp = {x = pos.x + bees_radius, y = pos.y + bees_radius, z = pos.z + bees_radius}
    local flowers = minetest.find_nodes_in_area(minp, maxp, 'group:flower')
    if not flowers then
      return 0
    end
    return flowers
  end

  function bees.count_hives_around(pos)
    local minp = {x = pos.x - bees_radius, y = pos.y - bees_radius, z = pos.z - bees_radius}
    local maxp = {x = pos.x + bees_radius, y = pos.y + bees_radius, z = pos.z + bees_radius}
    local hives = minetest.find_nodes_in_area(minp, maxp, 'group:hives')
    local i
    if not hives then
      return 0
    end
    for i = #hives, 1, -1 do
      if not bees.is_hive_alive(hives[i]) then
        table.remove(hives, i)
      end
    end
    return hives
  end

  function bees.growth_rate(nr_flowers, nr_hives)
    local growth_rate = nr_flowers / nr_hives / bees_flowers_per_hive - 1
    if growth_rate > 4 then
      return 4 --can not grow faster than that
    end
    return growth_rate --a number between -1 and 4
  end

  function bees.count_honey_combs(inv)
    local stacks = inv:get_list('combs')
    local honey_combs = 0
    for i=1,#stacks do
      if not inv:get_stack('combs', i):is_empty() then
        honey_combs = honey_combs + 1
      end
    end
    return honey_combs
  end

  function bees.swarming(pos) --splitting off a new wild hive from an existing one
    local minp = {x = pos.x - bees_radius * 2, y = pos.y - bees_radius * 2, z = pos.z - bees_radius * 2}
    local maxp = {x = pos.x + bees_radius * 2, y = pos.y + bees_radius * 2, z = pos.z + bees_radius * 2}
    local i
    local hives_around
    local flowers_around
    local new_hive_pos
    --first let's see if we can colonize an abandoned hive...
    --retrieve the list of hives within 2 radii from mother hive
    local hives = minetest.find_nodes_in_area(minp, maxp, 'group:hives')
    local best_growth_rate = bees_swarm_settle_threshold --starting value
    local chosen_places = {}
    local current_growth_rate
--    local chosen_place = {pos = nil, growth_rate = 0} --starting values
    for i = 1, #hives do
      --look at hives that are far (beyond 1 radius) and empty
      if (hives[i].x < pos.x - bees_radius or hives[i].x > pos.x + bees_radius) and (hives[i].y < pos.y - bees_radius or hives[i].y > pos.y + bees_radius) and (hives[i].z < pos.z - bees_radius or hives[i].z > pos.z + bees_radius) and bees.is_hive_alive(hives[i]) == false then
        current_growth_rate = bees.growth_rate(#bees.count_flowers_around(hives[i]),  #bees.count_hives_around(hives[i]) + 1)
        if growth_rate > best_growth_rate then --new champion
          chosen_places = {hives[i]}
          best_growth_rate = current_growth_rate
        elseif growth_rate == best_growth_rate then --add to champions
          table.insert(chosen_places, {hives[i]})
        end
      end
    end
    --see any place is above threshold
    if #chosen_places > 0 then --random among best places
      bees.recolonize_hive(chosen_places[math.random(#chosen_places)])
      return true
    end
    --if we are here, the swarm found no suitable hives for recolonization
    --let's try to build a wild hive
    --retrieve the list of leaves within 2 radii from mother hive
    local leaves = minetest.find_nodes_in_area(minp, maxp, 'group:leaves')
    --quit if no leaves at all
    if leaves == nil then
      return true
    end
    for i = #leaves, 1, -1 do --go backwards
      --look at leaves that are far (beyond 1 radius) and have air beneath
      if (leaves[i].x < pos.x - bees_radius or leaves[i].x > pos.x + bees_radius) and (leaves[i].y < pos.y - bees_radius or leaves[i].y > pos.y + bees_radius) and (leaves[i].z < pos.z - bees_radius or leaves[i].z > pos.z + bees_radius) and minetest.get_node({x = leaves[i].x, y = leaves[i].y - 1, z = leaves[i].z}).name == 'air' then
        current_growth_rate = bees.growth_rate(#bees.count_flowers_around({x = leaves[i].x, y = leaves[i].y - 1, z = leaves[i].z}),  #bees.count_hives_around({x = leaves[i].x, y = leaves[i].y - 1, z = leaves[i].z}) + 1)
        if current_growth_rate > best_growth_rate then --new champion
          chosen_places = {x = leaves[i].x, y = leaves[i].y - 1, z = leaves[i].z}
          best_growth_rate = current_growth_rate
        elseif current_growth_rate == best_growth_rate then --add to champions
          table.insert(chosen_places, {x = leaves[i].x, y = leaves[i].y - 1, z = leaves[i].z})
        end
      end
    end
    if #chosen_places > 0 then --random among best places
      minetest.set_node(chosen_places[math.random(#chosen_places)], {name = 'bees:hive_wild'})
      bees.fill_new_wild_hive(chosen_place.pos)
      return true
    end
    return false --the swarm could not find free space with good growth rate
  end

  function bees.fill_new_wild_hive(pos)
    minetest.get_node(pos).param2 = 0
    local meta = minetest.get_meta(pos)
    local inv  = meta:get_inventory()
    meta:set_int('agressive', 1)
    inv:set_size('colony', 1)
    inv:set_size('combs', 5)
    inv:set_stack('colony', 1, 'bees:colony')
    inv:set_stack('combs', 1, 'bees:honey_comb') --always start with one comb
    meta:set_string('infotext', i18n('colony is growing'))
    local timer = minetest.get_node_timer(pos)
    timer:start(1000 / bees_speedup)
  end

  function bees.recolonize_hive(pos)
    local meta = minetest.get_meta(pos)
    local inv  = meta:get_inventory()
    meta:set_int('agressive', 1)
    inv:set_stack('colony', 1, 'bees:colony')
    meta:set_string('infotext', i18n('hive has just been recolonized'))
    local timer = minetest.get_node_timer(pos)
    if not timer:is_started() then
      timer:start(1000 / bees_speedup) --set timer for the newly created hive
    end
  end

  function bees.is_hive_alive(pos)
    local meta = minetest.get_meta(pos)
    local inv  = meta:get_inventory()
    if inv:get_stack('colony', 1):is_empty() then
      return false
    else
      return true
    end
  end

  function bees.hive_on_timer(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local timer = minetest.get_node_timer(pos)
    if inv:contains_item('colony', 'bees:colony') then
      local i
      local progress = meta:get_int('progress') / 100
      local flowers_around = bees.count_flowers_around(pos)
      local hives_around = bees.count_hives_around(pos)
      local growth_rate = bees.growth_rate(#flowers_around, #hives_around)
      local growth = math.floor(growth_rate * 100 + 0.5) / 100 --2 digits after decimal
      progress = progress + growth
      --if growth rate is negative, the hive degrades and dies
      if growth_rate < 0 then
        --if progress is below zero, then try to remove honey from a frame
        if progress <= 0 then
          if inv:contains_item('frames', 'bees:frame_full') then
            local stacks = inv:get_list('frames')
            local frames = bees.count_frames(stacks)
            for i = #stacks, 1, -1 do --go backwards
              if inv:get_stack('frames', i):get_name() == 'bees:frame_full' then
                progress = progress + 100 --make it between 0 and 100
                meta:set_int('progress', progress * 100)
                inv:set_stack('frames', i ,'bees:frame_empty')
                meta:set_string('infotext', i18n('progress: @1', frames[2] - 1 .. '-' .. progress .. '/100'))
                timer:start(30 / bees_speedup)
                return
              end
            end
          end
          --else remove the colony
          inv:set_stack('colony', 1, '')
          meta:set_string('infotext', i18n('colony died, not enough flowers around'))
          meta:set_int('agressive', 0)
          timer:stop()
          return
        --if progress is positive, subtract the negative growth
        else
          local stacks = inv:get_list('frames')
          local frames = bees.count_frames(stacks)
          meta:set_int('progress', progress * 100)
          meta:set_string('infotext', i18n('progress: @1', frames[2] .. '-' .. progress .. '/100'))
          timer:start(30 / bees_speedup)
          return
        end
      --if positive growth, compute progress, add honey etc
      elseif growth_rate > 0 then
        if progress > 100 then
          progress = progress - 100
          meta:set_int('progress', progress * 100)
          if inv:contains_item('frames', 'bees:frame_empty') then
            local stacks = inv:get_list('frames')
            local frames = bees.count_frames(stacks)
            for k, v in pairs(stacks) do
              if inv:get_stack('frames', k):get_name() == 'bees:frame_empty' then
                inv:set_stack('frames', k, 'bees:frame_full')
                meta:set_string('infotext', i18n('progress: @1', frames[2] + 1 .. '+' .. progress ..'/100'))
                timer:start(30 / bees_speedup)
                return
              end
            end
          --if no empty frames, swarm!!!
          else
            bees.swarming(pos)
            local stacks = inv:get_list('frames') --they are all full
            local frames = bees.count_frames(stacks)
            meta:set_string('infotext', i18n('progress: @1', frames[2] - 1 .. '+' .. progress ..'/100'))--positive growth rate and one empty slot
            for k, v in pairs(stacks) do
              if inv:get_stack('frames', k):get_name() == 'bees:frame_full' then
                inv:set_stack('frames', k, 'bees:frame_empty') --clear the last frame
                timer:start(30 / bees_speedup)
                return
              end
            end
          end
        --if progress still under 100, just count full frames and update infotext
        else
          meta:set_int('progress', progress * 100)
          local stacks = inv:get_list('frames')
          local frames = bees.count_frames(stacks)
          meta:set_string('infotext', i18n('progress: @1', frames[2] .. '+' .. progress ..'/100'))
          timer:start(30 / bees_speedup)
          return
        end
      end
      --if growth is zero, reset timer and do nothing
      timer:start(30 / bees_speedup)
      return
    end
  end

  function bees.count_frames(stack)
    local full_frames = 0
    local empty_frames = 0
    for i = 1, #stack do
      if stack[i]:get_name() == 'bees:frame_full' then
        full_frames = full_frames + 1
      elseif stack[i]:get_name() == 'bees:frame_empty' then
        empty_frames = empty_frames + 1
      end
    end
    return {full_frames + empty_frames, full_frames, empty_frames}
  end

--NODES
  minetest.register_node('bees:extractor', {
    description = i18n('Honey extractor'),
    tiles = {
      "bees_extractor_top.png",
      "bees_extractor_bottom.png",
      "bees_extractor_right.png",
      "bees_extractor_left.png",
      "bees_extractor_rear.png",
      "bees_extractor_front.png"
    },
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {choppy=2,oddly_breakable_by_hand=2,tubedevice=1,tubedevice_receiver=1},
    drawtype = "nodebox",
    node_box = {
      type = "fixed",
      fixed = {
        {-0.25, -0.375, -0.3125, 0.0625, 0.4375, 0.5},
        {-0.5, -0.375, -0.0625, 0.3125, 0.4375, 0.25},
        {-0.375, -0.375, -0.25, 0.1875, 0.4375, 0.4375},
        {-0.4375, -0.375, -0.1875, 0.25, 0.4375, 0.375},
        {-0.5, 0.25, 0.0625, 0.375, 0.5, 0.125},
        {0.375, 0.25, 0.0625, 0.5, 0.3125, 0.125},
        {-0.5, -0.5, 0.0625, -0.4375, -0.375, 0.125},
        {0.25, -0.5, 0.0625, 0.3125, -0.375, 0.125},
        {-0.125, -0.5, 0.4375, -0.0625, -0.375, 0.5},
        {-0.125, -0.5, -0.3125, -0.0625, -0.375, -0.25},
        {-2/16, -4/16, -8/16, -1/16, -3/16, -5/16},
        {-2/16, -5/16, -8/16, -1/16, -4/16, -7/16},
      }
    },
    on_construct = function(pos, node)
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      local pos = pos.x..','..pos.y..','..pos.z
      inv:set_size('frames_filled'  ,1)
      inv:set_size('frames_emptied' ,1)
      inv:set_size('bottles_empty'  ,1)
      inv:set_size('bottles_full' ,1)
      inv:set_size('wax',1)
      meta:set_string('formspec',
        'size[8,9]'..
        --input
        'list[nodemeta:'..pos..';frames_filled;2,1;1,1;]'..
        'list[nodemeta:'..pos..';bottles_empty;2,3;1,1;]'..
        --output
        'list[nodemeta:'..pos..';frames_emptied;5,0.5;1,1;]'..
        'list[nodemeta:'..pos..';wax;5,2;1,1;]'..
        'list[nodemeta:'..pos..';bottles_full;5,3.5;1,1;]'..
        --player inventory
        'list[current_player;main;0,5;8,4;]'
      )
    end,
    on_timer = function(pos, node)
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      if not inv:contains_item('frames_filled','bees:frame_full') or not inv:contains_item('bottles_empty','vessels:glass_bottle') then
        return
      end
      if inv:room_for_item('frames_emptied', 'bees:frame_empty') 
      and inv:room_for_item('wax','bees:wax') 
      and inv:room_for_item('bottles_full', 'bees:bottle_honey') then
        --add to output
        inv:add_item('frames_emptied', 'bees:frame_empty')
        inv:add_item('wax', 'bees:wax')
        inv:add_item('bottles_full', 'bees:bottle_honey')
        --remove from input
        inv:remove_item('bottles_empty','vessels:glass_bottle')
        inv:remove_item('frames_filled','bees:frame_full')
        local p = {x=pos.x+math.random()-0.5, y=pos.y+math.random()-0.5, z=pos.z+math.random()-0.5}
        --wax flying all over the place
        minetest.add_particle({
          pos = {x=pos.x, y=pos.y, z=pos.z},
          velocity = {x=math.random(-4,4),y=math.random(8),z=math.random(-4,4)},
          acceleration = {x=0,y=-6,z=0},
          expirationtime = 2,
          size = math.random(1,3),
          collisiondetection = false,
          texture = 'bees_wax_particle.png',
        })
        local timer = minetest.get_node_timer(pos)
        timer:start(5)
      else
        local timer = minetest.get_node_timer(pos)
        timer:start(1) -- Try again in 1 second
      end
    end,
    tube = {
      insert_object = function(pos, node, stack, direction)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local timer = minetest.get_node_timer(pos)
        if stack:get_name() == "bees:frame_full" then
          if inv:is_empty("frames_filled") then
            timer:start(5)
          end
          return inv:add_item("frames_filled",stack)
        elseif stack:get_name() == "vessels:glass_bottle" then
          if inv:is_empty("bottles_empty") then
            timer:start(5)
          end
          return inv:add_item("bottles_empty",stack)
        end
        return stack
      end,
      can_insert = function(pos,node,stack,direction)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        if stack:get_name() == "bees:frame_full" then
          return inv:room_for_item("frames_filled",stack)
        elseif stack:get_name() == "vessels:glass_bottle" then
          return inv:room_for_item("bottles_empty",stack)
        end
        return false
      end,
      input_inventory = {"frames_emptied", "bottles_full", "wax"},
      connect_sides = {left=1, right=1, back=1, front=1, bottom=1, top=1}
    },
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
      local timer = minetest.get_node_timer(pos)
      local meta = minetest.get_meta(pos)
      local inv = meta:get_inventory()
      if inv:get_stack(listname, 1):get_count() == stack:get_count() then -- inv was empty -> start the timer
          timer:start(5) --create a honey bottle and empty frame and wax every 5 seconds
      end
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
      if (listname == 'bottles_empty' and stack:get_name() == 'vessels:glass_bottle') or (listname == 'frames_filled' and stack:get_name() == 'bees:frame_full') then
        return stack:get_count()
      else
        return 0
      end  
    end,
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
      return 0
    end,
  })

  minetest.register_node('bees:bees', {
    description = i18n('Flying bees'),
    drawtype = 'plantlike',
    paramtype = 'light',
    groups = { not_in_creative_inventory=1 },
    tiles = {
      {
        name='bees_strip.png', 
        animation={type='vertical_frames', aspect_w=16,aspect_h=16, length=2.0}
      }
    },
    damage_per_second = 1,
    walkable = false,
    buildable_to = true,
    pointable = false,
    on_punch = function(pos, node, puncher)
      local health = puncher:get_hp()
      puncher:set_hp(health-2)
    end,
  })

  minetest.register_node('bees:hive_wild', {
    description = i18n('Wild bee hive'),
    tiles = {'bees_hive_wild.png','bees_hive_wild.png','bees_hive_wild.png', 'bees_hive_wild.png', 'bees_hive_wild_bottom.png'}, --Neuromancer's base texture
    drawtype = 'nodebox',
    paramtype = 'light',
    paramtype2 = 'wallmounted',
    drop = {
      max_items = 6,
      items = {
        { items = {'bees:honey_comb'}, rarity = 5}
      }
    },
    groups = {choppy=2,oddly_breakable_by_hand=2,flammable=3,attached_node=1, hives = 1},
    node_box = { --VanessaE's wild hive nodebox contribution
      type = 'fixed',
      fixed = {
        {-0.250000,-0.500000,-0.250000,0.250000,0.375000,0.250000}, --NodeBox 2
        {-0.312500,-0.375000,-0.312500,0.312500,0.250000,0.312500}, --NodeBox 4
        {-0.375000,-0.250000,-0.375000,0.375000,0.125000,0.375000}, --NodeBox 5
        {-0.062500,-0.500000,-0.062500,0.062500,0.500000,0.062500}, --NodeBox 6
      }
    },
    on_timer = function(pos)
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      local timer= minetest.get_node_timer(pos)
      local flowers = bees.count_flowers_around(pos)
      local hives = bees.count_hives_around(pos)
      local growth_rate = bees.growth_rate(#flowers, #hives)
      --new mechanics starts here
      --if the colony is alive, look at growth rate and modify contents
      if not inv:get_stack('colony', 1):is_empty() then
        --if growth rate is negative, the hive degrades and dies
        if growth_rate < 0 then
          --first try to remove a comb
          local stacks = inv:get_list('combs')
          for i = #stacks, 1, -1 do --go backwards for fun
            if not inv:get_stack('combs', i):is_empty() then
              inv:set_stack('combs', i, '') --remove one comb
              meta:set_string('infotext', i18n('colony is dying, not enough flowers around'))
              timer:start(1000 / bees_speedup)
              return
            end
          end
          --if no combs, then remove the colony
          inv:set_stack('colony', 1, '')
          meta:set_string('infotext', i18n('colony died, not enough flowers around'))
          meta:set_int('agressive', 0)
          timer:start(1000 / bees_speedup)
          return
        --if growth rate is positive, the hive growth and swarms split off
        elseif growth_rate > 0 then
          --first try to add a comb
          local stacks = inv:get_list('combs')
          local comb_counter = 0
          for i = 1, #stacks do
            if inv:get_stack('combs', i):is_empty() then
              inv:set_stack('combs', i, 'bees:honey_comb') --add one comb
              if comb_counter == 4 then --4 comb slots were full and the last slot has just been filled
                meta:set_string('infotext', i18n('colony is ready to swarm'))
              else
                meta:set_string('infotext', i18n('colony is growing'))
              end
              timer:start(1000 / (growth_rate * bees_speedup)) --wait less if growth is fast
              return
            else
              comb_counter = comb_counter + 1
            end
          end
          --if no empty space for combs, then take one comb of honey and fly away
          inv:set_stack('combs', 5, '')
          bees.swarming(pos)
          meta:set_string('infotext', i18n('colony is growing'))--positive growth rate and one empty slot
          timer:start(1000 / (growth_rate * bees_speedup))
          return
        --if growth rate is 0, then nothing happens
        else
          meta:set_string('infotext', i18n('colony is not growing'))
          timer:start(1000 / bees_speedup)
        end
      --if the colony is dead, then remove hive
      else
        minetest.remove_node(pos)
        return
      end
      --new mechanics stops here
    end,
    on_construct = function(pos)
      bees.fill_new_wild_hive(pos)
    end,
    on_punch = function(pos, node, puncher)
      local meta = minetest.get_meta(pos)
      local inv = meta:get_inventory()
      if inv:contains_item('colony','bees:colony') then
        local health = puncher:get_hp()
        puncher:set_hp(health-4)
      end
    end,
    on_metadata_inventory_take = function(pos, listname, index, stack, taker)
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      local timer= minetest.get_node_timer(pos)
      if listname == 'combs' and inv:contains_item('colony', 'bees:colony') then
        local health = taker:get_hp()
        timer:start(10)
        taker:set_hp(health-2)
      elseif listname == 'colony' then
        meta:set_string('infotext', i18n('colony is missing'))
        timer:start(1000 / bees_speedup)
      end
    end,
    on_metadata_inventory_put = function(pos, listname, index, stack, taker) --restart the colony by adding a queen
      local flowers = bees.count_flowers_around(pos)
      local hives = bees.count_hives_around(pos)
      local growth_rate = bees.growth_rate(#flowers, #hives)
      if growth_rate < 0 then
        meta:set_string('infotext', i18n('colony is dying, not enough flowers around'))
      elseif growth_rate > 0 then
        meta:set_string('infotext', i18n('colony is growing'))
      else
        meta:set_string('infotext', i18n('colony is not growing'))
      end
      local timer = minetest.get_node_timer(pos)
      if not timer:is_started() then
        timer:start(1000 / bees_speedup)
      end
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
      if listname == 'colony' and stack:get_name() == 'bees:colony' then
        return 1
      else
        return 0
      end
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
      minetest.show_formspec(
        clicker:get_player_name(),
        'bees:hive_artificial',
        formspecs.hive_wild(pos, (itemstack:get_name() == 'bees:grafting_tool'))
      )
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      if meta:get_int('agressive') == 1 and inv:contains_item('colony', 'bees:colony') then
        local health = clicker:get_hp()
        clicker:set_hp(health-4)
      else
        meta:set_int('agressive', 1)
      end
    end,
    can_dig = function(pos,player)
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      if inv:is_empty('colony') and inv:is_empty('combs') then
        return true
      else
        return false
      end
    end,
    after_dig_node = function(pos, oldnode, oldmetadata, user)
      local inv = user:get_inventory()
      if inv then
        local rand = math.random(5)
        if rand == 1 then
          inv:add_item('main', ItemStack('bees:honey_comb')) --20% chance
        elseif rand == 2 then
          inv:add_item('main', ItemStack('wax')) --20% chance
        end
      end
    end
  })

  minetest.register_node('bees:hive_artificial', {
    description = i18n('Bee hive'),
    tiles = {'default_wood.png','default_wood.png','default_wood.png', 'default_wood.png','default_wood.png','bees_hive_artificial.png'},
    drawtype = 'nodebox',
    paramtype = 'light',
    paramtype2 = 'facedir',
    groups = {snappy=1,choppy=2,oddly_breakable_by_hand=2,flammable=3,wood=1, hives = 1},
    sounds = default.node_sound_wood_defaults(),
    node_box = {
      type = 'fixed',
      fixed = {
        {-4/8, 2/8, -4/8, 4/8, 3/8, 4/8},
        {-3/8, -4/8, -2/8, 3/8, 2/8, 3/8},
        {-3/8, 0/8, -3/8, 3/8, 2/8, -2/8},
        {-3/8, -4/8, -3/8, 3/8, -1/8, -2/8},
        {-3/8, -1/8, -3/8, -1/8, 0/8, -2/8},
        {1/8, -1/8, -3/8, 3/8, 0/8, -2/8},
      }
    },
    on_construct = function(pos)
      local timer = minetest.get_node_timer(pos)
      local meta = minetest.get_meta(pos)
      local inv = meta:get_inventory()
      meta:set_int('agressive', 1)
      inv:set_size('colony', 1)
      inv:set_size('frames', 8)
      meta:set_string('infotext', i18n('requires a bee colony to function'))
    end,
    on_rightclick = function(pos, node, clicker, itemstack)
      minetest.show_formspec(
        clicker:get_player_name(),
        'bees:hive_artificial',
        formspecs.hive_artificial(pos)
      )
      local meta = minetest.get_meta(pos)
      local inv  = meta:get_inventory()
      if meta:get_int('agressive') == 1 and inv:contains_item('colony', 'bees:colony') then
        local health = clicker:get_hp()
        clicker:set_hp(health-4)
      else
        meta:set_int('agressive', 1)
      end
    end,
    on_timer = function(pos)
      bees.hive_on_timer(pos)
    end,
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
      if listname == 'colony' then
        local timer = minetest.get_node_timer(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string('infotext', i18n('requires a bee colony to function'))
        timer:stop()
      end
    end,
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
      local inv = minetest.get_meta(pos):get_inventory()
      if from_list == to_list then 
        if inv:get_stack(to_list, to_index):is_empty() then
          return 1
        else
          return 0
        end
      else
        return 0
      end
    end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
      local meta = minetest.get_meta(pos)
      local inv = meta:get_inventory()
      local timer = minetest.get_node_timer(pos)
      if listname == 'colony' then --a colony was inserted
        local flowers = bees.count_flowers_around(pos)
        local hives = bees.count_hives_around(pos)
        local growth_rate = bees.growth_rate(#flowers, #hives)
        if growth_rate < 0 then --warn the player that the colony will die soon
          meta:set_string('infotext', i18n('colony is dying, not enough flowers around'))
          timer:start(1000 / bees_speedup)
          return
        else --colony survival is assured, let's look at frames
          if inv:contains_item('frames', 'bees:frame_empty') then
            meta:set_string('infotext', i18n('bees are aclimating'))
            timer:start(1000 / bees_speedup)
            return
          else
            meta:set_string('infotext', i18n('a colony is inserted, now for the empty frames'))
            timer:start(1000 / bees_speedup) --recheck later (growth_rate can turn negative)
            return
          end
        end
      elseif listname == 'frames' then --frames were inserted
        if inv:contains_item('colony', 'bees:colony') then --if the colony is already there, let's see growth rate
          local flowers = bees.count_flowers_around(pos)
          local hives = bees.count_hives_around(pos)
          local growth_rate = bees.growth_rate(#flowers, #hives)
          if growth_rate > 0 then --start working
            timer:start(30 / bees_speedup)
            meta:set_string('infotext', i18n('bees are aclimating'))
            return
          end
        else --the colony is not there
          timer:stop() --nothing to do
        end
      end
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
      if not minetest.get_meta(pos):get_inventory():get_stack(listname, index):is_empty() then return 0 end
      if listname == 'colony' then
        if stack:get_name():match('bees:colony*') then
          return 1
        end
      elseif listname == 'frames' then
        if stack:get_name() == ('bees:frame_empty') then
          return 1
        end
      end
      return 0
    end,
  })

--ABMS
  minetest.register_abm({ --particles
    nodenames = {'group:hives'},
    interval  = 10,
    chance    = 4,
    action = function(pos)
      minetest.add_particle({
        pos = {x=pos.x, y=pos.y, z=pos.z},
        velocity = {x=(math.random()-0.5)*5,y=(math.random()-0.5)*5,z=(math.random()-0.5)*5},
        acceleration = {x=math.random()-0.5,y=math.random()-0.5,z=math.random()-0.5},
        expirationtime = math.random(2.5),
        size = math.random(3),
        collisiondetection = true,
        texture = 'bees_particle_bee.png',
      })
    end,
  })

  minetest.register_abm({ --spontaneous spawning of wild hives
    nodenames = {'group:leaves'},
    neighbors = {''},
    interval = 1600,
    chance = 50,
    action = function(pos, node, _, _)
      local p = {x=pos.x, y=pos.y-1, z=pos.z} --spawn under leaves
      if minetest.get_node(p).walkable == false then return end
      local flowers = bees.count_flowers_around(pos) --5+ flowers needed for growth
      if (#flowers > 4 and minetest.find_node_near(p, 40, 'group:hives') == nil) then
        minetest.add_node(p, {name='bees:hive_wild'})
      end
    end,
  })

  minetest.register_abm({ --spawning bees around bee hive
    nodenames = {'group:hives'},
    neighbors = {'group:flowers', 'group:leaves'},
    interval = 30,
    chance = 4,
    action = function(pos, node, _, _)
      local p = {x=pos.x+math.random(-5,5), y=pos.y-math.random(0,3), z=pos.z+math.random(-5,5)}
      if minetest.get_node(p).name == 'air' then
        minetest.add_node(p, {name='bees:bees'})
      end
    end,
  })

  minetest.register_abm({ --remove bees
    nodenames = {'bees:bees'},
    interval = 30,
    chance = 5,
    action = function(pos, node, _, _)
      minetest.remove_node(pos)
    end,
  })

--ITEMS
  minetest.register_craftitem('bees:frame_empty', {
    description = i18n('Hive frame'),
    inventory_image = 'bees_frame_empty.png',
    stack_max = 24,
  })

  minetest.register_craftitem('bees:frame_full', {
    description = i18n('Hive frame with honey'),
    inventory_image = 'bees_frame_full.png',
    stack_max = 12,
  })

  minetest.register_craftitem('bees:bottle_honey', {
    description = i18n('Bottle with honey'),
    inventory_image = 'bees_bottle_honey.png',
    stack_max = 12,
    on_use = minetest.item_eat(3, "vessels:glass_bottle"),
  })
  
  minetest.register_craftitem('bees:wax', {
    description = i18n('Beeswax'),
    inventory_image = 'bees_wax.png',
    stack_max = 48,
  })

  minetest.register_craftitem('bees:honey_comb', {
    description = i18n('Honey comb'),
    inventory_image = 'bees_comb.png',
    on_use = minetest.item_eat(2),
    stack_max = 8,
  })

  minetest.register_craftitem('bees:colony', {
    description = i18n('A Bee Colony'),
    inventory_image = 'bees_particle_bee.png',
    stack_max = 1,
  })

--CRAFTS
  minetest.register_craft({
    output = 'bees:extractor',
    recipe = {
      {'','default:steel_ingot',''},
      {'default:steel_ingot','default:stick','default:steel_ingot'},
      {'default:mese_crystal','default:steel_ingot','default:mese_crystal'},
    }
  })

  minetest.register_craft({
    output = 'bees:smoker',
    recipe = {
      {'default:steel_ingot', 'wool:red', ''},
      {'', 'default:torch', ''},
      {'', 'default:steel_ingot',''},
    }
  })

  minetest.register_craft({
    output = 'bees:hive_artificial',
    recipe = {
      {'group:wood','group:wood','group:wood'},
      {'group:wood','default:stick','group:wood'},
      {'group:wood','default:stick','group:wood'},
    }
  })

  minetest.register_craft({
    output = 'bees:grafting_tool',
    recipe = {
      {'', '', 'default:steel_ingot'},
      {'', 'default:stick', ''},
      {'', '', ''},
    }
  })
  
  minetest.register_craft({
    output = 'bees:frame_empty',
    recipe = {
      {'group:wood',  'group:wood',  'group:wood'},
      {'default:stick', 'default:stick', 'default:stick'},
      {'default:stick', 'default:stick', 'default:stick'},
    }
  })

--TOOLS
  minetest.register_tool('bees:smoker', {
    description = i18n('Bee smoker'),
    inventory_image = 'bees_smoker.png',
    tool_capabilities = {
      full_punch_interval = 3.0,
      max_drop_level=0,
      damage_groups = {fleshy=2},
    },
    on_use = function(tool, user, node)
      if node then
        local pos = node.under
        if pos then
          for i=1,6 do
            minetest.add_particle({
              pos = {x=pos.x+math.random()-0.5, y=pos.y, z=pos.z+math.random()-0.5},
              velocity = {x=0,y=0.5+math.random(),z=0},
              acceleration = {x=0,y=0,z=0},
              expirationtime = 2+math.random(2.5),
              size = math.random(3),
              collisiondetection = false,
              texture = 'bees_smoke_particle.png',
            })
          end
          --tool:add_wear(2)
          local meta = minetest.get_meta(pos)
          meta:set_int('agressive', 0)
          return nil
        end
      end
    end,
  })

  minetest.register_tool('bees:grafting_tool', {
    description = i18n('Grafting tool'),
    inventory_image = 'bees_grafting_tool.png',
    tool_capabilities = {
      full_punch_interval = 3.0,
      max_drop_level=0,
      damage_groups = {fleshy=2},
    },
  })

--COMPATIBILTY --remove after all has been updated
  --ALIASES
  minetest.register_alias('bees:honey_extractor', 'bees:extractor')
  --BACKWARDS COMPATIBILITY WITH OLDER VERSION  
  minetest.register_alias('bees:queen', 'bees:colony')
  minetest.register_alias('bees:honey_bottle', 'bees:bottle_honey')
  minetest.register_abm({
    nodenames = {'bees:hive', 'bees:hive_artificial_inhabited'},
    interval = 0,
    chance = 1,
    action = function(pos, node)
      if node.name == 'bees:hive' then
        minetest.set_node(pos, { name = 'bees:hive_wild' })
        local meta = minetest.get_meta(pos)
        local inv  = meta:get_inventory()
        inv:set_stack('colony', 1, 'bees:colony')
      end
      if node.name == 'bees:hive_artificial_inhabited' then
        minetest.set_node(pos, { name = 'bees:hive_artificial' })
        local meta = minetest.get_meta(pos)
        local inv  = meta:get_inventory()
        inv:set_stack('colony', 1, 'bees:colony')
        local timer = minetest.get_node_timer(pos)
        timer:start(60)
      end
    end,
  })

  --PIPEWORKS
  if minetest.get_modpath("pipeworks") then
    minetest.register_node('bees:hive_industrial', {
      description = i18n('Industrial bee hive'),
      tiles = { 'bees_hive_industrial.png'},
      paramtype2 = 'facedir',
      groups = {snappy=1,choppy=2,oddly_breakable_by_hand=2,tubedevice=1,tubedevice_receiver=1, hives = 1},
      sounds = default.node_sound_wood_defaults(),
      tube = {
        insert_object = function(pos, node, stack, direction)
          local meta = minetest.get_meta(pos)
          local inv = meta:get_inventory()
          if stack:get_name() ~= "bees:frame_empty" or stack:get_count() > 1 then
            return stack
          end
          for i = 1, 8 do
            if inv:get_stack("frames", i):is_empty() then
              inv:set_stack("frames", i, stack)
              local timer = minetest.get_node_timer(pos)
              timer:start(30 / bees_speedup)
              meta:set_string('infotext',i18n('bees are aclimating'))
              return ItemStack("")
            end
          end
          return stack
        end,
        can_insert = function(pos,node,stack,direction)
          local meta = minetest.get_meta(pos)
          local inv = meta:get_inventory()
          if stack:get_name() ~= "bees:frame_empty" or stack:get_count() > 1 then
            return false
          end
          for i = 1, 8 do
            if inv:get_stack("frames", i):is_empty() then
              return true
            end
          end
          return false
        end,
        can_remove = function(pos,node,stack,direction)
          if stack:get_name() == "bees:frame_full" then
            return 1
          else
            return 0
          end
        end,
        input_inventory = "frames",
        connect_sides = {left=1, right=1, back=1, front=1, bottom=1, top=1}
      },
      on_construct = function(pos)
        local timer = minetest.get_node_timer(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        meta:set_int('agressive', 1)
        inv:set_size('colony', 1)
        inv:set_size('frames', 8)
        meta:set_string('infotext', i18n('requires a bee colony to function'))
      end,
      on_rightclick = function(pos, node, clicker, itemstack)
        minetest.show_formspec(
          clicker:get_player_name(),
          'bees:hive_artificial',
          formspecs.hive_artificial(pos)
        )
        local meta = minetest.get_meta(pos)
        local inv  = meta:get_inventory()
        if meta:get_int('agressive') == 1 and inv:contains_item('colony', 'bees:colony') then
          local health = clicker:get_hp()
          clicker:set_hp(health-4)
        else
          meta:set_int('agressive', 1)
        end
      end,
      on_timer = function(pos)
        bees.hive_on_timer(pos)
      end,
      on_metadata_inventory_take = function(pos, listname, index, stack, player)
        if listname == 'colony' then
          local timer = minetest.get_node_timer(pos)
          local meta = minetest.get_meta(pos)
          meta:set_string('infotext', i18n('requires a bee colony to function'))
          timer:stop()
        end
      end,
      allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        local inv = minetest.get_meta(pos):get_inventory()
        if from_list == to_list then 
          if inv:get_stack(to_list, to_index):is_empty() then
            return 1
          else
            return 0
          end
        else
          return 0
        end
      end,
      on_metadata_inventory_put = function(pos, listname, index, stack, player)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local timer = minetest.get_node_timer(pos)
        if listname == 'colony' then --a colony was inserted
          local flowers = bees.count_flowers_around(pos)
          local hives = bees.count_hives_around(pos)
          local growth_rate = bees.growth_rate(#flowers, #hives)
          if growth_rate < 0 then --warn the player that the colony will die soon
            meta:set_string('infotext', i18n('colony is dying, not enough flowers around'))
            timer:start(1000 / bees_speedup)
            return
          else --colony survival is assured, let's look at frames
            if inv:contains_item('frames', 'bees:frame_empty') then
              meta:set_string('infotext', i18n('bees are aclimating'))
              timer:start(1000 / bees_speedup)
              return
            else
              meta:set_string('infotext', i18n('a colony is inserted, now for the empty frames'))
              timer:start(1000 / bees_speedup) --recheck later (growth_rate can turn negative)
              return
            end
          end
        elseif listname == 'frames' then --frames were inserted
          if inv:contains_item('colony', 'bees:colony') then --if the colony is already there, let's see growth rate
            local flowers = bees.count_flowers_around(pos)
            local hives = bees.count_hives_around(pos)
            local growth_rate = bees.growth_rate(#flowers, #hives)
            if growth_rate > 0 then --start working
              timer:start(30 / bees_speedup)
              meta:set_string('infotext', i18n('bees are aclimating'))
              return
            end
          else --the colony is not there
            timer:stop() --nothing to do
          end
        end
      end,
      allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        if not minetest.get_meta(pos):get_inventory():get_stack(listname, index):is_empty() then return 0 end
        if listname == 'colony' then
          if stack:get_name():match('bees:colony*') then
            return 1
          end
        elseif listname == 'frames' then
          if stack:get_name() == ('bees:frame_empty') then
            return 1
          end
        end
        return 0
      end,
    })
    minetest.register_craft({
      output = 'bees:hive_industrial',
      recipe = {
        {'default:steel_ingot','homedecor:plastic_sheeting','default:steel_ingot'},
        {'pipeworks:tube_1','bees:hive_artificial','pipeworks:tube_1'},
        {'default:steel_ingot','homedecor:plastic_sheeting','default:steel_ingot'},
      }
    })
  end

minetest.log('action', 'MOD: Bees version ' .. bees_version .. ' loaded.')
