-- Academic Archive generator
-- Canonical historical model: data/archive.yml
-- Canonical metadata remain in their original registries.

local stringify = pandoc.utils.stringify

local function sval(x)
  if x == nil then return nil end
  return stringify(x)
end

local function esc(x)
  local s = tostring(x or "")
  s = s:gsub("&","&amp;")
  s = s:gsub("<","&lt;")
  s = s:gsub(">","&gt;")
  s = s:gsub('"',"&quot;")
  return s
end

local function read_yaml(path)
  local f=io.open(path,"r")
  if not f then return nil end
  local raw=f:read("*all"); f:close()
  return pandoc.read("---\n"..raw.."\n---","markdown").meta
end

local function H(n,s) return pandoc.Header(n,{pandoc.Str(s)}) end
local function P(s) return pandoc.Para({pandoc.Str(s)}) end

local registries = {}

local function index_records(collection, x)
  if x == nil then return end
  if x.t == "MetaMap" or type(x) == "table" then
    if x.id then
      local id=sval(x.id)
      local title=sval(x.title) or sval(x.name) or sval(x.label)
      if id and title then registries[collection..":"..id]={title=title, collection=collection} end
    end
    for _,v in pairs(x) do
      if type(v)=="table" then index_records(collection,v) end
    end
  end
end

local sources={
  projects="data/projects.yml",
  software="data/software.yml",
  texts="data/texts.yml",
  publications="data/publications.yml",
  supervision="data/supervision.yml",
  talks="data/talks.yml"
}
for collection,path in pairs(sources) do
  local m=read_yaml(path)
  if m then index_records(collection,m) end
end

local function ref_title(ref)
  local r=registries[ref]
  if r then return r.title end
  local _,id=ref:match("^([^:]+):(.+)$")
  return id or ref
end

local function collection_label(ref)
  local c=ref:match("^([^:]+):")
  local labels={
    projects="Project",software="Software & Data",texts="Books & Texts",
    publications="Publication",supervision="Supervision",talks="Talk"
  }
  return labels[c] or c or "Archive"
end

local function period_card(p)
  local html='<article class="archive-period">'
  html=html..'<div class="archive-period-years">'..esc(sval(p.years))..'</div>'
  html=html..'<h3>'..esc(sval(p.title))..'</h3>'
  html=html..'<p>'..esc(sval(p.narrative))..'</p>'
  if p.highlights and #p.highlights>0 then
    html=html..'<div class="archive-highlights">'
    for _,h in ipairs(p.highlights) do
      local ref=sval(h.ref)
      html=html..'<div class="archive-highlight">'
      html=html..'<span class="archive-dot"></span><div>'
      html=html..'<strong>'..esc(ref_title(ref))..'</strong>'
      html=html..'<div class="archive-small">'..esc(sval(h.years))..' · '..esc(collection_label(ref))..'</div>'
      html=html..'</div></div>'
    end
    html=html..'</div>'
  end
  return pandoc.RawBlock("html",html..'</article>')
end

local function genealogy_card(g)
  local html='<article class="genealogy-card">'
  html=html..'<h3>'..esc(sval(g.title))..'</h3>'
  html=html..'<p>'..esc(sval(g.summary))..'</p>'
  html=html..'<div class="genealogy-flow">'
  for i,n in ipairs(g.nodes or {}) do
    local ref=sval(n.ref)
    if i>1 then html=html..'<span class="genealogy-arrow" aria-hidden="true">→</span>' end
    html=html..'<div class="genealogy-node">'
    html=html..'<span class="genealogy-period">'..esc(sval(n.period))..'</span>'
    html=html..'<strong>'..esc(ref_title(ref))..'</strong>'
    html=html..'<span class="genealogy-kind">'..esc(collection_label(ref))..'</span>'
    html=html..'</div>'
  end
  html=html..'</div></article>'
  return pandoc.RawBlock("html",html)
end

function Pandoc(doc)
  local a=read_yaml("data/archive.yml")
  if not a then return doc end
  local b={}

  table.insert(b,H(2,"Historical Trajectory"))
  table.insert(b,P("The archive organizes my academic trajectory as a sequence of overlapping research periods. Period labels identify dominant themes rather than strict boundaries."))
  for _,p in ipairs(a.periods or {}) do table.insert(b,period_card(p)) end

  table.insert(b,H(2,"Research Genealogies"))
  table.insert(b,P("These genealogies show long-running research continuities across projects, publications, software, texts, supervision, and talks. Their sequence is historical and editorial; it does not by itself assert causality or derivation."))
  for _,g in ipairs(a.genealogies or {}) do table.insert(b,genealogy_card(g)) end

  table.insert(b,H(2,"About this Archive"))
  table.insert(b,P("This archive is evidence-based and metadata-centered. Canonical records remain in their original collections, while this page provides historical context and cross-collection interpretation. Gaps are preserved when documentary evidence is incomplete."))

  for _,x in ipairs(b) do table.insert(doc.blocks,x) end
  return doc
end
