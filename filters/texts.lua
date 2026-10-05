-- Books & Texts page generator
-- Reads data/texts.yml and creates a curated page from the canonical registry.

local stringify = pandoc.utils.stringify

local function esc(s)
  s = tostring(s or "")
  s = s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
  return s
end

local function join_authors(a)
  if type(a) ~= "table" then return "" end
  local names = {}
  for _,v in ipairs(a) do table.insert(names, stringify(v)) end
  return table.concat(names, ", ")
end

local function value(x)
  if x == nil then return nil end
  if type(x) == "table" then return stringify(x) end
  return tostring(x)
end

local function badge(text, cls)
  return '<span class="text-badge '..cls..'">'..esc(text)..'</span>'
end

local function evidence_badge(w)
  local e = value(w.evidence_status) or ""
  local s = value(w.status) or ""
  if s == "identified" then return badge("Document identified","evidence-identified") end
  if e == "externally-corroborated" then return badge("Externally corroborated","evidence-corroborated") end
  if e == "institutionally-contextualized" then return badge("Institutional context","evidence-context") end
  if e == "academically-contextualized" then return badge("Academic context","evidence-context") end
  if e == "project-contextualized" then return badge("Project context","evidence-context") end
  return badge("Bibliographic record","evidence-record")
end

local labels = {
  ["book"]="Book",
  ["book-chapter"]="Book chapter",
  ["commentary"]="Commentary",
  ["technical-report"]="Technical report",
  ["scientific-text"]="Scientific text",
  ["teaching-material"]="Teaching material"
}

local function citation_line(w)
  local bits={}
  if w.publisher then table.insert(bits, esc(value(w.publisher))) end
  if w.container then table.insert(bits, esc(value(w.container))) end
  if w.place then table.insert(bits, esc(value(w.place))) end
  if w.volume then table.insert(bits, "vol. "..esc(value(w.volume))) end
  if w.pages then table.insert(bits, esc(value(w.pages)).." pp.") end
  if w.isbn then table.insert(bits, "ISBN "..esc(value(w.isbn))) end
  return table.concat(bits, " · ")
end

local function card(w)
  local typ=value(w.type) or "text"
  local year=value(w.year) or ""
  local html='<article class="text-work">'
  html=html..'<div class="text-work-top"><div>'
  html=html..'<h3>'..esc(value(w.title))..'</h3>'
  local authors=join_authors(w.authors)
  if authors~="" then html=html..'<div class="text-authors">'..esc(authors)..'</div>' end
  html=html..'</div><div class="text-year">'..esc(year)..'</div></div>'
  html=html..'<div class="text-meta">'..badge(labels[typ] or typ,"type-badge")..evidence_badge(w)..'</div>'
  local cite=citation_line(w)
  if cite~="" then html=html..'<div class="text-citation">'..cite..'</div>' end
  html=html..'</article>'
  return pandoc.RawBlock("html",html)
end

local function sort_newest(a,b)
  local ay=tonumber(value(a.year)) or 0
  local by=tonumber(value(b.year)) or 0
  if ay~=by then return ay>by end
  return (value(a.title) or "") < (value(b.title) or "")
end

local function select(works, types, predicate)
  local set={}
  for _,t in ipairs(types) do set[t]=true end
  local r={}
  for _,w in ipairs(works) do
    if set[value(w.type)] and (not predicate or predicate(w)) then table.insert(r,w) end
  end
  table.sort(r,sort_newest)
  return r
end

local function heading(level,text)
  return pandoc.Header(level,{pandoc.Str(text)})
end

local function paragraph(text)
  return pandoc.Para({pandoc.Str(text)})
end

local function section(blocks,title,intro,items)
  table.insert(blocks,heading(2,title))
  if intro then table.insert(blocks,paragraph(intro)) end
  for _,w in ipairs(items) do table.insert(blocks,card(w)) end
end

function Pandoc(doc)
  local f=io.open("data/texts.yml","r")
  if not f then return doc end
  local raw=f:read("*all"); f:close()
  local meta=pandoc.read("---\n"..raw.."\n---","markdown").meta
  local works=meta.works or {}

  local blocks={}
  section(blocks,"Books",
    "Books and longer-form works authored or co-authored by Ricardo Custódio.",
    select(works,{"book"}))

  section(blocks,"Book Chapters & Commentary",
    "Selected chapters, tutorials, and commentary maintained as long-form scholarly or professional texts.",
    select(works,{"book-chapter","commentary"}))

  local recovered=select(works,{"technical-report","scientific-text"},function(w)
    return value(w.status)=="identified"
  end)
  if #recovered>0 then
    section(blocks,"Technical & Scientific Texts",
      "Technical and scientific texts for which a document has already been identified.",
      recovered)
  end

  section(blocks,"Teaching Materials",
    "Teaching-oriented texts and instructional material preserved as part of the academic record.",
    select(works,{"teaching-material"}))

  local historical=select(works,{"technical-report","scientific-text"},function(w)
    return value(w.status)~="identified"
  end)
  table.insert(blocks,heading(2,"Historical Archive"))
  table.insert(blocks,pandoc.Para({
    pandoc.Str("Historical technical and scientific texts identified in the academic record. "),
    pandoc.Str("Some original digital copies are still being recovered from personal, LabSEC, UFSC, and institutional archives.")
  }))
  if #historical>0 then
    local inner={}
    for _,w in ipairs(historical) do table.insert(inner,card(w)) end
    local div=pandoc.Div(inner,pandoc.Attr("",{"historical-texts"}))
    table.insert(blocks,div)
  end

  for _,b in ipairs(blocks) do table.insert(doc.blocks,b) end
  return doc
end
