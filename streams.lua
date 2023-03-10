-- ~~~~~~~~~ streams ~~~~~~~~
--
-- ~~a multi playhead sequencer
--
-- 1.1.0 @sonocircuit
-- llllllll.co/t/?????
--
--
-- for docs go to:
-- >> github.com
--    /sonocircuits/streams
--
-- or smb into:
-- >> code/streams/docs
--
--
--        ~~~~~~~~~~~~
--          ~~~~~
--             ~~~~~~~~~
--                ~~~
--
--

engine.name = "Moonshine"

local softsync = include('lib/streams_softsync')
local format = require 'formatters'

local mu = require "musicutil"

local g = grid.connect()


-------- variables --------
local pset_load = false
local default_pset = 6

local pageNum = 1
local edit = 1
local p_set = 1
local t_set = 1
local tp_set = 1
local focus = 1

local alt = false
local mod = false
local shift = false
local set_start = false
local set_end = false
local set_loop = false
local set_rate = false
local set_oct = false
local set_trsp = false
local altgrid = false
local viewinfo = 0
local freeze = 0

local transport = 0
local transport_tog = 0

local v8_std_1 = 12
local v8_std_2 = 12
local env1_amp = 8
local env1_a = 0
local env1_d = 0.4
local env2_a = 0
local env2_d = 0.4
local env2_amp = 8


-------- tables --------
local scale_names = {}
local scale_notes = {}

local options = {}
options.rate_val = {"2", "1", "3/4", "2/3", "1/2", "3/8", "1/3", "1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/32"}
options.rate_num = {2, 1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 3/64, 1/32}
options.direction = {"fwd", "rev"}
options.dir_mode = {"normal", "pendulum", "random"}
options.rnd_mode = {"jump", "drunk"}
options.gbl_out = {"per track", "moonshine", "midi", "crow ii jf", "crow ii wsyn"}
options.ind_out = {"moonshine", "midi", "crow 1+2", "crow 3+4", "crow ii jf", "crow ii wsyn"}
options.octave = {-3, -2, -1, 0, 1, 2, 3}
options.pages = {"SEQUENCE", "TRACK   PLAYHEAD", "TRACK   SOUND", "DELAY"}
options.tracks = {"off", "track 1", "track 2", "track 3", "track 4"}

local pattern = {}
pattern.notes = {}
pattern.rests = {}
for i = 1, 4 do -- 4 note and rest presets
  pattern.notes[i] = {}
  pattern.rests[i] = {}
  for j = 1, 16 do
    table.insert(pattern.notes[i], j, math.random(1, 20))
    table.insert(pattern.rests[i], j, 0)
  end
end

local track = {}
for i = 1, 4 do -- 4 tracks
  track[i] = {}
  track[i].loop_start = 1
  track[i].loop_end = 16
  track[i].loop_len = 16
  track[i].pos = 1
  track[i].note_prob = 100
  track[i].step_prob = 100
  track[i].rate = 1
  track[i].dir = 0
  track[i].dir_mode = 0
  track[i].octave = 0
  track[i].transpose = 0
  track[i].running = false
  track[i].reset = false
  track[i].track_out = 1
end

local set = {}
for i = 1, 4 do -- 4 tracks
  set[i] = {}
  set[i].loop_start = {}
  set[i].loop_end = {}
  set[i].rate = {}
  set[i].dir = {}
  set[i].dir_mode = {}
  set[i].octave = {}
  set[i].transpose = {}
  set[i].note_prob = {}
  set[i].step_prob = {}
  for j = 1, 4 do -- 4 presets
    set[i].loop_start[j] = 1
    set[i].loop_end[j] = 16
    set[i].rate[j] = 8
    set[i].dir[j] = 2
    set[i].dir_mode[j] = 0
    set[i].octave[j] = 4
    set[i].transpose[j] = 8
    set[i].note_prob[j] = 100
    set[i].step_prob[j] = 100
  end
end

local set_midi = {}
for i = 1, 4 do -- 4 tracks
  set_midi[i] = {}
  set_midi[i].ch = 1
  set_midi[i].vel = 100
  set_midi[i].vel_hi = 120
  set_midi[i].vel_lo = 80
  set_midi[i].vel_range = 20
  set_midi[i].velocity = 100
  set_midi[i].active_notes = {}
end

local set_crow = {}
for i = 1, 4 do -- 4 tracks
  set_crow[i] = {}
  set_crow[i].jf_ch = i
  set_crow[i].jf_amp = 5
  set_crow[i].wsyn_amp = 5
end

local m = {}
for i = 0, 4 do
  m[i] = midi.connect()
end

local held = {}
local heldmax = {}
local first = {}
local second = {}
for i = 1, 4 do
  held[i] = 0
  heldmax[i] = 0
  first[i] = 0
  second[i] = 0
end


-------- track settings --------
function build_scale()
  scale_notes = mu.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 20)
  local num_to_add = 20 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[20 - num_to_add])
  end
end

function set_track_output()
  local glb_out = params:get("global_out")
  for i = 1, 4 do
    if glb_out == 1 then
      track[i].track_out = params:get("track_out"..i)
    elseif glb_out == 2 then
      track[i].track_out = 1
    elseif glb_out == 3 then
      track[i].track_out = 2
      params:set("track_midi_device"..i, params:get("global_midi_device"))
      params:set("track_midi_channel"..i, params:get("global_midi_channel"))
    elseif glb_out == 4 then
      track[i].track_out = 5
      params:set("jf_mode"..i, 2)
    elseif glb_out == 5 then
      track[i].track_out = 6
      crow.ii.wsyn.voices(4)
    end
  end
  if glb_out == 4 then
    crow.ii.pullup(true)
    crow.ii.jf.mode(1)
  else
    local count = 0
    for i = 1, 4 do
      if params:get("track_out"..i) == 5 then
        count = count + 1
      end
    end
    if count > 0 then
      crow.ii.pullup(true)
      crow.ii.jf.mode(1)
    else
      crow.ii.jf.mode(0)
    end
  end
end

function set_loop_start(i, startpoint)
  track[i].loop_start = startpoint
  if track[i].loop_start >= track[i].loop_end then
    params:set("loop_end"..i, track[i].loop_start)
  end
  page_redraw(2)
end

function set_loop_end(i, endpoint)
  track[i].loop_end = endpoint
  if track[i].loop_end <= track[i].loop_start then
    params:set("loop_start"..i, track[i].loop_end)
  end
  page_redraw(2)
end


-------- midi --------
function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function midi_connect() -- MIDI register callback
  build_midi_device_list()
end

