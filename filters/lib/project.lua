-- filters/lib/project.lua
-- Common project-path and YAML helpers for Quarto/Pandoc Lua filters.

local M = {}

function M.locate(path)
  local candidates = {
    path,
    "../" .. path,
    "../../" .. path,
    "../../../" .. path,
    "../../../../" .. path
  }

  for _, candidate in ipairs(candidates) do
    local f = io.open(candidate, "r")
    if f then
      f:close()
      return candidate
    end
  end

  error("Cannot locate project file: " .. path)
end

function M.read_file(path)
  local resolved = M.locate(path)

  local f = assert(
    io.open(resolved, "r"),
    "Cannot read project file: " .. resolved
  )

  local content = f:read("*all")
  f:close()

  return content
end

function M.yaml_meta(path)
  local content = M.read_file(path)

  return pandoc.read(
    "---\n" .. content .. "\n---\n",
    "markdown"
  ).meta
end

return M
