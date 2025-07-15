-- TO DO: currently, previewing files with unicode characters in the filename is not possible,
-- due to limitations on how ffplay is invoked through the console
-- 
-- if you know how to fix this, please by all means go for it and make a pull request
--
-- ive tried 
-- going through powershell
-- manual re-encoding
--
-- i just don't know enough about how this problem works to make a fix for it

local mp3prvw = {}

function mp3prvw.stop()
  os.execute('taskkill /IM ffplay.exe /F >nul 2>&1')
end

function mp3prvw.play(full_path, duration)
  mp3prvw.stop()
  duration = tonumber(duration) or 30

  local fade_duration = 3
  local fade_start = math.max(0, duration - fade_duration)

  local path = full_path:gsub("\\", "/")
  local quoted = '"' .. path:gsub('"', '\\"') .. '"'

  -- Build command line for ffplay
  local ffplay_cmd = string.format(
    'ffmpeg\\ffplay.exe -nodisp -autoexit -loglevel quiet -t %d -af "afade=t=out:st=%d:d=%d" %s',
    duration, fade_start, fade_duration, quoted
  )

  -- Wrap with start /B and redirect output to prevent terminal flash
  local command = string.format('cmd /c start "" /B %s >nul 2>&1', ffplay_cmd)

  -- Use os.execute to run non-blocking
  os.execute(command)
end

return mp3prvw
