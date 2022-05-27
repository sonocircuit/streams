local Thebangs = {}

Thebangs.options = {}
Thebangs.options.algoNames = {"square", "square_mod1", "square_mod2", "sinfmlp", "sinfb", "reznoise", "klangexp", "klanglin"}
Thebangs.options.stealModes = {"static", "FIFO", "LIFO", "ignore"}

function Thebangs.synth_params()

  params:add_option("bangs_algo", "algo", Thebangs.options.algoNames, 1)
  params:set_action("bangs_algo", function(x) engine.algoIndex(x) end)

  params:add_control("bangs_amp", "amp", controlspec.new(0, 1, "lin", 0, 0.5, ""))
  params:set_action("bangs_amp", function(x) engine.amp(x) end)

  params:add_control("bangs_cutoff", "cutoff", controlspec.new(50, 8000, "exp", 0, 900, "hz"))
  params:set_action("bangs_cutoff", function(x) engine.cutoff(x) s_refresh() end)

  params:add_control("bangs_pw", "pw/mod1", controlspec.new(0, 100, "lin", 0, 32, "%"))
  params:set_action("bangs_pw", function(x) engine.pw(x / 100) s_refresh() end)

  params:add_control("bangs_gain", "gain/mod2", controlspec.new(0, 4, "lin", 0, 1, ""))
  params:set_action("bangs_gain", function(x) engine.gain(x) end)

  params:add_control("bangs_attack", "attack", controlspec.new(0.0001, 1, "exp", 0, 0.01, "s"))
  params:set_action("bangs_attack", function(x) engine.attack(x) s_refresh() end)

  params:add_control("bangs_release", "release", controlspec.new(0.1, 3.2, "lin", 0, 0.8, "s"))
  params:set_action("bangs_release", function(x) engine.release(x) s_refresh() end)

  params:add_control("bangs_pan", "pan", controlspec.new(-1, 1, "lin", 0, 0, ""))
  params:set_action("bangs_pan", function(x) engine.pan(x) end)
  --params:hide("bangs_pan")
end

function Thebangs.add_voicer_params()

  params:add_trigger("stop_all", "stopp all")
  params:set_action("stop_all", function(x) engine.stopAllVoices() end)

  params:add_number("max_voices", "max voices", 1, 32, 32)
  params:set_action("max_voices", function(x) engine.maxVoices(x) end)

  params:add_option("steal_mode", "steal mode", Thebangs.options.stealModes, 2)
  params:set_action("bangs_algo", function(x) engine.stealMode(x - 1) end)

  params:add_number("steal_index", "steal index", 1, 32, 0)
  params:set_action("steal_index", function(x) eengine.stealIndex(x) end)

end

return Thebangs