function midi_disconnect() -- MIDI remove callback
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

function clock.transport.start()
  if params:get("midi_trnsp") == 3 then
    for i = 1, 4 do
      if params:get("midi_trnsp_enable"..i) == 2 then
        track[i].running = true
      end
    end
    transport = 1
  end
end

function clock.transport.stop()
  if params:get("midi_trnsp") == 3 then
    for i = 1, 4 do
      track[i].running = false
      reset_pos()
      notes_off(i)
    end
    transport = 1
  end
  page_redraw(1)
  dirtygrid = true
end

function notes_off(i)
  for _, a in pairs(set_midi[i].active_notes) do
    m[i]:note_off(a, nil, set_midi[i].ch)
  end
  set_midi[i].active_notes = {}
end

function all_notes_off()
  for i = 1, 4 do
    for _, a in pairs(set_midi[i].active_notes) do
      m[i]:note_off(a, nil, set_midi[i].ch)
    end
    set_midi[i].active_notes = {}
  end
end

function set_velocity(i)
  set_midi[i].vel_hi = util.clamp(set_midi[i].vel + set_midi[i].vel_range, 1, 127)
  set_midi[i].vel_lo = util.clamp(set_midi[i].vel - set_midi[i].vel_range, 1, 127)
  page_redraw(3)
end


-------- defaults and presets --------
function set_defaults()
  -- track 1
  params:set("loop_start"..1, 3)
  params:set("loop_end"..1, 13)
  params:set("rate"..2, 14)
  -- track 2
  params:set("loop_start"..2, 4)
  params:set("loop_end"..2, 9)
  params:set("rate"..2, 13)
  params:set("octave"..2, 5)
  params:set("transpose"..2, 2)
  -- track 3
  params:set("loop_start"..3, 7)
  params:set("loop_end"..3, 14)
  params:set("rate"..3, 6)
  params:set("transpose"..3, 4)
  -- track 4
  params:set("loop_start"..4, 9)
  params:set("loop_end"..4, 11)
  params:set("rate"..4, 3)
  params:set("octave"..4, 3)
  for i = 1, 4 do
    track[i].pos = track[i].loop_start
  end
  -- presets
  clock.run(
  function()
    clock.sleep(0.2)
    for i = 1, 4 do
      save_track_data(i)
    end
  end)
end

-- save preset
function save_track_data(n)
  for i = 1, 4 do
    set[i].loop_start[n] = params:get("loop_start"..i)
    set[i].loop_end[n] = params:get("loop_end"..i)
    set[i].rate[n] = params:get("rate"..i)
    set[i].dir[n] = params:get("direction"..i)
    set[i].dir_mode[n] = params:get("step_mode"..i)
    set[i].octave[n] = params:get("octave"..i)
    set[i].transpose[n] = params:get("transpose"..i)
    set[i].note_prob[n] = params:get("n_probability"..i)
    set[i].step_prob[n] = params:get("s_probability"..i)
  end
end

-- load preset
function load_track_data()
  for i = 1, 4 do
    params:set("loop_start"..i, set[i].loop_start[t_set])
    params:set("loop_end"..i, set[i].loop_end[t_set])
    params:set("rate"..i, set[i].rate[t_set])
    params:set("direction"..i, set[i].dir[t_set])
    params:set("step_mode"..i, set[i].dir_mode[t_set])
    params:set("octave"..i, set[i].octave[t_set])
    params:set("transpose"..i, set[i].transpose[t_set])
    params:set("n_probability"..i, set[i].note_prob[t_set])
    params:set("s_probability"..i, set[i].step_prob[t_set])
    if not track[i].running then
      track[i].pos = track[i].loop_start
      track[i].reset = true
    end
  end
  dirtygrid = true
  dirtyscreen = true
end


-------- utils --------
function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end


