-- softsync – a synced softcut delay based on halfsecond
-- v_0.1.0 @sonocircuit

local softsync = {}

local div_options = {1/16, 1/12, 3/32, 1/8, 1/6, 3/16, 1/4, 1/3, 3/8, 1/2, 2/3, 3/4, 1}
local div_view = {"1/16", "1/12", "3/32", "1/8", "1/6", "3/16", "1/4","1/3", "3/8", "1/2", "2/3", "3/4", "1"}
local feedback = 0.3

-- tape warble
local warble = {}
warble.freq = 8
warble.counter = 1
warble.slope = 0
warble.active = false

local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

function softsync.init()
  audio.level_cut(1.0)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  softcut.level(1,1.0)
  softcut.level_slew_time(1,0.25)
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(2, 1, 1.0)
  softcut.pan(1, 0)

  softcut.play(1, 1)
  softcut.rate(1, 1)
  softcut.rate_slew_time(1,0)
  softcut.loop_start(1, 1)
  softcut.loop_end(1, 1)
  softcut.loop(1, 1)
  softcut.fade_time(1, 0.1)
  softcut.rec(1, 1)
  softcut.rec_level(1, 1)
  softcut.pre_level(1, 0.75)
  softcut.position(1, 1)
  softcut.enable(1, 1)

  softcut.post_filter_dry(1, 0.125)
  softcut.post_filter_fc(1, 1200)
  softcut.post_filter_lp(1, 0)
  softcut.post_filter_bp(1, 1.0)
  softcut.post_filter_rq(1, 2.0)

  params:add_control("delay_level", "level", controlspec.new(0, 1, 'lin' , 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
  params:set_action("delay_level", function(x) softcut.level(1, x) page_redraw(4) end)

  params:add_option("delay_length", "rate", div_view, 7)
  params:set_action("delay_length", function() set_del_rate() page_redraw(4) end)

  params:add_control("delay_length_ft", "adjust rate ", controlspec.new(-10, 10, 'lin', 0.1, 0), function(param) return (param:get().."%") end)
  params:set_action("delay_length_ft", function() set_del_rate() page_redraw(4) end)

  params:add_control("delay_feedback", "feedback", controlspec.new(0, 1.0, 'lin', 0 , 0.30), function(param) return (round_form(param:get() * 100, 1, "%")) end)
  params:set_action("delay_feedback", function(x) set_feedback(x) page_redraw(4) end)

  params:add_number("warble_amount", "warble amount", 0, 100, 0, function(param) return (param:get().."%") end)

  params:add_number("warble_depth", "wable depth", 0, 100, 12, function(param) return (param:get().."%") end)

  params:add_control("warble_freq","warble speed", controlspec.new(1.0, 10.0, "lin", 0.1, 6.0, ""))
  params:set_action("warble_freq", function(val) warble.freq = val * 1.2 end)

  warbletimer = metro.init(function() make_warble() end, 0.1, -1)
  warbletimer:start()
end

function set_feedback(x)
  local fb = x
  softcut.pre_level(1, fb)
  if fb == 1.0 then
    softcut.rec_level(1, 0)
  else
    softcut.rec_level(1, 1)
  end
end

function clock.tempo_change_handler()
  set_del_rate()
end

function set_del_rate()
  local del_rate = (clock.get_beat_sec() * div_options[params:get("delay_length")] * 4)
  local set_rate = 1 + del_rate - (del_rate * (params:get("delay_length_ft") / 100))
  softcut.loop_end(1, set_rate)
end

function make_warble()
  local tau = math.pi * 2
  -- make sine
  slope = 1 * math.sin(((tau / 100) * (warble.counter)) - (tau / (warble.freq)))
  warble.slope = util.linlin(-1, 1, -1, 0, math.max(-1, math.min(1, slope))) * (params:get("warble_depth") * 0.001)
  warble.counter = warble.counter + warble.freq
  -- activate warble
  if math.random(100) <= params:get("warble_amount") then
    if not warble.active then
      warble.active = true
    end
  end
  -- do warble
  if warble.active then
    softcut.rate(1, 1 + warble.slope)
  end
  -- stop warble
  if warble.active and warble.slope > -0.001 then -- nearest value to zero
    warble.active = false
    softcut.rate(1, 1)
  end
end

return softsync
