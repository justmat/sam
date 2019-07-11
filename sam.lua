--
--      sam(pler)
--  ________________________
-- |  ____________________   |
-- | /                        \  |
-- | |    //\\       //\\   |  |
-- | |    || () ||        || () ||   |  |
-- | |    \\//       \\//   |  |
-- | |                          |  |
-- | `-------------------------'   |
-- |     / []         []  \       |
-- !___/_______________\____!
--
--
-- key1 - alt
-- key2 - start/stop record
-- key3 - start/stop playback
-- alt + key3 - save slice
--
-- enc2 - sample start
-- enc3 - sample end
-- alt + enc2/3 - fine adjust
--
-- v0.1 @justmat

local recording = false
local playing = false
local save_time = 2

local start_time = nil
local alt = false
local sample_id = 1
local current_position = 0


local function reset_loop()
  softcut.buffer_clear(1)
  params:set("loop_start", 0)
  params:set("loop_end", 60)
  softcut.position(1, 0)
  current_position = 0
end


local function set_loop_start(v)
  v = util.clamp(v, 0, params:get("loop_end") - .01)
  params:set("loop_start", v)
  softcut.loop_start(1, v)
end


local function set_loop_end(v)
  v = util.clamp(v, params:get("loop_start") + .01, 60.0)
  params:set("loop_end", v)
  softcut.loop_end(1, v)
end


function write_buffer()
  -- saves L/R buffers as stereo files in /home/we/dust/audio/tape
  sample_id = string.match(util.time(), "....$")
  local loop_start = params:get("loop_start")
  local loop_end = params:get("loop_end")
  local file_path = "/home/we/dust/audio/tape/smpl." .. sample_id .. ".wav"

  softcut.buffer_write_mono(file_path, loop_start, loop_end, 1)
end


local function update_positions(voice,position)
  current_position = position
  --print(voice,position)
end


function init()
  -- softcut setup
  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  softcut.level(1,1)
  softcut.level_slew_time(1,0.1)
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(2, 1, 1.0)
  softcut.pan(1, 0.5)
  softcut.play(1, 1)
  softcut.rate(1, 1)
  softcut.rate_slew_time(1,0.1)
  softcut.loop_start(1, 1)
  softcut.loop_end(1, 60)
  softcut.loop(1, 1)
  softcut.fade_time(1, 0.1)
  softcut.rec(1, 0)
  softcut.rec_level(1, 1)
  softcut.pre_level(1, 1)
  softcut.position(1, 0)
  softcut.buffer(1,1)
  softcut.enable(1, 1)
  softcut.filter_dry(1, 1)
  
  -- sample start controls
  params:add_control("loop_start", "loop start", controlspec.new(0.0, 59.99, "lin", .01, 0, "secs"))
  params:set_action("loop_start", function(x) set_loop_start(x) end)
  -- sample end controls
  params:add_control("loop_end", "loop end", controlspec.new(.01, 60, "lin", .01, 60, "secs"))
  params:set_action("loop_end", function(x) set_loop_end(x) end)

  -- screen metro
  local screen_timer = metro.init()
  screen_timer.time = 1/15
  screen_timer.event = function() redraw() end
  screen_timer:start()

  -- softcut phase poll
  softcut.phase_quant(1, .01)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end


function key(n, z)
  if n == 1 then
    alt = z == 1 and true or false
  end
  
  if n == 2 and z == 1 then
    if recording == false then
      reset_loop()
      softcut.rec(1, 1)
      recording = true
      start_time = util.time()
    else
      softcut.rec(1,0)
      softcut.position(1, 0)
      params:set("loop_end", current_position)
      recording = false
      playing = true
    end
  elseif n == 3 and z == 1 then
    if alt then
      save_time = util.time()
      write_buffer()
    else
      if playing == true then
        softcut.play(1, 0)
        playing = false
      else
        softcut.position(1, 0)
        softcut.play(1, 1)
        playing = true
      end
    end
  end
end
      

function enc(n, d)
  if alt then
    -- fine
    if n == 2 then
      params:delta("loop_start", d * .01)
    elseif n == 3 then
      params:delta("loop_end", d * .01)
    end
  else
    -- coarse
    if n == 2 then
      params:delta("loop_start", d * .1)
    elseif n == 3 then
      params:delta("loop_end", d * .1)
    end
  end
end


function redraw()
  screen.aa(1)
  screen.clear()
  screen.move(64, 10)
  screen.level(6)
  if recording then
    screen.text_center("recording")
  elseif playing then
    screen.text_center("looping")
  elseif not playing and not recording then
    screen.text_center("stopped")
  end
  screen.level(15)
  screen.move(64, 32)
  screen.text_center("start : " .. string.format("%.2f", params:get("loop_start")))
  screen.move(64, 42)
  if recording then
    screen.text_center("end : " .. string.format("%.2f", current_position))
  else
    screen.text_center("end : " .. string.format("%.2f", params:get("loop_end")))
  end
  screen.move(64, 52)
  screen.level(util.time() - save_time <= 1.0 and 15 or 0)
  screen.text_center("saving smpl." .. sample_id .. ".wav")
  screen.update()
end

    