-------- init function --------
function init()

  -- populate scale_names table
  for i = 1, #mu.SCALES do
    table.insert(scale_names, string.lower(mu.SCALES[i].name))
  end

  -- scale params
  params:add_separator("global_settings", "global settings")

  params:add_option("global_out", "output", options.gbl_out, 1)
  params:set_action("global_out", function() set_track_output() build_menu() end)

  params:add_option("scale_mode", "scale", scale_names, 5)
  params:set_action("scale_mode", function() build_scale() end)

  params:add_number("root_note", "root note", 24, 84, 48, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", function() build_scale() end)

  params:add_option("loop_set_keys", "quick loop set", {"no", "yes"}, 1)

  -- midi params
  build_midi_device_list()

  params:add_group("global_midi_params", "global midi", 3)

  params:add_option("global_midi_device", "midi device", midi_devices, 1)
  params:set_action("global_midi_device", function(val) m[0] = midi.connect(val) set_track_output() end)

  params:add_number("global_midi_channel", "midi channel", 1, 16, 1)
  params:set_action("global_midi_channel", function(val) all_notes_off() set_track_output() end)

  params:add_option("midi_trnsp", "midi transport", {"off", "send", "receive"}, 1)

  -- track params
  params:add_separator("tracks", "tracks")
  for i = 1, 4 do
    params:add_group("track_"..i, "track "..i, 37)

    params:add_separator("output_"..i, "output")
    params:add_option("track_out"..i, "output", options.ind_out, 1)
    params:set_action("track_out"..i, function() set_track_output() build_menu() end)

    params:add_binary("track_transport"..i, "run/stop", "trigger")
    params:set_action("track_transport"..i, function() transport_track(i) end)

    -- moonshine params
    params:add_separator("moon_synthesis"..i, "moonshine settings")
    -- amp
    params:add_control("moon_amp"..i, "level", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("moon_amp"..i, function(x) engine.amp(i, x / 2) end) 
    -- sub division
    params:add_number("moon_sub_div"..i, "sub division", 1, 10, 1)
    params:set_action("moon_sub_div"..i, function(x) engine.sub_div(i, x) end)
    -- noise level
    params:add_control("moon_noise_amp"..i, "noise level", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get() * 50, 1, "%")) end)
    params:set_action("moon_noise_amp"..i, function(x) engine.noise_amp(i, x) end)
    -- cutoff
    params:add_control("moon_cutoff"..i, "cutoff", controlspec.new(20, 20000, "exp", 0, 1200), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("moon_cutoff"..i, function(x) engine.cutoff(i, x) page_redraw(3) end)
    -- filter env
    params:add_number("moon_cutoff_env"..i, "filter env", 0, 1, 0, function(param) return (param:get() == 1 and "on" or "off") end)
    params:set_action("moon_cutoff_env"..i, function(x) engine.cutoff_env(i, x) end)
    -- resonance
    params:add_control("moon_resonance"..i, "filter q", controlspec.new(0, 4, "lin", 0, 0.8), function(param) return (round_form(util.linlin(0, 4, 0, 100, param:get()), 1, "%")) end)
    params:set_action("moon_resonance"..i, function(x) engine.resonance(i, x) page_redraw(3) end)
    -- attack
    params:add_control("moon_attack"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("moon_attack"..i, function(x) engine.attack(i, x) page_redraw(3) end)
    -- release
    params:add_control("moon_release"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.3), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("moon_release"..i, function(x) engine.release(i, x) page_redraw(3) end)
    -- pan
    params:add_control("moon_pan"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0), format.bipolar_as_pan_widget)
    params:set_action("moon_pan"..i, function(x) engine.pan(i, x) end)

    -- midi params
    params:add_separator("midi_params_"..i, "midi settings")

    params:add_option("track_midi_device"..i, "midi device", midi_devices, 1)
    params:set_action("track_midi_device"..i, function(val) m[i] = midi.connect(val) page_redraw(3) end)

    params:add_number("track_midi_channel"..i, "midi channel", 1, 16, 1)
    params:set_action("track_midi_channel"..i, function(val) notes_off(i) set_midi[i].ch = val page_redraw(3) end)

    params:add_option("vel_mode"..i, "velocity mode", {"fixed", "random"}, 1)
    params:set_action("vel_mode"..i, function() set_velocity(i) end)

    params:add_number("midi_vel_val"..i, "velocity value", 1, 127, 100)
    params:set_action("midi_vel_val"..i, function(val) set_midi[i].vel = val set_velocity(i) end)

    params:add_number("midi_vel_range"..i, "velocity range ±", 1, 127, 20)
    params:set_action("midi_vel_range"..i, function(val) set_midi[i].vel_range = val set_velocity(i) end)

    -- jf params
    params:add_separator("jf_params_"..i, "jf settings")

    params:add_option("jf_mode"..i, "jf_mode", {"vox", "note"}, 1)
    params:set_action("jf_mode"..i, function() build_menu() page_redraw(3) end)

    params:add_number("jf_voice"..i, "jf voice", 1, 6, i)
    params:set_action("jf_voice"..i, function(num) set_crow[i].jf_ch = num page_redraw(3) end)

    params:add_control("jf_amp"..i, "jf level", controlspec.new(0, 10, "lin", 0, 8.0, "vpp"))
    params:set_action("jf_amp"..i, function(v) set_crow[i].jf_amp = v page_redraw(3) end)

    -- playhead params
    params:add_separator("playhead_"..i, "playhead")

    params:add_number("s_probability"..i, "step probability", 0, 100, 100, function(param) return (param:get().."%") end)
    params:set_action("s_probability"..i, function(x) track[i].step_prob = x page_redraw(2) end)

    params:add_option("rate"..i, "rate", options.rate_val, 8)
    params:set_action("rate"..i, function(idx) track[i].rate = options.rate_num[idx] * 4 page_redraw(2) end)

    params:add_option("direction"..i, "direction", options.direction, 1)
    params:set_action("direction"..i, function(x) track[i].dir = x - 1 page_redraw(2) dirtygrid = true end)

    params:add_option("step_mode"..i, "step mode", options.dir_mode, 1)
    params:set_action("step_mode"..i, function(x) track[i].dir_mode = x - 1 page_redraw(2) dirtygrid = true end)

    params:add_option("rnd_mode"..i, "random mode", options.rnd_mode, 1)

    -- sequence params
    params:add_separator("sequence_"..i, "sequence")
    params:add_number("n_probability"..i, "note probability", 0, 100, 100, function(param) return (param:get().."%") end)
    params:set_action("n_probability"..i, function(x) track[i].note_prob = x page_redraw(2) end)

    params:add_option("octave"..i, "octave",  options.octave, 4)
    params:set_action("octave"..i, function(idx) track[i].octave = options.octave[idx] page_redraw(2) end)

    params:add_number("transpose"..i, "transpose", -7, 7, 0, function(param) return (param:get().." deg") end)
    params:set_action("transpose"..i, function(x) track[i].transpose = x page_redraw(2) end)

    params:add_number("loop_start"..i, "start position", 1, 16, 1)
    params:set_action("loop_start"..i, function(x) set_loop_start(i, x) dirtygrid = true end)

    params:add_number("loop_end"..i, "end position", 1, 16, 16)
    params:set_action("loop_end"..i, function(x) set_loop_end(i, x) dirtygrid = true end)

    params:add_option("track_reset"..i, "position reset", options.tracks, 1)
    params:hide("track_reset"..i)

    params:add_option("midi_trnsp_enable"..i, "midi start msg", {"ignore", "follow"}, 2)

  end
  
  -- crow params
  params:add_separator("crow", "crow")

  params:add_group("out 1+2", 4)
  params:add_option("v8_type_1", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_1", function(x) if x == 1 then v8_std_1 = 12 else v8_std_1 = 10 end page_redraw(3) end)

  params:add_control("env1_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env1_amplitude", function(value) env1_amp = value page_redraw(3) end)

  params:add_control("env1_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_a = value page_redraw(3) end)

  params:add_control("env1_decay", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env1_decay", function(value) env1_d = value page_redraw(3) end)

  params:add_group("out 3+4", 4)
  params:add_option("v8_type_2", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_2", function(x) if x == 1 then v8_std_2 = 12 else v8_std_2 = 10 end page_redraw(3) end)

  params:add_control("env2_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env2_amplitude", function(value) env2_amp = value page_redraw(3) end)

  params:add_control("env2_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_a = value page_redraw(3) end)

  params:add_control("env2_decay", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env2_decay", function(value) env2_d = value page_redraw(3) end)

  params:add_group("wsyn_params", "wsyn", 10)
 
  params:add_option("wysn_mode", "wsyn mode", {"hold", "lpg"}, 2)
  params:set_action("wysn_mode", function(mode) crow.ii.wsyn.ar_mode(mode - 1) end)

  params:add_control("wsyn_amp", "level", controlspec.new(0, 10, "lin", 0, 5, "vpp"))
  params:set_action("wsyn_amp", function(level) set_crow[1].wsyn_amp = level end)
  
  params:add_control("wsyn_curve", "curve",  controlspec.new(-5, 5, "lin", 0, 5, "v"))
  params:set_action("wsyn_curve", function(v) crow.ii.wsyn.curve(v) page_redraw(3) end)
  
  params:add_control("wsyn_ramp", "ramp", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_ramp", function(v) crow.ii.wsyn.ramp(v) page_redraw(3) end)
  
  params:add_control("wsyn_lpg_time", "lpg time", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_lpg_time", function(v) crow.ii.wsyn.lpg_time(v) page_redraw(3) end)
  
  params:add_control("wsyn_lpg_sym", "lpg symmetry", controlspec.new(-5, 5, "lin", 0, -5, "v"))
  params:set_action("wsyn_lpg_sym", function(v) crow.ii.wsyn.lpg_symmetry(v) page_redraw(3) end)
  
  params:add_control("wsyn_fm_index", "fm index", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_fm_index", function(v) crow.ii.wsyn.fm_index(v) end)
  
  params:add_control("wsyn_fm_env", "fm envelope", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_fm_env", function(v) crow.ii.wsyn.fm_env(v) end)
  
  params:add_number("wsyn_fm_num", "fm ratio num", 1, 16, 1, function(param) return (param:get().."/"..params:get("wsyn_fm_den")) end)
  params:set_action("wsyn_fm_num", function(num) crow.ii.wsyn.fm_ratio(num, params:get("wsyn_fm_den")) end)
  
  params:add_number("wsyn_fm_den", "fm ratio denom", 1, 16, 2, function(param) return (params:get("wsyn_fm_num").."/"..param:get()) end)
  params:set_action("wsyn_fm_den", function(denom) crow.ii.wsyn.fm_ratio(params:get("wsyn_fm_num"), denom) end)

  params:add_separator("delay_params", "delay")
  softsync.init()

  -- bang params
  if pset_load then
    params:read(default_pset)
  else
    params:bang()
  end

  set_defaults()
  transport_all()
  reset_pos()

  -- metros
  gridredrawtimer = metro.init(grid_redraw, 1/30, -1)
  gridredrawtimer:start()
  dirtygrid = true

  screenredrawtimer = metro.init(screen_redraw, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  -- clocks
  for i = 1, 4 do
    clock.run(step, i)
  end

  -- hardware callbacks
  grid.add = drawgrid_connect
  midi.add = midi_connect
  midi.remove = midi_disconnect

  -- pset callback
  params.action_write = function(filename, name)

    save_track_data(t_set)

    local pset_string = string.sub(filename, string.len(filename) - 6, -1)
    local number = pset_string:gsub(".pset", "")

    os.execute("mkdir -p "..norns.state.data.."presets/"..number.."/")

    local pset_data = {}
    pset_data.note_pset = p_set
    pset_data.track_pset = t_set
    pset_data.prevtrack_pset = tp_set
    for i = 1, 4 do
      pset_data[i] = {}
      pset_data[i].notes = {table.unpack(pattern.notes[i])}
      pset_data[i].rests = {table.unpack(pattern.rests[i])}
      pset_data[i].loop_start = {table.unpack(set[i].loop_start)}
      pset_data[i].loop_end = {table.unpack(set[i].loop_end)}
      pset_data[i].rate = {table.unpack(set[i].rate)}
      pset_data[i].dir = {table.unpack(set[i].dir)}
      pset_data[i].dir_mode = {table.unpack(set[i].dir_mode)}
      pset_data[i].octave = {table.unpack(set[i].octave)}
      pset_data[i].transpose = {table.unpack(set[i].transpose)}
      pset_data[i].note_prob = {table.unpack(set[i].note_prob)}
      pset_data[i].step_prob = {table.unpack(set[i].step_prob)}
    end
    tab.save(pset_data, norns.state.data.."presets/"..number.."/"..name.."_pset.data")
    print("finished writing '"..filename.."' as '"..name.."'")
  end

  params.action_read = function(filename)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      local pset_string = string.sub(filename, string.len(filename) - 6, -1)
      local number = pset_string:gsub(".pset", "")

      local pset_data = tab.load(norns.state.data.."presets/"..number.."/"..pset_id.."_pset.data")
      p_set = pset_data.note_pset
      t_set = pset_data.track_pset
      tp_set = pset_data.prevtrack_pset
      for i = 1, 4 do
        pattern.notes[i] = {table.unpack(pset_data[i].notes)}
        pattern.rests[i] = {table.unpack(pset_data[i].rests)}
        set[i].loop_start = {table.unpack(pset_data[i].loop_start)}
        set[i].loop_end = {table.unpack(pset_data[i].loop_end)}
        set[i].rate = {table.unpack(pset_data[i].rate)}
        set[i].dir = {table.unpack(pset_data[i].dir)}
        set[i].dir_mode = {table.unpack(pset_data[i].dir_mode)}
        set[i].octave = {table.unpack(pset_data[i].octave)}
        set[i].transpose = {table.unpack(pset_data[i].transpose)}
        set[i].note_prob = {table.unpack(pset_data[i].note_prob)}
        set[i].step_prob = {table.unpack(pset_data[i].step_prob)}
      end
      load_track_data()
      dirtygrid = true
      dirtyscreen = true
      print("finished reading '"..filename.."'")
    end
  end
end


-------- sequencer --------
function step(i)
  while true do
    clock.sync(track[i].rate)
    notes_off(i)
    if track[i].running then
      -- step playhead
      if track[i].dir_mode == 2 and params:get("rnd_mode"..i) == 1 then
        track[i].pos = math.random(track[i].loop_start, track[i].loop_end)
        dirtygrid = true
        page_redraw(1)
      else
        if track[i].dir == 0 then
          if math.random(100) <= track[i].step_prob then
            track[i].pos = track[i].pos + 1
          end
          if params:get("rnd_mode"..i) == 2 and track[i].dir_mode == 2 then
            params:set("direction"..i, math.random(1, 2))
          end
          if (track[i].pos > track[i].loop_end or track[i].reset) then
            if track[i].dir_mode == 1 then
              params:set("direction"..i, 2)
              track[i].pos = track[i].loop_end - 1
            else
              track[i].pos = track[i].loop_start
            end
            track[i].reset = false
            for j = 1, 4 do
              if params:get("track_reset"..j) - 1  == i then
                track[j].reset = true
              end
            end
          end
        elseif track[i].dir == 1 then
          if math.random(100) <= track[i].step_prob then
            track[i].pos = track[i].pos - 1
          end
          if params:get("rnd_mode"..i) == 2 and track[i].dir_mode == 2 then
            params:set("direction"..i, math.random(1, 2))
          end
          if (track[i].pos < track[i].loop_start or track[i].reset) then
            if track[i].dir_mode == 1 then
              params:set("direction"..i, 1)
              track[i].pos = track[i].loop_start + 1
            else
              track[i].pos = track[i].loop_end
            end
            track[i].reset = false
            for j = 1, 4 do
              if params:get("track_reset"..j) - 1 == i then
                track[j].reset = true
              end
            end
          end
        end
        page_redraw(1)
        dirtygrid = true
      end
      -- send midi start msg
      if params:get("midi_trnsp") == 2 and transport_tog == 0 then
        m[0]:start()
        transport_tog = 1
      end
      -- play notes
      if math.random(100) <= track[i].note_prob then
        if pattern.rests[p_set][track[i].pos] < 1 then
          play_voice(i)
        end
      end
    end
  end
end

function play_voice(i)
  local note_num = scale_notes[util.clamp(pattern.notes[p_set][track[i].pos] + track[i].transpose,1, 20)] + track[i].octave * 12
  local freq = mu.note_num_to_freq(note_num)
  -- engine output
  if track[i].track_out == 1 then
    engine.trig(i, freq)
  -- midi output
  elseif track[i].track_out == 2 then
    if params:get("vel_mode"..i) == 2 then
      set_midi[i].velocity = math.random(set_midi[i].vel_lo, set_midi[i].vel_hi)
    else
      set_midi[i].velocity = set_midi[i].vel
    end
    m[i]:note_on(note_num, set_midi[i].velocity, set_midi[i].ch)
    table.insert(set_midi[i].active_notes, note_num)
  -- crow output 1+2
  elseif track[i].track_out == 3 then
    crow.output[1].volts = ((note_num - 60) / v8_std_1)
    crow.output[2].action = "{ to(0, 0), to("..env1_amp..", "..env1_a.."), to(0, "..env1_d..", 'log') }"
    crow.output[2]()
  -- crow output 3+4
  elseif track[i].track_out == 4 then
    crow.output[3].volts = ((note_num - 60) / v8_std_2)
    crow.output[4].action = "{ to(0, 0), to("..env2_amp..", "..env2_a.."), to(0, "..env2_d..", 'log') }"
    crow.output[4]()
  -- crow ii jf
  elseif track[i].track_out == 5 then
    if params:get("jf_mode"..i) == 1 then
      crow.ii.jf.play_voice(set_crow[i].jf_ch, ((note_num - 60) / 12), set_crow[i].jf_amp)
    else
      crow.ii.jf.play_note(((note_num - 60) / 12), set_crow[i].jf_amp)
    end
  elseif track[i].track_out == 6 then
    crow.ii.wsyn.play_voice(i, ((note_num - 60) / 12), set_crow[1].wsyn_amp)
  end
end

function transport_all()
  if transport == 1 then
    for i = 1, 4 do
      track[i].running = true
    end
  else
    if params:get("midi_trnsp") == 2 then m[0]:stop() transport_tog = 0 end
    for i = 1, 4 do
      track[i].running = false
      notes_off(i)
    end
  end
end

function transport_track(i)
  track[i].running = not track[i].running
  if not track[i].running then
    notes_off(i)
  end
  local run_count = 0
  for j = 1, 4 do
    if track[j].running then
      run_count = run_count + 1
    end
  end
  if run_count > 0 then
    transport = 1
  else
    transport = 0
  end
  dirtygrid = true
end

function reset_pos()
  for i = 1, 4 do
    track[i].reset = true
  end
end

function randomize_notes()
  for i = 1, 16 do
    table.insert(pattern.notes[p_set], i, math.random(1, 20))
    table.insert(pattern.rests[p_set], i, 0)
  end
end


-------- norns UI --------
local params_a = {"moon_cutoff", "track_midi_device", "v8_type_1", "v8_type_2", "jf_mode", "wsyn_curve"}
local params_b = {"moon_resonance", "track_midi_channel", "env1_amplitude", "env2_amplitude", "jf_amp", "wsyn_ramp"}
local params_c = {"moon_attack", "midi_vel_val", "env1_attack", "env2_attack", "jf_voice", "wsyn_lpg_time"}
local params_d = {"moon_release", "vel_mode", "env1_decay", "env2_decay", "", "wsyn_lpg_sym"}

local params_e = {"moon_amp", "track_midi_device", "v8_type_1", "v8_type_2", "jf_mode", "wsyn_fm_index"}
local params_f = {"moon_noise_amp", "track_midi_channel", "env1_amplitude", "env2_amplitude", "jf_amp", "wsyn_fm_env"}
local params_g = {"moon_cutoff_env", "midi_vel_range", "env1_attack", "env2_attack", "jf_voice", "wsyn_fm_num"}
local params_h = {"moon_sub_div", "vel_mode", "env1_decay", "env2_decay", "", "wsyn_fm_den"}

local display_a = {"cutoff", "midi device", "type", "type", "jf mode", "curve"}
local display_b = {"resonance", "channel", "env amp", "env amp", "jf level", "ramp"}
local display_c = {"attack", "velocity", "attack", "attack", "jf voice", "lpg time"}
local display_d = {"release", "mode", "decay", "decay", "", "lpg sym"}

local display_e = {"level", "midi device", "type", "type", "jf mode", "fm index"}
local display_f = {"noise", "channel", "env amp", "env amp", "jf level", "fm env"}
local display_g = {"cutoff env", "range ±", "attack", "attack", "jf voice", "ratio num"}
local display_h = {"sub div", "mode", "decay", "decay", "", "ratio denom"}

function enc(n, d)
  if n == 1 then
    pageNum = util.clamp(pageNum + d, 1, #options.pages)
  end
  if pageNum == 1 then
    if n == 2 then
      edit = util.clamp(edit + d, 1, 16)
    elseif n == 3 then
      pattern.notes[p_set][edit] = util.clamp(pattern.notes[p_set][edit] + d, 1, 20)
    end
  elseif pageNum == 2 then
    if viewinfo == 0 then
      if n == 2 then
        params:delta("rate"..focus, d)
      elseif n == 3 then
        if shift then
          params:delta("s_probability"..focus, d)
        else
          params:delta("n_probability"..focus, d)
        end
      end
    else
      if n == 2 then
        params:delta("octave"..focus, d)
      elseif n == 3 then
        params:delta("transpose"..focus, d)
      end
    end
  elseif pageNum == 3 then
    local output = track[focus].track_out
    if shift then
      if viewinfo == 0 then
        if n == 2 then
          if ((output == 3 or output == 4) or output == 6) then
            params:delta(params_e[output], d)
          else
            params:delta(params_e[output]..focus, d)
          end
        elseif n == 3 then
          if ((output == 3 or output == 4) or output == 6) then
            params:delta(params_f[output], d)
          else
            params:delta(params_f[output]..focus, d)
          end
        end
      else
        if n == 2 then
          if ((output == 3 or output == 4) or output == 6) then
            params:delta(params_g[output], d)
          else
            params:delta(params_g[output]..focus, d)
          end
        elseif n == 3 then
          if params_h[output] == "" then
            --return
          elseif ((output == 3 or output == 4) or output == 6) then
            params:delta(params_h[output], d)
          else
            params:delta(params_h[output]..focus, d)
          end
        end
      end
    else
      if viewinfo == 0 then
        if n == 2 then
          if ((output == 3 or output == 4) or output == 6) then
            params:delta(params_a[output], d)
          else
            params:delta(params_a[output]..focus, d)
          end
        elseif n == 3 then
          if ((output == 3 or output == 4) or output == 6) then
            params:delta(params_b[output], d)
          else
            params:delta(params_b[output]..focus, d)
          end
        end
      else
        if n == 2 then
          if ((output == 3 or output == 4) or output == 6) then
            params:delta(params_c[output], d)
          else
            params:delta(params_c[output]..focus, d)
          end
        elseif n == 3 then
          if params_d[output] == "" then
            --return
          elseif ((output == 3 or output == 4) or output == 6) then
            params:delta(params_d[output], d)
          else
            params:delta(params_d[output]..focus, d)
          end
        end
      end
    end
  elseif pageNum == 4 then
    if viewinfo == 0 then
      if n == 2 then
        params:delta("delay_level", d)
      elseif n == 3 then
        params:delta("delay_length", d)
      end
    else
      if n == 2 then
        if freeze == 0 then
          params:delta("delay_feedback", d)
        end
      elseif n == 3 then
        params:delta("delay_length_ft", d)
      end
    end
  end
  dirtyscreen = true
end

function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if pageNum == 1 then
    if n == 2 and z == 1 then
      if not shift then
        transport = 1 - transport
        transport_all()
      elseif shift then
        reset_pos()
      end
    elseif n == 3 and z == 1 then
      if not shift then
        pattern.rests[p_set][edit] = 1 - pattern.rests[p_set][edit]
      elseif shift then
        randomize_notes()
      end
    end
  elseif (pageNum == 2 or pageNum == 3) then
    if n == 2 then
      if z == 1 then
        viewinfo = 1 - viewinfo
      end
    end
  elseif pageNum == 4 then
    if n == 2 then
      if z == 1 then
        viewinfo = 1 - viewinfo
      end
    elseif n == 3 then
      if z == 1 then
        freeze = 1 - freeze
        if freeze == 1 then
          set_feedback(1)
        else
          local fb = params:get("delay_feedback")
          set_feedback(fb)
        end
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function redraw()
  screen.clear()
  for i = 1, #options.pages do
    screen.move(i * 6 + 97, 6)
    screen.line_rel(4, 0)
    screen.line_width(4)
    if i == pageNum then
      screen.level(15)
    else
      screen.level(2)
    end
    screen.stroke()
  end
  screen.move(1, 8)
  screen.level(6)
  screen.font_size(8)
  screen.text(options.pages[pageNum])
  local sel = viewinfo == 0
  if pageNum == 1 then
    for i = 1, 16 do
      -- draw notes
      screen.move(i * 8 - 8 + 1, 44 - ((pattern.notes[p_set][i]) * 2) + 8)
      screen.level((i == edit) and 15 or 3)
      if pattern.rests[p_set][i] == 1 then
        screen.level((i == edit) and 1 or 0)
      end
      screen.line_width(2)
      screen.line_rel(4, 0)
      screen.stroke()
    end
    -- draw playheads
    for i = 1, 4 do
      screen.level(1)
      screen.move(track[i].loop_start * 8 - 8 + 1, 51 + i * 3)
      screen.line_rel(track[i].loop_end * 8 - 4 - (track[i].loop_start * 8 - 8), 0)
      screen.stroke()
      screen.level(15)
      screen.move(track[i].pos * 8 - 8 + 1, 51 + i * 3) -- at y = 54, 56, 58, 60
      screen.line_rel(4, 0)
      screen.stroke()
    end
  elseif pageNum == 2 then
    screen.level(6)
    screen.move(28, 8)
    screen.font_size(8)
    screen.text(focus)
    screen.level(sel and 15 or 4)
    screen.move(14, 24)
    screen.text(params:string("rate"..focus))
    screen.move(74, 24)
    if shift then
      screen.text(params:string("s_probability"..focus))
    else
      screen.text(params:string("n_probability"..focus))
    end
    screen.level(3)
    screen.move(14, 32)
    screen.text("rate")
    screen.move(74, 32)
    if shift then
      screen.text("step prob")
    else
      screen.text("note prob")
    end
    screen.level(not sel and 15 or 4)
    screen.move(14, 48)
    screen.text(params:string("octave"..focus))
    screen.move(74, 48)
    screen.text(params:string("transpose"..focus))
    screen.level(3)
    screen.move(14, 56)
    screen.text("octave")
    screen.move(74, 56)
    screen.text("transpose")
  elseif pageNum == 3 then
    local output = track[focus].track_out
    screen.level(6)
    screen.move(28, 8)
    screen.font_size(8)
    screen.text(focus)
    if shift then
      screen.level(sel and 15 or 4)
      screen.move(14, 24)
      if ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_e[output]))
      else
        local params = output == 2 and string.sub(params:string(params_e[output]..focus), 1, 9) or params:string(params_e[output]..focus)
        screen.text(params)
      end
      screen.move(74, 24)
      if ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_f[output]))
      else
        screen.text(params:string(params_f[output]..focus))
      end
      screen.level(3)
      screen.move(14, 32)
      screen.text(display_e[track[focus].track_out])
      screen.move(74, 32)
      screen.text(display_f[track[focus].track_out])
      screen.level(not sel and 15 or 4)
      screen.move(14, 48)
      if ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_g[output]))
      else
        screen.text(params:string(params_g[output]..focus))
      end
      screen.move(74, 48)
      if params_h[output] == "" then
        --return
      elseif ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_h[output]))
      else
        screen.text(params:string(params_h[output]..focus))
      end
      screen.level(3)
      screen.move(14, 56)
      screen.text(display_g[track[focus].track_out])
      screen.move(74, 56)
      screen.text(display_h[track[focus].track_out])
    else
      screen.level(sel and 15 or 4)
      screen.move(14, 24)
      if ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_a[output]))
      else
        local params = output == 2 and string.sub(params:string(params_a[output]..focus), 1, 9) or params:string(params_a[output]..focus)
        screen.text(params)
      end
      screen.move(74, 24)
      if ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_b[output]))
      else
        screen.text(params:string(params_b[output]..focus))
      end
      screen.level(3)
      screen.move(14, 32)
      screen.text(display_a[track[focus].track_out])
      screen.move(74, 32)
      screen.text(display_b[track[focus].track_out])
      screen.level(not sel and 15 or 4)
      screen.move(14, 48)
      if ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_c[output]))
      else
        screen.text(params:string(params_c[output]..focus))
      end
      screen.move(74, 48)
      if params_d[output] == "" then
        --return
      elseif ((output == 3 or output == 4) or output == 6) then
        screen.text(params:string(params_d[output]))
      else
        screen.text(params:string(params_d[output]..focus))
      end
      screen.level(3)
      screen.move(14, 56)
      screen.text(display_c[track[focus].track_out])
      screen.move(74, 56)
      screen.text(display_d[track[focus].track_out])
    end
  elseif pageNum == 4 then
    screen.level(sel and 15 or 4)
    screen.move(14, 24)
    screen.text(params:string("delay_level"))
    screen.move(74, 24)
    screen.text(params:string("delay_length"))
    screen.level(3)
    screen.move(14, 32)
    screen.text("level")
    screen.move(74, 32)
    screen.text("rate")
    screen.level(not sel and 15 or 4)
    screen.move(14, 48)
    if (params:get("delay_feedback") == 1 or freeze == 1) then
      screen.text("freeeeze")
    else
      screen.text(params:string("delay_feedback"))
    end
    screen.move(74, 48)
    screen.text(params:string("delay_length_ft"))
    screen.level(3)
    screen.move(14, 56)
    screen.text("feedback")
    screen.move(74, 56)
    screen.text("adjust rate")
  end
  screen.update()
