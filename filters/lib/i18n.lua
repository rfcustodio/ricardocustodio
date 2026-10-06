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

-- Fallback language detection based on the input file path.
-- This is retained for contexts in which document metadata is unavailable.
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

  return "en"
end

-- Preferred language detection.
-- Uses the effective Pandoc/Quarto document metadata first and falls back
-- to the input-file path only when `lang` is unavailable.
function M.meta_language(meta)
  if meta and meta.lang then
    local lang = pandoc.utils.stringify(meta.lang)

    if lang ~= "" then
      return M.normalize_lang(lang)
    end
  end

  return M.document_language()
end

function M.load(lang)
  local code = M.normalize_lang(lang)
  local meta = project.yaml_meta("i18n/" .. code .. ".yml")

  return {
    language = code,
    labels = meta.labels or {},
    topic_labels = meta.topic_labels or {},
    group_labels = meta.group_labels or {},
    project_topic_labels = meta.project_topic_labels or {},
    artifact_type_labels = meta.artifact_type_labels or {},
    software_topic_labels = meta.software_topic_labels or {},
    supervision_topic_labels = meta.supervision_topic_labels or {},
    talk_role_labels = meta.talk_role_labels or {},
    teaching_topic_labels = meta.teaching_topic_labels or {}
  }
end

function M.tr(table_, key, fallback)
  if table_ and table_[key] then
    return pandoc.utils.stringify(table_[key])
  end

  return fallback or key
end

return M
