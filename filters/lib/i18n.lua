-- filters/lib/i18n.lua
-- Common internationalization support for Quarto/Pandoc Lua filters.

local project = require("lib.project")

local M = {}

function M.normalize_lang(lang)
  lang = (lang or "en"):lower()

  if lang:match("^pt") then
    return "pt"
  elseif lang:match("^es") then
    return "es"
  end

  return "en"
end

function M.document_language()
  local input = ""

  if PANDOC_STATE
      and PANDOC_STATE.input_files
      and #PANDOC_STATE.input_files > 0 then
    input = tostring(PANDOC_STATE.input_files[1])
  end

  input = input:gsub("\\", "/")

  if input:match("^pt/") or input:match("/pt/") then
    return "pt"
  elseif input:match("^es/") or input:match("/es/") then
    return "es"
  elseif input:match("^en/") or input:match("/en/") then
    return "en"
  end

  -- Root and language-independent pages use English as the canonical fallback.
  return "en"
end

function M.load(lang)
  local code = M.normalize_lang(lang)
  local meta = project.yaml_meta("i18n/" .. code .. ".yml")

  return {
    language = code,
    labels = meta.labels or {},
    topic_labels = meta.topic_labels or {},
    group_labels = meta.group_labels or {}
  }
end

function M.tr(table_, key, fallback)
  if table_ and table_[key] then
    return pandoc.utils.stringify(table_[key])
  end

  return fallback or key
end

return M