end


-------- grid interface --------
function g.key(x, y, z)
  -- loop modifier keys
  if x == 15 then
    if y == 5 then
      set_start = z == 1 and true or false
    elseif y == 6 then
      set_end = z == 1 and true or false
    elseif y == 7 then
      set_loop = z == 1 and true or false
    end
  end
  -- grid page keys
  if x == 16 then
    if y == 5 then
      set_rate = z == 1 and true or false
    elseif y == 6 then
      set_oct = z == 1 and true or false
    elseif y == 7 then
      set_trsp = z == 1 and true or false
    end
    if y > 4 and y < 8 then
      altgrid = z == 1 and true or false
    end
  end
  -- mod and alt keys
  if x == 15 and y == 8 then
    mod = z == 1 and true or false
  end
  if x == 16 and y == 8 then
    alt = z == 1 and true or false
  end
  -- set loop size
  if y < 5 and params:get("loop_set_keys") == 2 then
    local i = y
    if z == 1 and held[i] then heldmax[i] = 0 end
    held[i] = held[i] + (z * 2 - 1)
    if held[i] > heldmax[i] then heldmax[i] = held[i] end
    if z == 1 then
      if held[i] == 1 then
        first[i] = x
      elseif held[i] == 2 then
        second[i] = x
      end
    elseif z == 0 then
      if held[i] == 1 and heldmax[i] == 2 then
        params:set("loop_start"..i, math.min(first[i], second[i]))
        params:set("loop_end"..i, math.max(first[y], second[y]))
      end
    end
    page_redraw(1)
    dirtygrid = true
  end
  -- all other functions
  if z == 1 then
    if y < 5 then
      local i = y
      if focus ~= i then focus = i end
      if not altgrid then
        if set_start then
          params:set("loop_start"..i, x)
          if mod then track[i].pos = track[i].loop_end end
        elseif set_end then
          params:set("loop_end"..i, x)
          if mod then track[i].pos = x end
        elseif set_loop then
          track[i].loop_len = track[i].loop_end - track[i].loop_start
          params:set("loop_start"..i, x)
          params:set("loop_end"..i, x + track[i].loop_len)
          if mod then track[i].pos = x end
        elseif alt then
          reset_pos()
        elseif mod then
          for i = 1, 4 do
            track[i].pos = x
            if not track[i].running then
              play_voice(i)
            end
          end
        else
          track[i].pos = x
          if not track[i].running then
            play_voice(i)
          end
        end
      elseif set_rate then
        params:set("rate"..i, x)
      elseif set_oct then
        if x > 4 and x < 9 then
          params:set("octave"..i, x - 4)
        elseif x > 8 and x < 13 then
          params:set("octave"..i, x - 5)
        end
      elseif set_trsp then
        if x < 9 then
          params:set("transpose"..i, x - 8)
        elseif x > 8 then
          params:set("transpose"..i, x - 9)
        end
      end
      dirtyscreen = true
    end
    if y > 4 then
      local i = y - 4
      -- run/stop
      if x == 1 and not alt then
        transport_track(i)
      elseif x == 1 and alt then
        if track[i].running then
          if params:get("midi_trnsp") == 2 then m[0]:stop() transport_tog = 0 end
          for j = 1, 4 do
            track[j].running = false
            notes_off(j)
            reset_pos()
          end
        elseif not track[i].running then
          for j = 1, 4 do
            track[j].running = true
          end
        end
        dirtyscreen = true
      end
      -- track focus
      if x == 2 then
        if focus ~= i then focus = i end
        if pageNum == 2 then dirtyscreen = true end
      end
      -- note presets
      if x > 3 and x < 6 then
        if y > 5 and y < 8 then
          local i = (y - 5) + (x - 4) * 2
          if alt then
            pattern.notes[i] = {table.unpack(pattern.notes[p_set])}
            pattern.rests[i] = {table.unpack(pattern.rests[p_set])}
          elseif not alt then
            p_set = i
          end
          dirtyscreen = true
        end
      end
      -- direction
      if x == 7 then
        params:set("direction"..i, x - 5)
      elseif x == 10 then
        params:set("direction"..i, x - 9)
      end
      -- step mode
      if x == 8 then
        if params:get("step_mode"..i) == 2 then
          params:set("step_mode"..i, 1)
        else
          params:set("step_mode"..i, 2)
        end
      elseif x == 9 then
        if params:get("step_mode"..i) == 3 then
          params:set("step_mode"..i, 1)
        else
          params:set("step_mode"..i, 3)
        end
      end
    end
    -- track preset
    if x > 11 and x < 14 then
      if y > 5 and y < 8 then
        local i = (y - 5) + (x - 12) * 2
        if alt then
          save_track_data(t_set)
        elseif not alt then
          save_track_data(tp_set)
          t_set = i
        end
			end
      dirtyscreen = true
    end
  elseif z == 0 then
    if x > 11 and x < 14 then
      if y > 5 and y < 8 then
        local i = (y - 5) + (x - 12) * 2
        tp_set = i
        load_track_data()
      end
    end
    dirtyscreen = true
  end
  dirtygrid = true
