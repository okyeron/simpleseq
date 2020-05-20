-- ~~ simpleseq ~~
--
-- performable sequencer
-- inspired by the korg sq-1
--
-- ENC1 sequencer mode
-- ENC2 editor index
-- ENC3 note entry
--
-- KEY1 alt
--
-- KEY2 toggle active
-- KEY3 toggle gate
--
-- alt+KEY2 init sequence
-- alt+KEY3 random sequence
--
-- TODOS:
-- * Quantize to scale
-- * Clean up drawing code
-- * MIDI output, and MIDI note input

-----------------------------
-- INCLUDES, ETC.
-----------------------------

local MusicUtil = require "musicutil"
local Passersby = require "passersby/lib/passersby_engine"
local hs = require "awake/lib/halfsecond"

engine.name = "Passersby"

-----------------------------
-- STATE
-----------------------------

local foreground_level = 15
local background_level = 5
local disabled_level = 5
  
local steps = {}
local mode = 1
local mode_names = {"classic", "zig", "rand"}
local base_note = 41
local max_note = 36
local edit = 1
local index = 1
local alt = false

-----------------------------
-- SETUP
-----------------------------

function init()
  init_steps()
  randomize_steps()
  
  setup_engine()
  setup_clock()
end

function setup_engine()
  -- Setup synth.
  params:add_separator()
  Passersby.add_params()
  
  -- Setup delay.
  hs.init()
  params:set("delay", 0.35)
  params:set("delay_feedback", 0.5)
end

function setup_clock()
  clock.run(tick)
end

function init_steps()
  steps.notes = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  steps.gates = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  steps.actives = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
end

function randomize_steps()
  for i=1, #steps.notes do
    steps.notes[i] = math.random(0, max_note)
    steps.actives[i] = math.random(0, 1)
    steps.gates[i] = math.random(0, 1)
  end
end

-----------------------------
-- SEQUENCER
-----------------------------

function tick()
  while true do
    clock.sync(1/4)
    
    untrigger_last_step()
    find_next_step()
    trigger_current_step()
    
    redraw()
  end
end

function find_next_step()
  name = mode_names[mode]
  
  -- Find next step.
  if name == "classic" then
    index = index % 16 + 1
  elseif name == "zig" then
    index = util.clamp(index > 8 and index % 16 - 7 or index % 16 + 8, 1, 16)
  elseif name == "rand" then
    index = math.random(1, 16)
  end
  
  -- Skip step if inactive...
  if steps.actives[index] == 0 then
    find_next_step()
  end
end

function untrigger_last_step()
  engine.noteOffAll()
end

function trigger_current_step()
  if steps.gates[index] == 1 then
    note = base_note + steps.notes[index]
    engine.noteOn(note, MusicUtil.note_num_to_freq(note), 1)
  end
end

-----------------------------
-- INPUT HANDLING
-----------------------------

function key(n, z)
  if n == 1 then
    if z > 0 then
      alt = true
    else
      alt = false
    end
  elseif n == 2 and z == 1 then
    if alt then
      init_steps()
    else
      steps.actives[edit] = 1 - steps.actives[edit]
    end
  elseif n == 3 and z == 1 then
    if alt then
      randomize_steps()
    else
      steps.gates[edit] = 1 - steps.gates[edit]
    end
  end
  
  redraw()
end

function enc(n, d)
  if n == 1 then
    mode = util.clamp(mode + d, 1, #mode_names)
  elseif n == 2 then
    edit = util.clamp(edit + d, 1, #steps.notes)
  elseif n == 3 then
    steps.notes[edit] = util.clamp(steps.notes[edit] + d, 0, max_note)
  end
  
  redraw()
end

-----------------------------
-- DRAWING
-----------------------------

function redraw()
  screen.clear()
  draw_steps()
  draw_modes()
  draw_editor()
  screen.update()
end

function draw_steps()
  box_size = 10
  x = 1

  for row=1,2 do
    for col=1,8 do
      if steps.actives[x] == 1 then
        -- Drawing for active-enabled steps.
        screen.level(steps.gates[x] == 1 and 5 or 1)
        screen.rect((box_size + 4) * (col - 1) + 1, (box_size + 4) * (row - 1) + 6, box_size, box_size)
        screen.stroke()
        
        -- Drawing for currently active, if needed.
        if x == index then
          inside_box_size = box_size - 3
          screen.rect(14 * (col - 1) + 2, 14 * (row - 1) + 7, 7, 7)
          screen.fill()
        end
      else
        -- Drawing for inactive steps.
        screen.level(1)
        screen.move(14 * (col - 1), 14 * (row - 1) + 6 + 10)
        screen.line(14 * (col - 1) + 11, 14 * (row - 1) + 6 + 10)
        screen.stroke()
      end
      
      -- Editor cursor.
      if x == edit then 
        screen.level(foreground_level)
        screen.move(14 * (col - 1), 14 * (row - 1) + 6 + 10)
        screen.line(14 * (col - 1) + 11, 14 * (row - 1) + 6 + 10)
        screen.stroke()
        
        screen.move(14 * (col - 1), 14 * (row - 1) + 6 + 11)
        screen.line(14 * (col - 1) + 11, 14 * (row - 1) + 6 + 11)
        screen.stroke()
      end
      
      x = x + 1
    end
  end
end

function draw_modes()
  screen.move(1, 40)
  screen.level(foreground_level)
  screen.text("mode: ")
  
  for m=1,#mode_names do
    screen.level(m == mode and foreground_level or disabled_level)
    screen.text(mode_names[m] .. " ")
  end
end

function draw_editor()
  note = steps.notes[edit]
  gate = steps.gates[edit]
  active = steps.actives[edit]

  screen.move(1, 50)
  screen.level(foreground_level)
  screen.text("note: ")
  screen.level(background_level)
  screen.text(note)
  
  screen.move(1, 60)
  screen.level(foreground_level)
  screen.text("active: ")
  screen.level(background_level)
  screen.text(bool_to_string(active))
  
  screen.move(55, 60)
  screen.level(foreground_level)
  screen.text("gate: ")
  screen.level(background_level)
  screen.text(bool_to_string(gate))
end

-----------------------------
-- UTILITY
-----------------------------

function bool_to_string(b)
  return b == 1 and "yes" or "no"
end
