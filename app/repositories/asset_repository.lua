local asset_repository = {}

-- Scan folder for audio files
function asset_repository.scan_music_folder(base_path)
  local scanFolderForMP3 = require("mp3scan")
  return scanFolderForMP3(base_path)
end

-- Get unique directory paths
function asset_repository.get_unique_paths(directory)
  local util = require("util")
  return util.get_unique_paths(directory)
end

-- Convert between path and name
function asset_repository.path_to_name(assets, path)
  for i, p in ipairs(assets.paths) do
    if p == path then
      return assets.names[i]
    end
  end
  return nil
end

function asset_repository.name_to_path(assets, name)
  for i, n in ipairs(assets.names) do
    if n == name then
      return assets.paths[i]
    end
  end
  return nil
end

return asset_repository