end

function gridredraw()
  g:all(0)
  if not altgrid then
    -- loop windows
    for i = 1, 4 do
      track[i].len = track[i].loop_end - track[i].loop_start
      for j = 1, track[i].len + 1 do
        g:led(track[i].loop_start + j - 1, i, set_loop and 6 or 4)
      end
      if set_start then
        g:led(track[i].loop_start, i, 7)
      end
      if set_end then
        g:led(track[i].loop_end, i, 7)
      end
    end
    -- playhead
    for i = 1, 4 do
      g:led(track[i].pos, i, 15)
    end
  elseif altgrid and set_rate then
    for i = 1, 4 do
      g:led(2, i, 3)
      g:led(5, i, 3)
      g:led(8, i, 6)
      g:led(11, i, 3)
      g:led(14, i, 3)
      g:led(16, i, 3)
      g:led(params:get("rate"..i), i, 10)
    end
  elseif altgrid and set_oct then
    for i = 1, 4 do
      g:led(8, i, params:get("octave"..i) == 4 and 8 or 4)
      g:led(9, i, params:get("octave"..i) == 4 and 8 or 4)
      if params:get("octave"..i) < 4 then
        g:led(params:get("octave"..i) + 4, i, 10)
      elseif params:get("octave"..i) > 4 then
        g:led(params:get("octave"..i) + 5, i, 10)
      end
    end
  elseif altgrid and set_trsp then
    for i = 1, 4 do
      g:led(8, i, params:get("transpose"..i) == 0 and 8 or 4)
      g:led(9, i, params:get("transpose"..i) == 0 and 8 or 4)
      if params:get("transpose"..i) < 0 then
        g:led(params:get("transpose"..i) + 8, i, 10)
      elseif params:get("transpose"..i) > 0 then
        g:led(params:get("transpose"..i) + 9, i, 10)
      end
    end
  end
  -- alt keys
  g:led(15, 5, set_start and 15 or 3)
  g:led(15, 6, set_end and 15 or 3)
  g:led(15, 7, set_loop and 15 or 3)
  g:led(15, 8, mod and 15 or 8)

  g:led(16, 5, set_rate and 15 or 4)
  g:led(16, 6, set_oct and 15 or 4)
  g:led(16, 7, set_trsp and 15 or 4)
  g:led(16, 8, alt and 15 or 8)
  -- playback
  for i = 1, 4 do
    g:led(1, i + 4, track[i].running and 15 or 4) -- run/stop
    g:led(2, i + 4, focus == i and 8 or 3) -- focus
    g:led(7, i + 4, track[i].dir == 1 and 9 or 4) -- fwd
    g:led(8, i + 4, track[i].dir_mode == 1 and 6 or 2) -- pendulum
    g:led(9, i + 4, track[i].dir_mode == 2 and 6 or 2) -- random
    g:led(10, i + 4, track[i].dir == 0 and 9 or 4) -- rev
  end
  -- note presets
  for i = 1, 2 do
    g:led(4, i + 5, 3)
    g:led(5, i + 5, 3)
  end
  if p_set < 3 then
    g:led(4, p_set + 5, 10)
  else
    g:led(5, p_set + 3, 10)
  end
  -- track presets
  for i = 1, 2 do
    g:led(12, i + 5, 3)
    g:led(13, i + 5, 3)
  end
  if t_set < 3 then
    g:led(12, t_set + 5, 10)
  else
    g:led(13, t_set + 3, 10)
  end
  g:refresh()
