-- Talks V1.3 — multilingual presentation over data/talks.yml
local project=require('lib.project'); local i18n=require('lib.i18n'); local stringify=pandoc.utils.stringify
local I,T={},{ }
local function setup(meta) I=i18n.load(i18n.meta_language(meta)); T=I.labels or {} end
local function tr(k,f) return i18n.tr(T,k,f) end
local function val(x) if x==nil then return nil end return stringify(x) end
local function esc(s) s=tostring(s or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'); return s end
local typekeys={['keynote']='keynote',['invited-talk']='invited_talk',['conference-presentation']='conference_presentation',['workshop']='workshop',['tutorial']='tutorial',['panel']='panel',['roundtable']='roundtable',['guest-lecture']='guest_lecture',['institutional-talk']='institutional_talk',['professional-talk']='professional_talk'}
local function type_label(x) local k=typekeys[x]; return k and tr(k,x) or x or tr('talk','Talk') end
local function role_label(x) return i18n.tr(I.talk_role_labels,x,x) end
local function badge(s) return '<span class="talk-badge">'..esc(s)..'</span>' end
local function card(t)
 local html='<article class="talk-card"><div class="talk-top"><div><h3>'..esc(val(t.title))..'</h3><div class="talk-event">'..esc(val(t.event))..'</div></div><div class="talk-year">'..esc(val(t.year))..'</div></div>'
 html=html..'<div class="talk-meta">'..badge(type_label(val(t.type))); if t.role then html=html..badge(role_label(val(t.role))) end; html=html..'</div>'
 local d={}; if t.date then table.insert(d,esc(val(t.date))) end; if t.location then table.insert(d,esc(val(t.location))) end; if #d>0 then html=html..'<div class="talk-details">'..table.concat(d,' · ')..'</div>' end
 if t.notes then html=html..'<div class="talk-notes">'..esc(val(t.notes))..'</div>' end
 return pandoc.RawBlock('html',html..'</article>')
end
local function sortnew(a,b) local ay=tonumber(val(a.year)) or 0; local by=tonumber(val(b.year)) or 0; if ay~=by then return ay>by end; return (val(a.title) or '')<(val(b.title) or '') end
local function choose(ts,pred) local r={}; for _,t in ipairs(ts) do if pred(t) then table.insert(r,t) end end; table.sort(r,sortnew); return r end
local function H(n,s) return pandoc.Header(n,{pandoc.Str(s)}) end; local function P(s) return pandoc.Para({pandoc.Str(s)}) end
local function add(b,a) for _,x in ipairs(a) do table.insert(b,card(x)) end end
local function render(doc)
 local m=project.yaml_meta('data/talks.yml'); local ts=m.talks or {}; local b={}
 table.insert(b,H(2,tr('selected_talks','Selected Talks'))); table.insert(b,P(tr('selected_talks_intro','Selected talks.'))); add(b,choose(ts,function(t) return val(t.selected)=='true' end))
 table.insert(b,H(2,tr('recent_talks','Recent Talks'))); table.insert(b,P(tr('recent_talks_intro','Recent talks.'))); add(b,choose(ts,function(t) return (tonumber(val(t.year)) or 0)>=2020 and val(t.selected)~='true' end))
 table.insert(b,H(2,tr('browse_by_type','Browse by Type')))
 local groups={{tr('invited_talks','Invited Talks'),{'invited-talk'}},{tr('conference_presentations','Conference Presentations'),{'conference-presentation'}},{tr('panels_roundtables','Panels & Roundtables'),{'panel','roundtable'}},{tr('tutorials_workshops','Tutorials & Workshops'),{'tutorial','workshop'}},{tr('professional_institutional_talks','Professional & Institutional Talks'),{'professional-talk','institutional-talk','guest-lecture'}}}
 for _,g in ipairs(groups) do local set={}; for _,x in ipairs(g[2]) do set[x]=true end; local a=choose(ts,function(t) return set[val(t.type)] and (tonumber(val(t.year)) or 0)>=2012 end); if #a>0 then table.insert(b,H(3,g[1])); add(b,a) end end
 table.insert(b,H(2,tr('historical_talks_archive','Historical Talks Archive'))); table.insert(b,P(tr('historical_talks_intro','Earlier presentations reconstructed from the academic record.')))
 local hist=choose(ts,function(t) return (tonumber(val(t.year)) or 0)<2012 end); for _,d in ipairs({{2000,2011,'2000–2011'},{1990,1999,'1990s'}}) do local a=choose(hist,function(t) local y=tonumber(val(t.year)) or 0; return y>=d[1] and y<=d[2] end); if #a>0 then table.insert(b,H(3,d[3])); add(b,a) end end
 for _,x in ipairs(b) do table.insert(doc.blocks,x) end; return doc
end
return {{Meta=function(meta) setup(meta); return nil end},{Pandoc=render}}
