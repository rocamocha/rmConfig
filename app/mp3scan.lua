function scanFolderForMP3(basePath)
  local paths = {}
  local names = {}
  local tmpfile = os.tmpname() .. ".txt"  -- Windows-safe temp filename

  -- PowerShell writes relative paths to UTF-8 file
  local ps_command = [[powershell -NoProfile -Command "]]
    .. [[Get-ChildItem -Recurse -File -LiteralPath ']] .. basePath .. [[' | ]]
    .. [[ForEach-Object {]]
    .. [[$name = $_.FullName.Substring((Get-Item ']].. basePath ..[[').FullName.Length); ]]
    .. [[$name = $name.Replace('\', '/'); ]]
    .. [[$name -replace '\.[^./\\]+$', '']]  -- Remove extension
    .. [[} | Out-File -FilePath ']] .. tmpfile .. [[' -Encoding UTF8"]]
  os.execute(ps_command)

  -- Read UTF-8 lines safely
  local f = io.open(tmpfile, "r")
  if not f then return {} end

  for line in f:lines() do
    line = line:gsub("\r", ""):gsub("^/", "")  -- Normalize
    if line ~= "" then
      
      table.insert(paths, line)
    end
  end

  local function extract_filenames(file_paths)
    local names = {}
    for _, path in ipairs(file_paths) do
      local name = path:match("([^/\\]+)$")
      if name then
        table.insert(names, name)
      end
    end
    return names
  end

  names = extract_filenames(paths)
  
  f:close()
  os.remove(tmpfile)
  return {
    paths = paths,
    names = names
  }
end

return scanFolderForMP3