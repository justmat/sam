--
--      sam(ples)
--  ________________________
-- |  ____________________   |
-- | /                         \ |
-- | |    //\\       //\\   |  |
-- | |    || () ||        || () ||   |  |
-- | |    \\//       \\//   |  |
-- | `-------------------------'   |
-- |      /  []       []    \     |
-- |     / ()            ()  \    |
-- !___/________________\___!
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
-- v1.2 @justmat

local te = require 'textentry'
local alt = false
local recording = false
local playing = false
local saved_time = 2.0
local quantized_time = 2.0
local quantized_err_time = 2.0
local start_time = nil
local current_position = 0
local last_saved_name = ''


local function reset_loop()
  softcut.buffer_clear(1)
  params:set("sample", "-")
  params:set("loop_start", 0)
  params:set("loop_end", 350.0)
  softcut.position(1, 0)
  current_position = 0
end


local function set_loop_start(v)
  v = util.clamp(v, 0, params:get("loop_end") - .01)
  softcut.loop_start(1, v)
end


local function set_loop_end(v)
  v = util.clamp(v, params:get("loop_start") + .01, 350.0)
  softcut.loop_end(1, v)
end

local function quantize_loop_len()
  local loop_start = params:get("loop_start")
  local loop_len = params:get("loop_end") - loop_start
  local q_beat_len = clock.get_beat_sec() * params:get("quantize_div")
  local q_beat_count = loop_len // q_beat_len
  
  if math.abs(loop_len - (q_beat_len * q_beat_count)) > math.abs(loop_len - (q_beat_len * (q_beat_count + 1) )) then
    q_beat_count = q_beat_count + 1
  end

  if q_beat_count~=0 then
    params:set("loop_end", loop_start + (q_beat_len * q_beat_count))
    quantized_time = util.time()
  else
    quantized_err_time = util.time()
  end
end

local function load_sample(file)
  local chan, samples, rate = audio.file_info(file)
  local sample_len = samples / rate
  softcut.buffer_clear(1)
  softcut.buffer_read_mono(file, 0, 0, -1, 1, 1)
  set_loop_start(0)
  set_loop_end(sample_len)
end


function write_buffer(name)
  -- saves buffer as a mono file in /home/we/dust/audio/tape
  if name then
    last_saved_name = name
    local file_path = "/home/we/dust/audio/tape/" .. name .. ".wav"
    local loop_start = params:get("loop_start")
    local loop_end = params:get("loop_end")
    local dur = loop_end - loop_start

    softcut.buffer_write_mono(file_path, loop_start, dur + .12, 1)
    print("Buffer saved as " .. file_path)
    saved_time = util.time()
  end
end


local function update_positions(voice,position)
  current_position = position
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
  softcut.play(1, 0)
  softcut.rate(1, 1)
  softcut.rate_slew_time(1,0.1)
  softcut.loop_start(1, 0)
  softcut.loop_end(1, 350)
  softcut.loop(1, 1)
  softcut.fade_time(1, 0.1)
  softcut.rec(1, 0)
  softcut.rec_level(1, 1)
  softcut.pre_level(1, 1)
  softcut.position(1, 0)
  softcut.buffer(1,1)
  softcut.enable(1, 1)
  softcut.filter_dry(1, 1)

  -- load a sample
  params:add_file("sample", "sample")
  params:set_action("sample", function(file) load_sample(file) end)
  -- sample start controls
  params:add_control("loop_start", "loop start", controlspec.new(0.0, 349.99, "lin", .01, 0, "secs"))
  params:set_action("loop_start", function(x) set_loop_start(x) end)
  -- sample end controls
  params:add_control("loop_end", "loop end", controlspec.new(.01, 350, "lin", .01, 350, "secs"))
  params:set_action("loop_end", function(x) set_loop_end(x) end)
  -- quantize (todo: make this visiion more readable/standardized?)
  params:add_number("quantize_div", "Q beats", 1, 32, 1)

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
    if alt then
      -- quantize!
      quantize_loop_len()
    else
      if recording == false then
        reset_loop()
        softcut.rec(1, 1)
        recording = true
        start_time = util.time()
      else
        params:set("loop_end", current_position)
        softcut.rec(1,0)
        softcut.position(1, 0)
        recording = false
        playing = true
        softcut.play(1, 1)
      end
    end
  elseif n == 3 and z == 1 then
    if alt then
      te.enter(write_buffer, 'sam', 'Save Sample As: ')
      alt = not alt
    else
      if recording then
        -- do nothing
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
end


function enc(n, d)
  if alt then
    -- coarse
    if n == 2 then
      params:delta("loop_start", d * .5)
    elseif n == 3 then
      params:delta("loop_end", d * .5)
    end
  else
    -- fine
    if n == 2 then
      params:delta("loop_start", d * .005)
    elseif n == 3 then
      params:delta("loop_end", d * .005)
    end
  end
end


function redraw()
  screen.aa(0)
  screen.clear()
  screen.move(64, 12)
  screen.level(4)
  if recording then
    screen.text_center("recording...")
  elseif playing then
    screen.text_center("looping " .. "(" .. string.format("%.2f", current_position) .. ")")
  elseif not playing and not recording then
    screen.text_center("stopped")
  end
  screen.level(15)
  screen.move(64, 30)
  screen.text_center("start : " .. string.format("%.2f", params:get("loop_start")))
  screen.move(64, 42)
  if recording then
    screen.text_center("end : " .. string.format("%.2f", current_position))
  else
    screen.text_center("end : " .. string.format("%.2f", params:get("loop_end")))
  end
  screen.move(7, 60)  
  if recording then
    screen.text("loop")
  else
    if alt then
      screen.text("Q " .. params:get("clock_tempo") .. "/" .. params:get("quantize_div"))
    else
      screen.text("rec")
    end
  end
  screen.move(120, 60)
  if alt then
    screen.text_right("save")
  else
    if recording then
      screen.text_right(" - ")
    elseif playing then
      screen.text_right("stop")
    else
      screen.text_right("start")
    end
  end
  screen.move(64, 54)
  screen.level(4)
  if util.time() - saved_time <= 1.0 then
    screen.text_center("saved " .. last_saved_name .. ".wav")
  elseif util.time() - quantized_time <= 1.0 then
    screen.text_center("quantized!")
  elseif util.time() - quantized_err_time <= 1.0 then
    screen.text_center("loop too short :%(")
  end
  screen.update()
end
