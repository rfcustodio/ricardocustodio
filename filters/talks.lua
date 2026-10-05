-- Talks page generator. Canonical source: data/talks.yml
local stringify=pandoc.utils.stringify
local function val(x) if x==nil then return nil end return stringify(x) end
local function esc(s)
  s=tostring(s or "")
  s=s:gsub("&","&amp;")
  s=s:gsub("<","&lt;")
  s=s:gsub(">","&gt;")
  s=s:gsub('"',"&quot;")
  return s
end
local labels={
 ["keynote"]="Keynote",["invited-talk"]="Invited talk",["conference-presentation"]="Conference presentation",
 ["workshop"]="Workshop",["tutorial"]="Tutorial",["panel"]="Panel",["roundtable"]="Roundtable",
 ["guest-lecture"]="Guest lecture",["institutional-talk"]="Institutional talk",["professional-talk"]="Professional talk"
}
local function badge(s) return '<span class="talk-badge">'..esc(s)..'</span>' end
local function card(t)
 local html='<article class="talk-card"><div class="talk-top"><div><h3>'..esc(val(t.title))..'</h3>'
 html=html..'<div class="talk-event">'..esc(val(t.event))..'</div></div>'
 html=html..'<div class="talk-year">'..esc(val(t.year))..'</div></div>'
 html=html..'<div class="talk-meta">'..badge(labels[val(t.type)] or val(t.type) or "Talk")
 if t.role then html=html..badge(val(t.role)) end
 html=html..'</div>'
 local details={}
 if t.date then table.insert(details,esc(val(t.date))) end
 if t.location then table.insert(details,esc(val(t.location))) end
 if #details>0 then html=html..'<div class="talk-details">'..table.concat(details," · ")..'</div>' end
 if t.notes then html=html..'<div class="talk-notes">'..esc(val(t.notes))..'</div>' end
 return pandoc.RawBlock("html",html..'</article>')
end
local function sortnew(a,b)
 local ay=tonumber(val(a.year)) or 0; local by=tonumber(val(b.year)) or 0
 if ay~=by then return ay>by end
 return (val(a.title) or "")<(val(b.title) or "")
end
local function choose(ts,pred)
 local r={}; for _,t in ipairs(ts) do if pred(t) then table.insert(r,t) end end
 table.sort(r,sortnew); return r
end
local function H(n,s) return pandoc.Header(n,{pandoc.Str(s)}) end
local function P(s) return pandoc.Para({pandoc.Str(s)}) end
local function addcards(blocks,items) for _,t in ipairs(items) do table.insert(blocks,card(t)) end end

function Pandoc(doc)
 local f=io.open("data/talks.yml","r"); if not f then return doc end
 local raw=f:read("*all"); f:close()
 local m=pandoc.read("---\n"..raw.."\n---","markdown").meta
 local ts=m.talks or {}; local b={}

 table.insert(b,H(2,"Selected Talks"))
 table.insert(b,P("A selection spanning digital trust, electronic documents, public-key infrastructure, identity, post-quantum cryptography, and artificial intelligence."))
 addcards(b,choose(ts,function(t) return val(t.selected)=="true" end))

 table.insert(b,H(2,"Recent Talks"))
 table.insert(b,P("Recent invited presentations, panels, workshops, and institutional talks."))
 addcards(b,choose(ts,function(t) return (tonumber(val(t.year)) or 0)>=2020 and val(t.selected)~="true" end))

 table.insert(b,H(2,"Browse by Type"))
 local groups={
  {"Invited Talks",{"invited-talk"}},
  {"Conference Presentations",{"conference-presentation"}},
  {"Panels & Roundtables",{"panel","roundtable"}},
  {"Tutorials & Workshops",{"tutorial","workshop"}},
  {"Professional & Institutional Talks",{"professional-talk","institutional-talk","guest-lecture"}}
 }
 for _,g in ipairs(groups) do
   local set={}; for _,x in ipairs(g[2]) do set[x]=true end
   local items=choose(ts,function(t) return set[val(t.type)] and (tonumber(val(t.year)) or 0)>=2012 end)
   if #items>0 then table.insert(b,H(3,g[1])); addcards(b,items) end
 end

 table.insert(b,H(2,"Historical Talks Archive"))
 table.insert(b,P("Earlier presentations reconstructed from the academic record. The archive is intentionally evidence-based: years with no documented talk remain gaps rather than being filled by inference."))
 local hist=choose(ts,function(t) return (tonumber(val(t.year)) or 0)<2012 end)
 local decades={{2000,2011,"2000–2011"},{1990,1999,"1990s"}}
 for _,d in ipairs(decades) do
   local items=choose(hist,function(t)
     local y=tonumber(val(t.year)) or 0; return y>=d[1] and y<=d[2]
   end)
   if #items>0 then table.insert(b,H(3,d[3])); addcards(b,items) end
 end

 for _,x in ipairs(b) do table.insert(doc.blocks,x) end
 return doc
end
