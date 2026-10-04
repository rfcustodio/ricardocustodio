local stringify = pandoc.utils.stringify

local function read_yaml(path)
  local file = io.open(path, "r")
  if not file then
    io.stderr:write("supervision.lua: cannot open " .. path .. "\n")
    return nil
  end

  local content = file:read("*all")
  file:close()

  local ok, doc = pcall(
    pandoc.read,
    "---\n" .. content .. "\n---\n",
    "markdown"
  )

  if not ok then
    io.stderr:write("supervision.lua: error parsing " .. path .. "\n")
    return nil
  end

  return doc.meta
end

local function text(value)
  if value == nil then
    return ""
  end
  return stringify(value)
end

local function student_name(record)
  if record.student and record.student.name then
    return text(record.student.name)
  end
  return ""
end

local function end_year(record)
  if record["end"] then
    return tonumber(text(record["end"])) or 0
  end
  return 0
end

local function repository_url(record)
  if record.thesis and record.thesis.persistent_url then
    local url = text(record.thesis.persistent_url)
    if url ~= "" then
      return url
    end
  end
  return nil
end

local function topic_label(topic)
  local labels = {
    ["cryptography"] = "Cryptography",
    ["post-quantum-cryptography"] = "Post-Quantum Cryptography",
    ["digital-signatures"] = "Digital Signatures",
    ["hash-based-signatures"] = "Hash-Based Signatures",
    ["digital-identity"] = "Digital Identity",
    ["self-sovereign-identity"] = "Self-Sovereign Identity",
    ["public-key-infrastructure"] = "Public-Key Infrastructure",
    ["electronic-documents"] = "Electronic Documents",
    ["digital-trust"] = "Digital Trust",
    ["information-security"] = "Information Security",
    ["long-term-preservation"] = "Long-Term Preservation",
    ["cryptographic-protocols"] = "Cryptographic Protocols",
    ["network-security"] = "Network Security",
    ["secret-sharing"] = "Secret Sharing",
    ["blockchain"] = "Blockchain",
    ["tls"] = "TLS",
    ["code-based-cryptography"] = "Code-Based Cryptography",
    ["lattice-based-cryptography"] = "Lattice-Based Cryptography",
    ["isogeny-based-cryptography"] = "Isogeny-Based Cryptography"
  }

  return labels[topic] or topic
end

local function topics(record)
  local result = {}

  if record.topics then
    for _, topic in ipairs(record.topics) do
      table.insert(result, topic_label(text(topic)))
    end
  end

  return result
end

local function select_records(records, level, status)
  local result = {}

  for _, record in ipairs(records) do
    if text(record.level) == level
       and text(record.status) == status then
      table.insert(result, record)
    end
  end

  if status == "current" then
    table.sort(result, function(a, b)
      return student_name(a):lower() < student_name(b):lower()
    end)
  else
    table.sort(result, function(a, b)
      local ya = end_year(a)
      local yb = end_year(b)

      if ya ~= yb then
        return ya > yb
      end

      return student_name(a):lower() < student_name(b):lower()
    end)
  end

  return result
end

local function current_card(record, level_label)
  local name = student_name(record)
  local title = text(record.title)
  local research_topics = topics(record)

  local blocks = {}

  table.insert(
    blocks,
    pandoc.Header(3, pandoc.Str(name))
  )

  table.insert(
    blocks,
    pandoc.Para({
      pandoc.Strong({
        pandoc.Str(level_label)
      }),
      pandoc.Str(" · Universidade Federal de Santa Catarina")
    })
  )

  if title ~= "" then
    table.insert(
      blocks,
      pandoc.Para({
        pandoc.Emph({pandoc.Str(title)})
      })
    )
  end

  if #research_topics > 0 then
    local inlines = {}

    for i, topic in ipairs(research_topics) do
      if i > 1 then
        table.insert(inlines, pandoc.Str(" · "))
      end
      table.insert(inlines, pandoc.Str(topic))
    end

    table.insert(
      blocks,
      pandoc.Para(inlines)
    )
  end

  return pandoc.Div(
    blocks,
    pandoc.Attr("", {"supervision-card"})
  )
end

local function completed_item(record)
  local name = student_name(record)
  local year = end_year(record)
  local title = text(record.title)
  local url = repository_url(record)

  local inlines = {
    pandoc.Strong({pandoc.Str(name)})
  }

  if year > 0 then
    table.insert(
      inlines,
      pandoc.Str(" (" .. tostring(year) .. ")")
    )
  end

  if title ~= "" then
    table.insert(inlines, pandoc.Str(" — "))
    table.insert(
      inlines,
      pandoc.Emph({pandoc.Str(title)})
    )
  end

    if url then
    local level = text(record.level)
    local link_label = "Academic work"

    if level == "phd" then
      link_label = "Dissertation"
    elseif level == "masters" then
      link_label = "Master's thesis"
    end

    table.insert(inlines, pandoc.Str(" · "))
    table.insert(
      inlines,
      pandoc.Link(
        {pandoc.Str(link_label)},
        url
      )
    )
  end
  
  return {pandoc.Plain(inlines)}