end


-------- menu and redraw functions --------
function build_menu()
  for i = 1, 4 do
    if track[i].track_out == 1 then
      params:show("moon_synthesis"..i)
      params:show("moon_amp"..i)
      params:show("moon_sub_div"..i)
      params:show("moon_noise_amp"..i)
      params:show("moon_cutoff"..i)
      params:show("moon_cutoff_env"..i)
      params:show("moon_resonance"..i)
      params:show("moon_attack"..i)
      params:show("moon_release"..i)
      params:show("moon_pan"..i)
    else
      params:hide("moon_synthesis"..i)
      params:hide("moon_amp"..i)
      params:hide("moon_sub_div"..i)
      params:hide("moon_noise_amp"..i)
      params:hide("moon_cutoff"..i)
      params:hide("moon_cutoff_env"..i)
      params:hide("moon_resonance"..i)
      params:hide("moon_attack"..i)
      params:hide("moon_release"..i)
      params:hide("moon_pan"..i)
    end
    if track[i].track_out == 2 then
      params:show("midi_params_"..i)
      params:show("track_midi_device"..i)
      params:show("track_midi_channel"..i)
      params:show("vel_mode"..i)
      params:show("midi_vel_val"..i)
      params:show("midi_vel_range"..i)
    else
      params:hide("midi_params_"..i)
      params:hide("track_midi_device"..i)
      params:hide("track_midi_channel"..i)
      params:hide("vel_mode"..i)
      params:hide("midi_vel_val"..i)
      params:hide("midi_vel_range"..i)
    end
    if track[i].track_out == 3 then
      if (params:get("clock_crow_out") == 2 or params:get("clock_crow_out") == 3) then
        params:set("clock_crow_out", 1)
      end
    end
    if track[i].track_out == 4 then
      if (params:get("clock_crow_out") == 4 or params:get("clock_crow_out") == 5) then
        params:set("clock_crow_out", 1)
      end
    end
    if track[i].track_out == 5 then
      params:show("jf_params_"..i)
      if params:get("jf_mode"..i) == 1 then
        params:show("jf_voice"..i)
      else
        params:hide("jf_voice"..i)
      end
      params:show("jf_amp"..i)
      params:show("jf_mode"..i)
    else
      params:hide("jf_params_"..i)
      params:hide("jf_mode"..i)
      params:hide("jf_voice"..i)
      params:hide("jf_amp"..i)
    end
  end
  _menu.rebuild_params()
end

function grid_redraw()
  if dirtygrid == true then
    gridredraw()
    dirtygrid = false
  end
end

function screen_redraw()
  if dirtyscreen == true then
    redraw()
    dirtyscreen = false
  end
end

function page_redraw(num)
  if pageNum == num then
    dirtyscreen = true
  end
end

function drawgrid_connect()
 dirtygrid = true
 gridredraw()
end

function cleanup()
  grid.add = function() end
  midi.add = function() end
  midi.remove = function() end
  crow.ii.jf.mode(0)
end