end

local function current_section(records, level, label, student_label)
  local selected = select_records(records, level, "current")
  local blocks = {}

  table.insert(
    blocks,
    pandoc.Header(
      2,
      pandoc.Str(label .. " (" .. #selected .. ")")
    )
  )

  if #selected == 0 then
    table.insert(
      blocks,
      pandoc.Para({
        pandoc.Emph({
          pandoc.Str("No current students listed.")
        })
      })
    )
    return blocks
  end

  local cards = {}

  for _, record in ipairs(selected) do
    table.insert(
      cards,
      current_card(record, student_label)
    )
  end

  table.insert(
    blocks,
    pandoc.Div(
      cards,
      pandoc.Attr("", {"supervision-grid"})
    )
  )

  return blocks
end

local function completed_section(records, level, label)
  local selected = select_records(records, level, "completed")
  local blocks = {}

  table.insert(
    blocks,
    pandoc.Header(
      2,
      pandoc.Str(label .. " (" .. #selected .. ")")
    )
  )

  if #selected == 0 then
    table.insert(
      blocks,
      pandoc.Para({
        pandoc.Emph({
          pandoc.Str("No completed supervisions listed.")
        })
      })
    )
    return blocks
  end

  -- PhD supervisions are few enough to display directly.
  if level == "phd" then
    local items = {}

    for _, record in ipairs(selected) do
      table.insert(items, completed_item(record))
    end

    table.insert(blocks, pandoc.BulletList(items))
    return blocks
  end

  -- Master's supervisions are grouped chronologically.
  local periods = {
    {
      label = "2020–2026",
      min_year = 2020,
      max_year = 2026,
      records = {}
    },
    {
      label = "2010–2019",
      min_year = 2010,
      max_year = 2019,
      records = {}
    },
    {
      label = "2000–2009",
      min_year = 2000,
      max_year = 2009,
      records = {}
    },
    {
      label = "Before 2000",
      min_year = 0,
      max_year = 1999,
      records = {}
    }
  }

  local unknown = {}

  for _, record in ipairs(selected) do
    local year = end_year(record)
    local placed = false

    if year > 0 then
      for _, period in ipairs(periods) do
        if year >= period.min_year and year <= period.max_year then
          table.insert(period.records, record)
          placed = true
          break
        end
      end
    end

    if not placed then
      table.insert(unknown, record)
    end
  end

  for _, period in ipairs(periods) do
    if #period.records > 0 then
      local items = {}

      for _, record in ipairs(period.records) do
        table.insert(items, completed_item(record))
      end

      local summary = pandoc.RawBlock(
        "html",
        '<details class="supervision-period">' ..
        '<summary>' ..
        period.label ..
        ' <span class="supervision-count">(' ..
        #period.records ..
        ')</span></summary>'
      )

      table.insert(blocks, summary)
      table.insert(blocks, pandoc.BulletList(items))
      table.insert(blocks, pandoc.RawBlock("html", "</details>"))
    end
  end

  if #unknown > 0 then
    local items = {}

    for _, record in ipairs(unknown) do
      table.insert(items, completed_item(record))
    end

    table.insert(
      blocks,
      pandoc.RawBlock(
        "html",
        '<details class="supervision-period">' ..
        '<summary>Year to be verified ' ..
        '<span class="supervision-count">(' ..
        #unknown ..
        ')</span></summary>'
      )
    )

    table.insert(blocks, pandoc.BulletList(items))
    table.insert(blocks, pandoc.RawBlock("html", "</details>"))
  end

  return blocks
end

local function append(target, source)
  for _, block in ipairs(source) do
    table.insert(target, block)
  end
end

function Div(div)
  if not div.classes:includes("supervision-generated") then
    return nil
  end

  local meta = read_yaml("data/supervision.yml")

  if not meta or not meta.supervisions then
    return pandoc.Div({
      pandoc.Para({
        pandoc.Strong({
          pandoc.Str("Unable to load supervision data.")
        })
      })
    })
  end

  local records = meta.supervisions
  local blocks = {}

  append(
    blocks,
    current_section(
      records,
      "phd",
      "Current PhD Students",
      "PhD student"
    )
  )

  append(
    blocks,
    current_section(
      records,
      "masters",
      "Current Master's Students",
      "Master's student"
    )
  )

  append(
    blocks,
    completed_section(
      records,
      "phd",
      "Former PhD Students"
    )
  )

  append(
    blocks,
    completed_section(
      records,
      "masters",
      "Former Master's Students"
    )
  )

  return pandoc.Div(blocks)
end
