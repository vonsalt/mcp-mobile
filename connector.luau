local a={cache={}::any}do do local function __modImpl()return function(b)
local c=b.HttpService
local d=b.BridgeURL
local e=b.WebSocketAvailable
local f=b.GetRegistrationInfo
local g=b.SanitizeForOutput
local h=b.LuaEncode


local i={};do
i.__index=i

function i.BindToType(j,k,l)
j.Callbacks[k]=l
end

function i.BindToTypeRaw(j,k,l)
j.Callbacks[k]=l
j.RawCallbacks=j.RawCallbacks or{}
j.RawCallbacks[k]=true
end

function i.CreateAlias(j,k,l)
for m,n in l do
j.Callbacks[n]=j.Callbacks[k]
if j.RawCallbacks and j.RawCallbacks[k]then
j.RawCallbacks[n]=true
end
end
end

function i.HandleMessage(j,k)
if j.Callbacks[k.type]then
local l,m=pcall(function()
return j.Callbacks[k.type](k)
end)

if l and m==nil then
return nil
end

if not l then
return j:FormatResponse(m,k.id,true)
end

if j.RawCallbacks and j.RawCallbacks[k.type]then
return{
output=tostring(m),
success=true,
id=k.id
}
end

return j:FormatResponse(m,k.id,false)
end
return nil
end

function i.FormatResponse(j,k,l,m)
if m then
return{
error=tostring(k),
success=false,
id=l
}
end

local n=g(k)
if typeof(n)~="table"then
n={n}
end

return{
output=h(n,{
Prettify=false
}),
success=true,
id=l
}
end

function i.IsAlive(j)
local k,l=pcall(function()
local k
local l=task.spawn(function()
local l,m=pcall(request,{
Url="http://"..d,
Method="GET"
})

if l then
k=m
end
end)

local m=os.clock()
repeat task.wait(0.05)until k~=nil or os.clock()-m>5

if k==nil then
task.cancel(l)
return false
end


if k.StatusCode==426 or k.StatusCode==200 then
return true
end

return false
end)

if not k then
return false
end

return l
end
end


local j=setmetatable({},{__index=i});do
j.__index=j

function j.new()
local k=setmetatable({},j)


local l=0.5
local m=5
local n=10
local o=0

while not k:IsAlive()do
o+=1
if o>=n then
error("Failed to connect to bridge server after "..n.." attempts")
end
task.wait(l)
l=math.min(l*1.5,m)
end


local p
local q=task.spawn(function()
local q,r=pcall(function()
return WebSocket.connect("ws://"..d)
end)
if q then
p=r
end
end)

local r=os.clock()
repeat task.wait(0.05)until p~=nil or os.clock()-r>5

if p==nil then
task.cancel(q)
error"WebSocket connection timed out after 5 seconds"
end

k.WebSocket=p
k.Connected=true
k.Callbacks={}
k.ClientId=nil


k.WebSocket:Send(c:JSONEncode(f()))

k.AliveThread=task.spawn(function()
local s=0
while task.wait(1)do
if not k.Connected then
continue
end





if k.WebSocket then


s=0
continue
end


if k:IsAlive()then
s=0
continue
end

s+=1
if s<3 then
continue
end

k.Connected=false
break
end

pcall(function()
k.WebSocket:Close()
end)
end)


k.WebSocket.OnMessage:Connect(function(s)
local t=c:JSONDecode(s)


if t.type=="registered"then
k.ClientId=t.clientId
return
end

local u=k:HandleMessage(t)
if u then
k.WebSocket:Send(c:JSONEncode(u))
end
end)


k.WebSocket.OnClose:Connect(function()
k.Connected=false

end)


if k.WebSocket.OnError then
k.WebSocket.OnError:Connect(function()
k.Connected=false
end)
end

return k
end

function j.WaitForDisconnect(k)
while k.Connected do
task.wait(0.1)
end
end
end


local k=setmetatable({},{__index=i});do
k.__index=k

function k.new()
local l=setmetatable({},k)


local m=0.5
local n=5
local o=10
local p=0

while not l:IsAlive()do
p+=1
if p>=o then
error("Failed to connect to bridge server after "..o.." attempts")
end
task.wait(m)
m=math.min(m*1.5,n)
end

l.Connected=true
l.Callbacks={}
l.PollInterval=0.1
l.ClientId=nil


pcall(function()
local q=request{
Url="http://"..d.."/register",
Method="POST",
Headers={["Content-Type"]="application/json"},
Body=c:JSONEncode(f()),
}
if q.StatusCode==200 and q.Body then
local r=c:JSONDecode(q.Body)
l.ClientId=r.clientId
end
end)


l.PollThread=task.spawn(function()
local q=0

while l.Connected do
local r=false local
s=pcall(function()
local s="http://"..d.."/poll"
if l.ClientId then
s=s.."?clientId="..l.ClientId
end
local t=request{
Url=s,
Method="GET"
}


if t.StatusCode~=204 and t.StatusCode~=200 then
q+=1
if q>=3 then
l.Connected=false
end

return
end

q=0


if t.Body and t.Body~=""then
local u=c:JSONDecode(t.Body)
local v={}
if typeof(u)=="table"and u.type==nil and#u>0 then
v=u
elseif typeof(u)=="table"and u.type~=nil then
v={u}
end

for w,x in ipairs(v)do
r=true
task.spawn(function()
local y=l:HandleMessage(x)
if y==nil then return end


request{
Url="http://"..d.."/respond",
Method="POST",
Headers={
["Content-Type"]="application/json"
},
Body=c:JSONEncode(y)
}
end)
end
end
end)

if not s then
q+=1
if q>=3 then
l.Connected=false
end
end

if not r then
task.wait(l.PollInterval)
end
end
end)

return l
end

function k.WaitForDisconnect(l)
while l.Connected do
task.wait(0.1)
end
end
end


local function CreateBridge()
if e then
local l,m=pcall(function()
return j.new()
end)

if l then
return m
end
end

return k.new()
end

return{
CreateBridge=CreateBridge,
}
end end function a.a():typeof(__modImpl())local b=a.cache.a if not b then b={c=__modImpl()}a.cache.a=b end return b.c end end do local function __modImpl()

local b={}
b.__index=b

function b.new(c)
local d=setmetatable(c,b)
d.Queue={}
d.QueueHead=1
d.QueueTail=0
d.ActiveWorkers=0
d.ManagerGeneration=0
d.IsDestroyed=false
d.TaskLibrary=c.TaskLibrary or task
d:Reset()
return d
end

function b.QueueOperation(c,...)
if c.IsDestroyed then return end
c.QueueTail+=1
c.Queue[c.QueueTail]=table.pack(...)
c:DrainQueue()
end

function b.DrainQueue(c,d)
if c.IsDestroyed then return end
if d~=nil and c.ManagerGeneration~=d then return end

local e=c.ManagerGeneration
while c.ActiveWorkers<c.MaxConcurrent and c.QueueHead<=c.QueueTail do
local f=c.Queue[c.QueueHead]
c.Queue[c.QueueHead]=nil
c.QueueHead+=1
if not f then continue end

c.ActiveWorkers+=1
c.TaskLibrary.defer(function()
local g=f
while g do
if not c.IsDestroyed and c.ManagerGeneration==e then
local h,i=pcall(
c.MainCallback,
table.unpack(g,1,g.n)
)
if not h then
if c.OnError then
pcall(
c.OnError,
i,
table.unpack(g,1,g.n)
)
end
end
end

if c.IsDestroyed or c.ManagerGeneration~=e or c.ActiveWorkers>c.MaxConcurrent then
break
end

if c.QueueHead<=c.QueueTail then
g=c.Queue[c.QueueHead]
c.Queue[c.QueueHead]=nil
c.QueueHead+=1
else
g=nil
end
end



c.ActiveWorkers=math.max(0,c.ActiveWorkers-1)
c:DrainQueue()
end)
end
end

function b.Reset(c)
if c.IsDestroyed then return end
c.Queue={}
c.QueueHead=1
c.QueueTail=0
c.ManagerGeneration+=1
c:DrainQueue()
end

function b.SetMaxConcurrent(c,d)
c.MaxConcurrent=math.max(1,math.floor(tonumber(d)or 1))
c:DrainQueue()
end

function b.Destroy(c)
if c.IsDestroyed then return end
c.IsDestroyed=true
table.clear(c.Queue)
c.QueueHead=1
c.QueueTail=0
end

b.Stop=b.Destroy

return b end function a.b():typeof(__modImpl())local b=a.cache.b if not b then b={c=__modImpl()}a.cache.b=b end return b.c end end do local function __modImpl()

local b={}
b.__index=b

local c={
mapped=true,
failed=true,
}

local d={
queued={mapping=true,deferred=true,awaiting_upload=true,failed=true,removed=true},
mapping={queued=true,deferred=true,awaiting_upload=true,failed=true,removed=true},
deferred={queued=true,awaiting_upload=true,failed=true,removed=true},
awaiting_upload={mapped=true,failed=true,removed=true},
mapped={removed=true},
failed={queued=true,removed=true},
removed={},
}

function b.new()
return setmetatable({
jobs={},
instances=setmetatable({},{__mode="v"}),
total=0,
processed=0,
skipped=0,
disabled=false,
statusDirty=false,
clientId=nil,
workers=nil,
configuredWorkers=0,
currentWorkers=0,
successesSinceWorkerAdjustment=0,
descendantConnection=nil,
initialScanRunning=false,
initialScanFinished=false,
generation=0,
session=nil,
stateVersion=0,
upload={
queue={},
head=1,
tail=0,
bytes=0,
thread=nil,
},
bridge=nil,
sourceCacheByHash={},
sourceCacheCheckedByHash={},
scriptHashByDebugId={},
},b)
end

function b.IsActiveSession(e,f,g,h)
return(
e.session==f and
e.generation==g and
e.clientId==h
)
end

function b.IsFinished(e,f)
local g=f==nil and e.processed or f
return e.disabled or(
e.initialScanFinished and
g>=e.total
)
end

function b.Reset(e,f,g)
e.generation+=1
e.session=g
e.stateVersion=0
e.currentWorkers=e.configuredWorkers
e.successesSinceWorkerAdjustment=0
e.jobs={}
e.instances=setmetatable({},{__mode="v"})
e.total=0
e.processed=0
e.skipped=0
e.statusDirty=true
e.disabled=false
e.clientId=f
e.scriptHashByDebugId={}
e.sourceCacheCheckedByHash={}
e.initialScanRunning=false
e.initialScanFinished=false
end

function b.EnsureJob(e,f)
local g=e.jobs[f]
if g then return g,false end

g={debugId=f,generation=e.generation}
e.jobs[f]=g
e.total+=1
e.stateVersion+=1
e.statusDirty=true
return g,true
end

function b.TrackJob(e,f)
local g=e.jobs[f]
if g and g.state~="failed"then return nil end

if not g then
g=e:EnsureJob(f)
else
g.generation=e.generation
end
g.mappingAttempts=0
e:SetJobState(g,"queued")
return g
end

function b.TryStartMapping(e,f)
if e.jobs[f.debugId]~=f or f.generation~=e.generation then return false end
if f.state~="queued"then return false end
e:SetJobState(f,"mapping")
return true
end

function b.CanDeferScanJob(e,f,g)
return(
f~=nil and
f.generation==g and
g==e.generation and
f.state=="queued"
)
end

function b.SetJobState(e,f,g)
local h=f.state
if h==g then return false end
if h~=nil and not d[h][g]then
error("Invalid script mapping transition: "..tostring(h).." -> "..tostring(g))
end

if h=="mapped"then
e.processed=math.max(0,e.processed-1)
elseif h=="failed"then
e.processed=math.max(0,e.processed-1)
e.skipped=math.max(0,e.skipped-1)
end

if g=="mapped"then
e.processed+=1
elseif g=="failed"then
e.processed+=1
e.skipped+=1
elseif g=="removed"then
e.total=math.max(0,e.total-1)
end

f.state=g
if c[h]or c[g]or g=="removed"then
e.stateVersion+=1
e.statusDirty=true
end
return true
end

return b end function a.c():typeof(__modImpl())local b=a.cache.c if not b then b={c=__modImpl()}a.cache.c=b end return b.c end end do local function __modImpl()

local b={}
b.__index=b
local c=0

function b.new(d,e,f)
local g=math.max(0,math.floor(tonumber(e)or 0))
local h=math.max(g,c+1)
c=h
return setmetatable({
id=d,
startedAt=h,
generation=f,
revision=0,
started=false,
},b)
end

function b.NextRevision(d)
d.revision+=1
return d.revision
end

function b.MarkStarted(d)
d.started=true
end

return b end function a.d():typeof(__modImpl())local b=a.cache.d if not b then b={c=__modImpl()}a.cache.d=b end return b.c end end do local function __modImpl()

local b={}

function b.CanAttemptBuiltIn(c,d,e)
return(
c.builtinAttempted~=true and
c.builtinDisabled~=true and
d<=e
)
end

function b.MarkBuiltInAttempted(c)
c.builtinAttempted=true
end

function b.DisableBuiltIn(c)
c.builtinAttempted=true
c.builtinDisabled=true
c.useDirectBuiltin=false
end

return b end function a.e():typeof(__modImpl())local b=a.cache.e if not b then b={c=__modImpl()}a.cache.e=b end return b.c end end do local function __modImpl()

local b=a.e()

local c={}

function c.MaterializeServerFallback(d,e)
b.DisableBuiltIn(d)
if type(d.bytecode)=="string"then
return true
end

local f,g=e()
if not f then
return false,g
end

d.bytecode=g
return true
end

return c end function a.f():typeof(__modImpl())local b=a.cache.f if not b then b={c=__modImpl()}a.cache.f=b end return b.c end end do local function __modImpl()

local b={}
b.__index=b

function b.new(c,d)
c.configuredWorkers=d
c.currentWorkers=d
return setmetatable({pipeline=c},b)
end

function b.Reduce(c)
local d=c.pipeline
local e=math.max(4,math.floor(d.currentWorkers/2))
if e>=d.currentWorkers then return end

d.currentWorkers=e
d.successesSinceWorkerAdjustment=0
if d.workers then
d.workers:SetMaxConcurrent(e)
end
end

function b.RecordSuccess(c)
local d=c.pipeline
if d.currentWorkers>=d.configuredWorkers then return end

d.successesSinceWorkerAdjustment+=1
if d.successesSinceWorkerAdjustment<100 then return end

d.successesSinceWorkerAdjustment=0
d.currentWorkers+=1
if d.workers then
d.workers:SetMaxConcurrent(d.currentWorkers)
end
end

return b end function a.g():typeof(__modImpl())local b=a.cache.g if not b then b={c=__modImpl()}a.cache.g=b end return b.c end end do local function __modImpl()

local b={}
b.__index=b

function b.new(c,d)
d=d or{}
return setmetatable({
pipeline=c,
clock=d.Clock or os.clock,
taskLibrary=d.TaskLibrary or task,
intervalSeconds=d.IntervalSeconds or 30,
maxDelaySeconds=d.MaxDelaySeconds or 300,
batchSize=d.BatchSize or 8,
thread=nil,
},b)
end

function b.Schedule(c,d)
local e=math.max(0,d.resyncRounds or 0)
local f=math.min(
c.intervalSeconds*(2^e),
c.maxDelaySeconds
)
d.nextResyncAt=c.clock()+f
end

function b.Cancel(c,d)
d.nextResyncAt=nil
d.resyncRounds=nil
end

function b.Defer(c,d)
d.nextResyncAt=c.clock()+c.intervalSeconds
end

function b.GetDue(c,d)
d=d or c.clock()
local e={}
for f,g in c.pipeline.jobs do
if(
g.generation==c.pipeline.generation and
g.state=="failed"and
type(g.nextResyncAt)=="number"and
g.nextResyncAt<=d
)then
table.insert(e,g)
end
end

table.sort(e,function(f,g)
if f.nextResyncAt==g.nextResyncAt then
return f.debugId<g.debugId
end
return f.nextResyncAt<g.nextResyncAt
end)
while#e>c.batchSize do
table.remove(e)
end
return e
end

function b.Claim(c,d,e)
e=e or c.clock()
if c.pipeline.jobs[d.debugId]~=d then return false end
if d.generation~=c.pipeline.generation or d.state~="failed"then return false end
if type(d.nextResyncAt)~="number"or d.nextResyncAt>e then return false end

d.resyncRounds=(d.resyncRounds or 0)+1
d.nextResyncAt=nil
d.errorMessage=nil
return c.pipeline:TrackJob(d.debugId)==d
end

function b.Start(c,d)
if c.thread then return end
c.thread=c.taskLibrary.spawn(function()
while true do
c.taskLibrary.wait(c.intervalSeconds)
pcall(d)
end
end)
end

function b.ProcessDue(c,d,e)
for f,g in c:GetDue()do
local h,i=pcall(d,g)
if not h then
if e then
e(g,i)
else
c:Defer(g)
end
end
end
end

return b end function a.h():typeof(__modImpl())local b=a.cache.h if not b then b={c=__modImpl()}a.cache.h=b end return b.c end end do local function __modImpl()

local b={}
b.__index=b
local c=warn or print

function b.new(d,e)
return setmetatable({
pipeline=d,
failedResync=e,
},b)
end

function b.Publish(d)
d.pipeline.statusDirty=true
end

function b.MarkMapped(d,e,f)
local g=d.pipeline
local h=g.jobs[e]
if h and(h.state=="mapped"or h.state=="failed"or h.state=="removed")then
return false
end

if not h then
h=g:EnsureJob(e)
end

g:SetJobState(h,"mapped")
if d.failedResync then d.failedResync:Cancel(h)end
h.prepared=nil
h.script=nil
if f~=false then d:Publish()end
return true
end

function b.MarkFailed(d,e,f,g)
local h=d.pipeline
local i=h.jobs[e]
if i and(i.state=="mapped"or i.state=="failed"or i.state=="removed")then
return false
end

if not i then
i=h:EnsureJob(e)
end

h:SetJobState(i,"failed")
if d.failedResync then d.failedResync:Schedule(i)end
i.errorMessage=tostring(f or"unknown error")
i.prepared=nil
i.script=nil
c("[Roblox Executor MCP] Script mapping skipped "..tostring(e)..": "..tostring(f or"unknown error"))
if g~=false then d:Publish()end
return true
end

return b end function a.i():typeof(__modImpl())local b=a.cache.i if not b then b={c=__modImpl()}a.cache.i=b end return b.c end end do local function __modImpl()

return function(b)
local c=b.ScriptMappingPipeline
local d=b.HttpService
local e=b.BridgeURL
local f=b.JobStatus
local g=64
local h=8388608
local i=0.5
local j=5
local k=8

local function IsScriptMappingTransportReady(l)
return(
c.bridge~=nil and
c.bridge.Connected==true and
c.bridge.ClientId~=nil and
c.bridge.ClientId==l
)
end

local function UploadScriptSourceBatch(l,m)
if not l then return false end
if not IsScriptMappingTransportReady(l)then return false end
local n=c.generation
local o=c.session
if not o then return false end

local p={}
local q={}
for r,s in m or{}do
if s.kind=="remove"then
table.insert(q,s.debugId)
else
table.insert(p,{
debugId=s.debugId,
path=s.path,
source=s.source,
scriptHash=s.scriptHash,
})
end
end

local r=#p
local s=math.min(c.total,c.processed+r)
local t=c:IsFinished(s)
local u=o:NextRevision()

local v,w=pcall(request,{
Url="http://"..e.."/script-sources",
Method="POST",
Headers={
["Content-Type"]="application/json"
},
Body=d:JSONEncode{
clientId=l,
scripts=p,
removedScriptIds=q,
hasFinishedMapping=t,
sourcesToMap=c.total,
processedSources=s,
skippedSources=c.skipped,
mappingSessionId=o.id,
mappingSessionStartedAt=o.startedAt,
mappingRevision=u,
beginMappingSession=not o.started,
}
})

if not v or not w or w.StatusCode~=200 then return false,u end

if(
not c:IsActiveSession(o,n,l)
)then
return false,u,"stale_session"
end

local x=u
if type(w.Body)=="string"and w.Body~=""then
local y,z=pcall(function()
return d:JSONDecode(w.Body)
end)
if y and type(z)=="table"and type(z.acceptedMappingRevision)=="number"then
x=z.acceptedMappingRevision
end
end
if x~=u then return false,u end

o:MarkStarted()
return true,u
end

local function EnqueueScriptSourceUpload(l)
l.queuedBytes=if type(l.source)=="string"then#l.source else 0
c.upload.tail+=1
c.upload.queue[c.upload.tail]=l
c.upload.bytes+=l.queuedBytes
end

local function DequeueScriptSourceUpload()
if c.upload.head>c.upload.tail then return nil end
local l=c.upload.queue[c.upload.head]
c.upload.queue[c.upload.head]=nil
c.upload.head+=1
if l then c.upload.bytes=math.max(0,c.upload.bytes-(l.queuedBytes or 0))end
return l
end

local function ResetScriptSourceUploadQueue()
c.upload.queue={}
c.upload.head=1
c.upload.tail=0
c.upload.bytes=0
end

local function StartUploadQueue()
if c.upload.thread then return end

c.upload.thread=task.spawn(function()
while true do
if not IsScriptMappingTransportReady(c.clientId)then
task.wait(i)
continue
end
if c.upload.head>c.upload.tail then
if c.statusDirty then
local l=c.stateVersion
local m=UploadScriptSourceBatch(
c.clientId,
{}
)
if m and c.stateVersion==l then
c.statusDirty=false
end
end
task.wait(i)
continue
end

local l={}
local m=0
while c.upload.head<=c.upload.tail and#l<g do
local n=c.upload.queue[c.upload.head]
local o=if n and type(n.source)=="string"then#n.source else 0
if#l>0 and m+o>h then break end

local p=DequeueScriptSourceUpload()
if not p then continue end
local q=c.jobs[p.debugId]
local r=p.generation==c.generation and q~=nil
local s=r and(
(p.kind=="source"and q.state=="awaiting_upload")or
(p.kind=="remove"and q.state=="removed")
)
if s then
table.insert(l,p)
m+=o
end
end
if#l==0 then continue end

local n=c.stateVersion
local o=UploadScriptSourceBatch(c.clientId,l)
if o then
local p=0
for q,r in l do
if r.kind=="source"and r.generation==c.generation then
if f:MarkMapped(r.debugId,false)then
p+=1
end
end
end
c.statusDirty=
c.stateVersion~=n+p
else
local p=false
for q=#l,1,-1 do
local r=l[q]
if r.generation~=c.generation then
continue
end

r.attempts=(r.attempts or 0)+1
if r.kind=="source"and r.attempts>=j then
p=f:MarkFailed(
r.debugId,
"Source upload failed after "..tostring(r.attempts).." attempts.",
false
)or p
else
EnqueueScriptSourceUpload(r)
end
end
if p then f:Publish()end
local q=l[1]and l[1].attempts or 1
task.wait(math.min(2^math.max(0,q-1),k))
end

task.wait()
end
end)
end

return{
EnqueueScriptSourceUpload=EnqueueScriptSourceUpload,
IsScriptMappingTransportReady=IsScriptMappingTransportReady,
ResetScriptSourceUploadQueue=ResetScriptSourceUploadQueue,
StartUploadQueue=StartUploadQueue,
UploadQueueMaxBytes=33554432,
}
end end function a.j():typeof(__modImpl())local b=a.cache.j if not b then b={c=__modImpl()}a.cache.j=b end return b.c end end do local function __modImpl()

return function(b)
local c=b.ScriptMappingPipeline
local d=b.HttpService
local e=b.BridgeURL
local f=b.StripDecompilerBanner
local g=b.base64_encode
local h=b.BuiltInDecompile
local i=b.GetScriptHash
local j=b.DecompilerAttemptState
local k=b.PreparedScript
local l=b.Concurrency
local m=256
local n=2
local o=3
local p=8
local q=65
local r={
providerId=nil,
expiresAt=0,
refreshToken=nil,
blockedBuiltinUntil=0,
}
local s={
startedAt=nil,
lastAt=nil,
samples=0,
lastReportAt=0,
revision=0,
}

local function RunWithTimeout(t,u)
local v=false
local w=false
local x

local y=task.spawn(function()
w,x=pcall(u)
v=true
end)

local z=os.clock()+t
while not v and os.clock()<z do
task.wait(0.05)
end

if not v then
pcall(task.cancel,y)
return false,"Timed out after "..tostring(t).."s."
end

if not w then
return false,x
end

return true,x
end

local function RememberScriptSourceForHash(t,u)
if type(t)~="string"or t==""then return false end
if type(u)~="string"or u==""then return false end

c.sourceCacheByHash[t]=u
c.sourceCacheCheckedByHash[t]=true
return true
end

local function ReadScriptHash(t)
if type(i)~="function"then return nil end

local u,v=RunWithTimeout(n,function()
return i(t)
end)

if not u or type(v)~="string"or v==""then
return nil
end

return v
end

local function GetScriptHashForInstance(t)
local u=t:GetDebugId()
if c.scriptHashByDebugId[u]~=nil then
return c.scriptHashByDebugId[u]or nil
end

local v=ReadScriptHash(t)
c.scriptHashByDebugId[u]=v or false
return v
end

local function FetchCachedScriptSourceBatch(t,u)
if#u==0 then return true end

local v,w=pcall(request,{
Url="http://"..e.."/script-source-cache",
Method="POST",
Headers={
["Content-Type"]="application/json",Accept=
"application/json",
},
Body=d:JSONEncode{
clientId=t,
hashes=u,
},
})

if not v or type(w)~="table"or w.StatusCode~=200 or type(w.Body)~="string"then
return false
end

local x,y=pcall(function()
return d:JSONDecode(w.Body)
end)
if not x or type(y)~="table"or type(y.sources)~="table"then
return false
end

for z,A in ipairs(y.sources)do
if type(A)=="table"then
RememberScriptSourceForHash(A.scriptHash,A.source)
end
end

return true
end

local function FetchCachedScriptSources(t,u)
if type(request)~="function"then return end
if type(t)~="string"or t==""then return end
if type(u)~="table"then return end

local v={}
local w={}
local function flush()
local x=FetchCachedScriptSourceBatch(t,v)
if x then
for y,z in v do
c.sourceCacheCheckedByHash[z]=true
end
end
table.clear(v)
end

for x,y in ipairs(u)do
if(
type(y)=="string"and
y~=""and
not c.sourceCacheByHash[y]and
not c.sourceCacheCheckedByHash[y]and
not w[y]
)then
w[y]=true
table.insert(v,y)
if#v>=m then
flush()
end
end
end

flush()
end

local function ReadScriptBytecode(t)
local u,v=RunWithTimeout(o,function()
return getscriptbytecode(t)
end)
if not u or v==nil then
return false,v or"Failed to read script bytecode."
end
return true,v
end

local function TryBuiltInDecompile(t)
if type(h)~="function"then
return nil,0,"Executor built-in decompile is unavailable.",false
end

local u=os.clock()
local v,w=RunWithTimeout(p,function()
return h(t)
end)
local x=math.floor((os.clock()-u)*1000)
if not v then
local y=tostring(w or"Built-in decompile failed.")
return nil,x,y,string.find(y,"Timed out",1,true)~=nil
end
if type(w)~="string"or w==""then
return nil,x,"Built-in decompile returned no source.",false
end

return f(w),x
end

local function IsActiveMappingContext(t,u)
return(
t==c.generation and
u~=nil and
u==c.clientId
)
end

local function RefreshDecompilerPlan(t,u,v)
u=u or c.generation
v=v or c.clientId
if not IsActiveMappingContext(u,v)then return nil end
local w=os.clock()
if not t and r.expiresAt>w then
return r.providerId
end
if r.refreshToken then
local x=w+2
repeat task.wait()until not r.refreshToken or os.clock()>=x
return r.providerId
end
if type(request)~="function"then return nil end

local x={}
r.refreshToken=x

local y,z=RunWithTimeout(5,function()
return request{
Url="http://"..e.."/decompile-plan?clientId="..d:UrlEncode(v),
Method="GET",
Headers={Accept=
"application/json",
},
}
end)
if r.refreshToken~=x then return nil end
r.refreshToken=nil
if not IsActiveMappingContext(u,v)then return nil end
if not y or type(z)~="table"or z.StatusCode~=200 or type(z.Body)~="string"then
r.providerId=nil
r.expiresAt=w+0.25
return nil
end

local A,B=pcall(function()
return d:JSONDecode(z.Body)
end)
if not A or type(B)~="table"then
r.providerId=nil
r.expiresAt=w+0.25
return nil
end

r.providerId=if type(B.providerId)=="string"then B.providerId else nil
local C=math.max(0.25,math.min((tonumber(B.ttlMs)or 1000)/1000,5))
r.expiresAt=os.clock()+C
return r.providerId
end

local function ShouldUseDirectBuiltIn(t,u,v)
if t~="builtin"then return false end
if r.blockedBuiltinUntil>os.clock()then return false end
return type(h)=="function"and RefreshDecompilerPlan(false,u,v)=="builtin"
end

local function PostBuiltInObservation(t,u,v)
if not IsActiveMappingContext(u,v)then return end
local w=c.session
if not w then return end
s.revision+=1
t.clientId=v
t.providerId="builtin"
t.observationSessionId=w.id
t.observationSessionStartedAt=w.startedAt
t.observationRevision=s.revision
t.beginObservationSession=true
task.defer(function()
if not IsActiveMappingContext(u,v)then return end
pcall(request,{
Url="http://"..e.."/decompiler-observations",
Method="POST",
Headers={
["Content-Type"]="application/json",Accept=
"application/json",
},
Body=d:JSONEncode(t),
})
end)
end

local function ReportBuiltInDecompileSuccess(t,u,v)
if not IsActiveMappingContext(u,v)then return end
local w=os.clock()
if s.lastAt==nil or w-s.lastAt>2 then
s.startedAt=w
s.samples=0
end

s.lastAt=w
s.startedAt=s.startedAt or w
s.samples+=1
if w-s.startedAt<0.25 then return end
if w-s.lastReportAt<0.5 then return end
s.lastReportAt=w

local x=math.max(0.001,w-s.startedAt)
PostBuiltInObservation({
latencyMs=t,
successCount=s.samples,
throughputPerSecond=s.samples/x,
throughputWindowMs=x*1000,
throughputSamples=s.samples,
},u,v)
end

local function ReportBuiltInDecompileFailure(t,u,v,w,x)
if not IsActiveMappingContext(w,x)then return end
r.providerId=nil
r.expiresAt=0
r.blockedBuiltinUntil=os.clock()+5
if v==true then l:Reduce()end
PostBuiltInObservation({
latencyMs=u,
errorMessage=tostring(t or"Built-in decompile failed."),
timedOut=v==true,
},w,x)
end

local function RequestServerDecompile(t,u,v,w)
if type(request)~="function"then
return nil,"request function is unavailable"
end

u=if type(u)=="table"then u else{}
local x={
clientId=w,
bytecode=g(t),
builtinAvailable=type(h)=="function",
}
if type(u.builtinSource)=="string"then
x.builtinSource=u.builtinSource
end
if type(u.builtinLatencyMs)=="number"then
x.builtinLatencyMs=u.builtinLatencyMs
end
if type(u.requestedProvider)=="string"then
x.requestedProvider=u.requestedProvider
end
if type(u.disabledProviders)=="table"then
x.disabledProviders=u.disabledProviders
end

local y,z=RunWithTimeout(q,function()
return request{
Url="http://"..e.."/decompile",
Method="POST",
Headers={
["Content-Type"]="application/json",Accept=
"application/json",
},
Body=d:JSONEncode(x),
}
end)
if not y then
return nil,tostring(z)
end

if type(z)~="table"or type(z.Body)~="string"then
return nil,"Decompile server returned no response body."
end

local A,B=pcall(function()
return d:JSONDecode(z.Body)
end)
if not A or type(B)~="table"then
return nil,"Decompile server returned invalid JSON."
end

local C
if type(B.attemptedProviders)=="table"and type(B.attemptedProviders[1])=="string"then
C=B.attemptedProviders[1]
end

if B.ok==true and type(B.source)=="string"and B.source~=""then
return f(B.source),nil,false,C
end
if B.needsBuiltin==true and B.providerId=="builtin"then
return nil,nil,true,C
end

if type(B.error)=="string"and B.error~=""then
return nil,B.error,false,C
end
if type(B.attempts)=="table"then
return nil,table.concat(B.attempts,"\n\n"),false,C
end

return nil,"Decompile server failed without a detailed error.",false,C
end

local function PrepareScriptForMapping(t,u,v,w,x)
v=v or c.generation
w=w or c.clientId
local y=t:GetDebugId()
local z=GetScriptHashForInstance(t)
if u and z then
FetchCachedScriptSources(w,{z})
end

local A=z and c.sourceCacheByHash[z]or nil
if A then
return{
debugId=y,
scriptHash=z,
source=A,
}
end

local B=RefreshDecompilerPlan(false,v,w)
local C=x or B
local D=x=="builtin"
if D or ShouldUseDirectBuiltIn(C,v,w)then
return{
debugId=y,
scriptHash=z,
retryProviderId=x,
useDirectBuiltin=true,
forceDirectBuiltinRetry=D,
}
end

local E,F=ReadScriptBytecode(t)
if not E then
return nil,F
end

return{
debugId=y,
scriptHash=z,
bytecode=F,
retryProviderId=x,
}
end

local function BuildServerOptions(t,u)
local v={}
if type(t.retryProviderId)=="string"then
v.requestedProvider=t.retryProviderId
end
if type(u)=="table"then
for w,x in u do
v[w]=x
end
end
return if next(v)==nil then nil else v
end

local function TakeRetryServerOptions(t,u)
local v=BuildServerOptions(t,u)
t.retryProviderId=nil
return v
end

local function DecompileScriptSource(t,u,v,w)
v=v or c.generation
w=w or c.clientId
local x
if not u then
u,x=PrepareScriptForMapping(t,true,v,w)
end
if not u then
return nil,x or"Failed to prepare script for decompile.",nil,nil
end

if type(u.source)=="string"and u.source~=""then
return u.source,nil,u.scriptHash,u
end
if u.useDirectBuiltin==true then
local y=u.forceDirectBuiltinRetry==true or
j.CanAttemptBuiltIn(
u,
r.blockedBuiltinUntil,
os.clock()
)
if y then
u.retryProviderId=nil
u.forceDirectBuiltinRetry=nil
u.initialProviderId=u.initialProviderId or"builtin"
j.MarkBuiltInAttempted(u)
local z,A,B,C=TryBuiltInDecompile(t)
if z then
ReportBuiltInDecompileSuccess(A,v,w)
if u.scriptHash then
RememberScriptSourceForHash(u.scriptHash,z)
end
return z,nil,u.scriptHash,u
end

j.DisableBuiltIn(u)
ReportBuiltInDecompileFailure(B,A,C,v,w)
end
local z,A=k.MaterializeServerFallback(u,function()
return ReadScriptBytecode(t)
end)
if not z then
return nil,A,u.scriptHash,u
end
end

if type(u.bytecode)~="string"then
return nil,"Prepared script is missing bytecode.",u.scriptHash,u
end

local y=TakeRetryServerOptions(
u,
if u.builtinDisabled==true then{disabledProviders={"builtin"}}else nil
)
local z,A,B,C=RequestServerDecompile(
u.bytecode,
y,
v,
w
)
if not u.initialProviderId and type(C)=="string"then
u.initialProviderId=C
end
if B then
local D=j.CanAttemptBuiltIn(
u,
r.blockedBuiltinUntil,
os.clock()
)
if D then
j.MarkBuiltInAttempted(u)
local E,F,G,H=TryBuiltInDecompile(t)
if E then
ReportBuiltInDecompileSuccess(F,v,w)
z,A=RequestServerDecompile(u.bytecode,BuildServerOptions(u,{
requestedProvider="builtin",
builtinSource=E,
builtinLatencyMs=F,
}),v,w)
else
j.DisableBuiltIn(u)
ReportBuiltInDecompileFailure(G,F,H,v,w)
z,A=RequestServerDecompile(u.bytecode,BuildServerOptions(u,{
disabledProviders={"builtin"},
}),v,w)
end
else
j.DisableBuiltIn(u)
z,A=RequestServerDecompile(u.bytecode,BuildServerOptions(u,{
disabledProviders={"builtin"},
}),v,w)
end
end
if not z then
return nil,A,u.scriptHash,u
end

if u.scriptHash then
RememberScriptSourceForHash(u.scriptHash,z)
end
return z,nil,u.scriptHash,u
end

local function ResetDecompilerClient()
r.providerId=nil
r.expiresAt=0
r.refreshToken=nil
r.blockedBuiltinUntil=0
s.startedAt=nil
s.lastAt=nil
s.samples=0
s.lastReportAt=0
s.revision=0
end

return{
DecompileScriptSource=DecompileScriptSource,
FetchCachedScriptSources=FetchCachedScriptSources,
GetScriptHashForInstance=GetScriptHashForInstance,
PrepareScriptForMapping=PrepareScriptForMapping,
RefreshDecompilerPlan=RefreshDecompilerPlan,
ResetDecompilerClient=ResetDecompilerClient,
TakeRetryServerOptions=TakeRetryServerOptions,
}
end end function a.k():typeof(__modImpl())local b=a.cache.k if not b then b={c=__modImpl()}a.cache.k=b end return b.c end end do local function __modImpl()

return function(b)
local c=b.ScriptMappingPipeline
local d=b.WorkerPool
local e=b.UploadSession
local f=b.GenerateSessionGuid
local g=b.CoreGui
local h=b.CorePackages
local i=b.ScriptContext
local j=b.getnilinstances
local k=b.WorkerCount
local l=b.Concurrency
local m=b.JobStatus
local n=b.FailedResync
local o=b.UploadClient
local p=b.DecompilerClient
local q=o.EnqueueScriptSourceUpload
local r=o.IsScriptMappingTransportReady
local s=o.ResetScriptSourceUploadQueue
local t=p.DecompileScriptSource
local u=p.FetchCachedScriptSources
local v=p.GetScriptHashForInstance
local w=p.PrepareScriptForMapping
local x=p.RefreshDecompilerPlan
local y=p.ResetDecompilerClient
local z=4
local A=8
local B=256
local C

local function PublishCurrentMappingStatus()
m:Publish()
end

local function RemoveScriptFromMapping(D,E)
local F=c.jobs[D]
if E~=c.generation or not F or F.state=="removed"then return end

c.instances[D]=nil
c:SetJobState(F,"removed")
F.script=nil
F.prepared=nil
q{
kind="remove",
debugId=D,
generation=E,
attempts=0,
}
end

local function AttachScriptToMappingJob(D,E)
D.script=E
c.instances[D.debugId]=E
if D.destroyingConnection then return end
local F=D.generation
D.destroyingConnection=E.Destroying:Once(function()
RemoveScriptFromMapping(D.debugId,F)
end)
end

local function TrackScriptForMapping(D)
return c:TrackJob(D)~=nil
end

local function DeferScriptMappingUntilTransport(D,E,F,G)
local H=G or D:GetDebugId()
local I=c.jobs[H]
if F~=c.generation or not I then return end
if I.state=="mapped"or I.state=="failed"or I.state=="removed"then return end

c:SetJobState(I,"deferred")
AttachScriptToMappingJob(I,D)
I.prepared=E
end

local function RetryScriptMapping(D,E,F,G,H)
local I=H or D:GetDebugId()
local J=c.jobs[I]
if F~=c.generation or not J then return end
if J.state=="mapped"or J.state=="failed"or J.state=="removed"then return end
if string.find(tostring(G),"Timed out",1,true)then
l:Reduce()
end

J.mappingAttempts=(J.mappingAttempts or 0)+1
if J.mappingAttempts>=z then
m:MarkFailed(I,G or"Failed to prepare or decompile script source.")
return
end

c:SetJobState(J,"queued")
AttachScriptToMappingJob(J,D)
J.prepared=E
local K=math.min(2^math.max(0,J.mappingAttempts-1),A)
task.delay(K,function()
if F~=c.generation or J.generation~=F then return end
if J.state~="queued"then return end
if not r(c.clientId)then
DeferScriptMappingUntilTransport(D,E,F,I)
return
end

c.workers:QueueOperation(D,E,F,I)
end)
end

local function QueueMappedScriptSource(D,E,F,G,H)
local I=H or D:GetDebugId()
local J=c.jobs[I]
if not J then
TrackScriptForMapping(I)
J=c.jobs[I]
elseif J.state=="failed"then
TrackScriptForMapping(I)
elseif J.state=="mapped"or J.state=="awaiting_upload"or J.state=="removed"then
return false
end

local K=D:GetFullName()
AttachScriptToMappingJob(J,D)

c:SetJobState(J,"awaiting_upload")
q{
kind="source",
debugId=I,
path=K,
source=E,
scriptHash=F,
attempts=0,
generation=G,
}
return true
end

local function MapScriptSource(D,E,F,G)
if F~=c.generation then return end

local H=G or D:GetDebugId()
local I=c.jobs[H]
if not I or I.state~="queued"then return end
if not r(c.clientId)then
DeferScriptMappingUntilTransport(D,E,F,H)
return
end
if not c:TryStartMapping(I)then return end

while c.upload.bytes>=o.UploadQueueMaxBytes do
if F~=c.generation then return end
if not r(c.clientId)then
DeferScriptMappingUntilTransport(D,E,F,H)
return
end
task.wait(0.05)
end

AttachScriptToMappingJob(I,D)
local J=c.clientId
if not E then
local K
E,K=w(
D,
true,
F,
J,
I.initialProviderId
)
if not E then
RetryScriptMapping(D,nil,F,K,H)
return
end
end
I.prepared=E
local K,L,M,N=t(
D,
E,
F,
J
)
I.prepared=N
if not I.initialProviderId and N then
I.initialProviderId=N.initialProviderId
end
if not K then
RetryScriptMapping(D,N,F,L,H)
return
end
if F~=c.generation then return end
if c.jobs[H]~=I then return end
if I.state=="mapped"or I.state=="failed"or I.state=="removed"then return end
I.mappingAttempts=0
l:RecordSuccess()

QueueMappedScriptSource(D,K,M,F,H)
end

C=function(D,E,F,G,H)
if G~=c.generation or type(H)~="string"then return end
RetryScriptMapping(E,F,G,tostring(D),H)
end

c.workers=d.new{
MaxConcurrent=k,
MainCallback=MapScriptSource,
OnError=C,
}

local function GetScriptByDebugId(D)
local E=c.instances[D]
if E then
return E
end

for F,G in game:QueryDescendants"LuaSourceContainer"do
if G:IsA"Script"and G.RunContext==Enum.RunContext.Server then continue end
if G:GetDebugId()~=D then continue end

c.instances[D]=G
return G
end

for F,G in j()do
if not G:IsA"LuaSourceContainer"then continue end

if G:IsA"Script"and G.RunContext~=Enum.RunContext.Client then continue end
if G:GetDebugId()~=D then continue end

c.instances[D]=G
return G
end

return nil
end

local function RetryFailedScripts()
if not r(c.clientId)then return end

n:ProcessDue(function(D)
local E=GetScriptByDebugId(D.debugId)
if not E then
n:Defer(D)
return
end
if not n:Claim(D)then return end

AttachScriptToMappingJob(D,E)
c.workers:QueueOperation(
E,
nil,
D.generation,
D.debugId
)
end,function(D,E)
if D.state=="failed"then
n:Defer(D)
else
m:MarkFailed(
D.debugId,
"Failed to run periodic resync: "..tostring(E)
)
end
end)
end

local function StartFailedScriptResync()
n:Start(RetryFailedScripts)
end

local function IsCandidateScriptForMapping(D)
local E=(
D:IsA"Script"and(
D.RunContext==Enum.RunContext.Server or
D.RunContext==Enum.RunContext.Legacy
)
)
if E then return false end

local F=(
D.RobloxLocked or
D:IsDescendantOf(g)or
D:IsDescendantOf(h)or
D:IsDescendantOf(i)
)
if F then return false end

local G=D:GetDebugId()
if c.jobs[G]then return false end

return true
end

local function QueueScriptForMapping(D,E)
local F=D:GetDebugId()
if not TrackScriptForMapping(F)then return end
AttachScriptToMappingJob(c.jobs[F],D)

m:Publish()
local G=c.generation
if r(c.clientId)then
c.workers:QueueOperation(D,E,G,F)
else
DeferScriptMappingUntilTransport(D,E,G,F)
end
end

local function ResumeDeferredScriptMappings()
if not r(c.clientId)then return end

for D,E in c.jobs do
if E.generation==c.generation and E.state=="deferred"then
c:SetJobState(E,"queued")
c.workers:QueueOperation(E.script,E.prepared,E.generation,D)
end
end
end

local function StartScriptMapping(D)
if not r(D)then return end

c.clientId=D
x(true,c.generation,D)

if not c.descendantConnection then
c.descendantConnection=game.DescendantAdded:Connect(function(E)
if not E:IsA"LuaSourceContainer"then
return
end

if not IsCandidateScriptForMapping(E)then return end
QueueScriptForMapping(E)
end)
end

if c.initialScanRunning or c.initialScanFinished then return end
c.initialScanRunning=true
local E=c.generation


task.spawn(function()
local F={}
local G=false local
H=pcall(function()
local H={
game:QueryDescendants"LuaSourceContainer",
j()
}
local I={}

for J,K in H do
for L,M in K do
if E~=c.generation then return end
local N,O=pcall(function()
if not M:IsA"LuaSourceContainer"then return nil end
if not IsCandidateScriptForMapping(M)then return nil end
return M:GetDebugId()
end)
if not N then
continue
end
if not O then continue end
if I[O]then continue end
I[O]=true
if not TrackScriptForMapping(O)then continue end
AttachScriptToMappingJob(c.jobs[O],M)
table.insert(F,{script=M,debugId=O})
end
end

m:Publish()

local J={}
local K={}
local function flushPreparedScripts()
u(D,J)
for L,M in K do
if E~=c.generation then return end
if r(D)then
c.workers:QueueOperation(M.script,nil,E,M.debugId)
else
DeferScriptMappingUntilTransport(M.script,nil,E,M.debugId)
end
end
table.clear(J)
table.clear(K)
end

for L,M in F do
if E~=c.generation then return end
local N=v(M.script)
if N then table.insert(J,N)end
table.insert(K,M)

if#K>=B then
flushPreparedScripts()
end
if L%250==0 then task.wait()end
end
flushPreparedScripts()

G=true
end)

if E~=c.generation then return end
c.initialScanRunning=false
if H and G then
c.initialScanFinished=true
c.stateVersion+=1
PublishCurrentMappingStatus()
return
end

for I,J in F do
local K=c.jobs[J.debugId]
if c:CanDeferScanJob(K,E)then
local L,M=pcall(
DeferScriptMappingUntilTransport,
J.script,
K.prepared,
E,
J.debugId
)
if not L then
local N,O=pcall(
RetryScriptMapping,
J.script,
K.prepared,
E,
tostring(M),
J.debugId
)
if not N then
m:MarkFailed(
J.debugId,
"Scan recovery failed: "..tostring(O),
false
)
end
end
end
end
task.delay(1,function()
ResumeDeferredScriptMappings()
StartScriptMapping(D)
end)
end)
end

local function ResetScriptMappingState(D)
local E=c.descendantConnection
local F=c.generation+1
local G=e.new(
f(),
DateTime.now().UnixTimestampMillis,
F
)
c:Reset(D,G)
y()

if E then
E:Disconnect()
c.descendantConnection=nil
end

if c.workers then
c.workers:SetMaxConcurrent(c.currentWorkers)
c.workers:Reset()
end

s()
end

return{
DecompileScriptSource=t,
GetScriptByDebugId=GetScriptByDebugId,
QueueMappedScriptSource=QueueMappedScriptSource,
ResetScriptMappingState=ResetScriptMappingState,
ResumeDeferredScriptMappings=ResumeDeferredScriptMappings,
StartFailedScriptResync=StartFailedScriptResync,
StartScriptMapping=StartScriptMapping,
}
end end function a.l():typeof(__modImpl())local b=a.cache.l if not b then b={c=__modImpl()}a.cache.l=b end return b.c end end do local function __modImpl()

return function(b,c)
local d=b.LogService

c:BindToType("execute",function(e)
task.defer(function()
setthreadidentity(8)
loadstring(e.source)()
end)
end)

c:BindToTypeRaw("get-console-output",function(e)
local f=math.max(1,math.min(tonumber(e.limit)or 20,200))
local g=e.logsOrder or"NewestFirst"
local h=e.filter
local i=typeof(h)=="string"and h~=""
local j=e.summaryOnly==true

local k=d:GetLogHistory()
local l={}
local m=0
local n={}

local function matchesFilter(o)
if not i then return true end
return string.find(o.message,h,1,true)~=nil
end

local o=500
local function formatLogMessage(p)
local q=tostring(p or"")
if#q>o then
q=string.sub(q,1,o)
.."…(+"..(#q-o).." chars omitted)"
end
return q
end

if g=="NewestFirst"then
for p=#k,1,-1 do
local q=k[p]
if not matchesFilter(q)then continue end

m+=1
local r=q.messageType and q.messageType.Name or"Unknown"
n[r]=(n[r]or 0)+1
if#l<f then
table.insert(l,q)
end
end
else
for p,q in k do
if not matchesFilter(q)then continue end

m+=1
local r=q.messageType and q.messageType.Name or"Unknown"
n[r]=(n[r]or 0)+1
if#l<f then
table.insert(l,q)
end
end
end

local p={}
if j then
table.insert(p,string.format("Matched %d logs.",m))
for q,r in n do
table.insert(p,string.format("%s: %d",q,r))
end
return table.concat(p,"\n")
end

table.insert(p,string.format("Displaying %d/%d logs:",#l,m))

for q,r in l do
table.insert(p,string.format(
"[%s t=%s] %s",
r.messageType.Name,tostring(r.timestamp),
formatLogMessage(r.message)
))
end

return table.concat(p,"\n")
end)

c:BindToType("get-data-by-code",function(e)
setthreadidentity(8)
local f=table.pack(loadstring(e.source)())

return f
end)
end end function a.m():typeof(__modImpl())local b=a.cache.m if not b then b={c=__modImpl()}a.cache.m=b end return b.c end end do local function __modImpl()

return function(b,c)
local d=b.ScriptMappingPipeline
local e=b.GetScriptByDebugId
local f=b.DecompileScriptSource
local g=b.QueueMappedScriptSource

c:BindToTypeRaw("get-script-content",function(h)
local i
local j


if h.debugId then
j=e(h.debugId)
assert(j,"No live script instance found for ScriptProxy with DebugId: "..tostring(h.debugId))
else
setthreadidentity(8)
j=loadstring(h.source)()

assert(typeof(j)=="Instance","Script instance is not an instance.")
assert(j:IsA"LuaSourceContainer","Script instance is not a LuaSourceContainer (Script, LocalScript, or ModuleScript).")
assert(not(j:IsA"Script"and j.RunContext==Enum.RunContext.Server),"Script instance is a Server Script.")
end

local k
local l
i,l,k=f(
j,
nil,
d.generation,
d.clientId
)

if not i and j then
local m,n=pcall(function()return j.Source end)
if m and type(n)=="string"and n~=""then
i=n
l=nil
end
end

if not i and j and type(getscriptbytecode)=="function"then
local m,n=pcall(function()return getscriptbytecode(j)end)
if m and type(n)=="string"and#n>0 then
i="-- Bytecode (decompile unavailable). Length: "..#n.." bytes\n"..n
l=nil
end
end

assert(i,"Failed to decompile script. "..tostring(l or"No decompile function or script source available on this executor."))

local m=j:GetDebugId()
local n=d.jobs[m]
if d.clientId and(not n or n.state~="mapped")then
g(
j,
i,
k,
d.generation,
m
)
end


local o={}
local p=1
local q=#i
while p<=q do
local r=i:find("\n",p,true)
if r then
table.insert(o,i:sub(p,r-1))
p=r+1
else
table.insert(o,i:sub(p))
break
end
end

local r=#o
local s=math.max(1,math.min(tonumber(h.maxLines)or 200,2000))
local t=h.startLine and math.max(1,math.min(h.startLine,r))or 1
local u=h.endLine and math.max(t,math.min(h.endLine,r))or r
local v=math.min(u,t+s-1)

local w={}
for x=t,v do
table.insert(w,o[x])
end

local x=""
if v<u then
x="\n-- Output truncated to "..s.." lines. Rerun with startLine="..(v+1).." or a tighter range to continue."
end

return"-- Lines "..t.."-"..v.." of "..r.."\n"..table.concat(w,"\n")..x
end)
end end function a.n():typeof(__modImpl())local b=a.cache.n if not b then b={c=__modImpl()}a.cache.n=b end return b.c end end do local function __modImpl()

return function(b,c)
local d=b.MarketplaceService
local e=b.RobloxReplicatedStorage

c:BindToType("search-instances",function(f)
local g=loadstring("return "..f.root)()
local h=g:QueryDescendants(f.selector)

local i=math.max(1,math.min(tonumber(f.limit)or 20,100))
local j={}

for k,l in h do
if k>i then break end

local m=l.Name
pcall(function()m=l:GetFullName()end)

table.insert(j,{
Name=l.Name,
ClassName=l.ClassName,
Path=m,
DebugId=l:GetDebugId()
})
end

return{
count=#h,
limited=#h>i,
results=j
}
end)

c:BindToType("get-game-info",function(f)
local g=d:GetProductInfo(game.PlaceId)
local h=game.Players.LocalPlayer

local i
pcall(function()
i=e.GetServerType:InvokeServer()
end)

local j={
PlaceId=game.PlaceId,
GameId=game.GameId,
PlaceVersion=game.PlaceVersion,
PlaceName=g.Name,
Creator=g.Creator.Name,
CreatorType=tostring(g.Creator.CreatorType),
CreatorId=g.Creator.CreatorTargetId,
JobId=game.JobId,
ServerType=i,
LocalPlayer=h and{
Name=h.Name,
UserId=h.UserId,
DisplayName=h.DisplayName,
AccountAge=h.AccountAge,
Team=h.Team and h.Team.Name or nil,
}or nil,
Workspace={
ChildCount=#game.Workspace:GetChildren(),
CameraSubject=game.Workspace.CurrentCamera and tostring(game.Workspace.CurrentCamera.CameraSubject)or nil,
},
PlayerCount=#game.Players:GetPlayers(),
MaxPlayers=game.Players.MaxPlayers,
IsStudio=game:GetService"RunService":IsStudio(),
}

if f.includeDescription==true then
j.PlaceDescription=g.Description
end

return j
end)

c:BindToType("get-descendants-tree",function(f)
local g=loadstring("return "..f.root)()
assert(typeof(g)=="Instance","Root path did not resolve to a valid Instance.")

local h=math.max(0,math.min(tonumber(f.maxDepth)or 2,5))
local i=math.max(1,math.min(tonumber(f.maxChildren)or 20,30))
local j=f.classFilter or""
local k=j~=""
local l=f.summaryOnly==true
local m=300
local n=m
local o=false

if l then
local p={}
local q=0
local r=0

local function walk(s,t)
if t>h then
return
end

for u,v in s:GetChildren()do
q+=1
if not k or v:IsA(j)then
r+=1
p[v.ClassName]=(p[v.ClassName]or 0)+1
end
if t<h then
walk(v,t+1)
end
end
end

walk(g,1)

return{
Root={
Name=g.Name,
ClassName=g.ClassName,
ChildCount=#g:GetChildren(),
},
MaxDepth=h,
ClassFilter=if k then j else nil,
VisitedDescendants=q,
MatchedDescendants=r,
ClassCounts=p,
}
end

local function buildTree(p,q)
if q>h then
return nil
end

local r=p:GetChildren()
local s={}
local t=0
local u=#r

for v,w in r do
if t>=i then break end
if n<=0 then
o=true
break
end

if k and not w:IsA(j)then


if q<h then
local x=buildTree(w,q+1)
if x and x.Children and#x.Children>0 then
table.insert(s,x)
t+=1
end
end
continue
end

n-=1

local x={
Name=w.Name,
ClassName=w.ClassName,
ChildCount=#w:GetChildren()
}

if q<h and x.ChildCount>0 then
local y=buildTree(w,q+1)
if y then
x.Children=y.Children
end
end

table.insert(s,x)
t+=1
end

return{
Name=p.Name,
ClassName=p.ClassName,
ChildCount=u,
TruncatedAt=if t<u then t else nil,
Children=s
}
end

local p=buildTree(g,0)
if o and typeof(p)=="table"then
p.Note="Output capped at "..m.." nodes. Narrow with classFilter, lower maxDepth, or summaryOnly=true."
end
return p
end)
end end function a.o():typeof(__modImpl())local b=a.cache.o if not b then b={c=__modImpl()}a.cache.o=b end return b.c end end do local function __modImpl()

return function(b,c)
c:BindToType("ensure-remote-spy",function(d)
if getgenv().Cobalt then
return{
status="already_loaded",
message="Cobalt remote spy is already running."
}
end local

e=pcall(function()
loadstring(game:HttpGet"https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau")()
end)

if e then
local f=os.clock()
while not getgenv().Cobalt and os.clock()-f<10 do
task.wait(0.1)
end

if getgenv().Cobalt then
return{status="loaded",message="Cobalt remote spy loaded successfully."}
end
end

getgenv().MCP_BasicRemoteSpy=true
return{
status="basic_mode",
message="Cobalt not available. Using basic remote inventory mode."
}
end)

c:BindToType("get-remote-spy-logs",function(d)
local e=getgenv().Cobalt

if not e and getgenv().MCP_BasicRemoteSpy then
local f=d.remoteNameFilter or""
local g=math.max(1,math.min(tonumber(d.limit)or 10,100))
local h=f~=""

local i={}
local function scanRemotes(j,k)
if#i>=g*3 then return end
if k>5 then return end
for l,m in j:GetChildren()do
if#i>=g*3 then break end
if m:IsA"RemoteEvent"or m:IsA"RemoteFunction"or m:IsA"UnreliableRemoteEvent"then
local n=m.Name
if not h or string.find(string.lower(n),string.lower(f),1,true)then
local o=""
pcall(function()o=m:GetFullName()end)
table.insert(i,{
RemoteName=n,
RemoteClass=m.ClassName,
Direction="unknown",
Method="basic_mode",
TotalCalls=0,
Ignored=false,
Blocked=false,
RecentCalls=nil,
Path=o,
})
end
end
scanRemotes(m,k+1)
end
end


local j={"ReplicatedStorage","Workspace","Players"}
for k,l in j do
pcall(function()
local m=game:GetService(l)
scanRemotes(m,0)
end)
end


if#i>g then
local k={}
for l=1,g do
k[l]=i[l]
end
i=k
end

return{
count=#i,
results=i,
mode="basic",
message="Running in basic remote inventory mode."
}
end

assert(e and e.shared and e.shared.Logs,"Cobalt remote spy is not loaded. Call ensure-remote-spy first.")

local f=d.direction or"Both"
local g=d.remoteNameFilter or""
local h=math.max(1,math.min(tonumber(d.limit)or 10,100))
local i=math.max(0,math.min(tonumber(d.maxCallsPerRemote)or 2,20))
local j=d.summaryOnly==true
local k=g~=""

local function ProcessLogs(l,m)
local n={}

for o,p in l do
if typeof(o)~="Instance"then continue end
if#n>=h then break end

local q=""
local r=""
pcall(function()
q=o.Name
r=o.ClassName
end)


if k and not string.find(string.lower(q),string.lower(g),1,true)then
continue
end


local s={}
local t=#p.Calls
local u=math.max(1,t-i+1)

if not j then
for v=u,t do
local w=p.Calls[v]
if not w then continue end

table.insert(s,{
Index=v,
Arguments=w.Arguments,
Origin=w.Origin,
IsExecutor=w.IsExecutor or false,
IsActor=w.IsActor or false,
Line=w.Line,
})
end
end

table.insert(n,{
RemoteName=q,
RemoteClass=r,
Direction=m,
Method=p.Method,
TotalCalls=t,
Ignored=p.Ignored,
Blocked=p.Blocked,
RecentCalls=if j then nil else s,
})
end

return n
end

local l={}

if f=="Outgoing"or f=="Both"then
local m=ProcessLogs(e.shared.Logs.Outgoing,"Outgoing")
for n,o in m do
table.insert(l,o)
end
end

if f=="Incoming"or f=="Both"then
local m=ProcessLogs(e.shared.Logs.Incoming,"Incoming")
for n,o in m do
table.insert(l,o)
end
end


table.sort(l,function(m,n)
return m.TotalCalls>n.TotalCalls
end)


if#l>h then
local m={}
for n=1,h do
m[n]=l[n]
end
l=m
end

return{
count=#l,
results=l
}
end)
end end function a.p():typeof(__modImpl())local b=a.cache.p if not b then b={c=__modImpl()}a.cache.p=b end return b.c end end do local function __modImpl()

return function(b,c)
c:BindToType("clear-remote-spy-logs",function(d)
local e=getgenv().Cobalt
if not e and getgenv().MCP_BasicRemoteSpy then
return{
status="no_op",
message="Running in basic remote inventory mode. No call logs to clear."
}
end
assert(e and e.shared and e.shared.ClearLogs,"Cobalt remote spy is not loaded. Call ensure-remote-spy first.")

e.shared.ClearLogs()

return{
status="cleared",
message="All remote spy logs have been cleared."
}
end)

c:BindToType("block-remote",function(d)
local e=getgenv().Cobalt
if not e and getgenv().MCP_BasicRemoteSpy then
return{
status="unsupported",
message="Not available in basic mode."
}
end
assert(e and e.shared and e.shared.Logs,"Cobalt remote spy is not loaded. Call ensure-remote-spy first.")

local f=d.remoteName
local g=d.direction
local h=d.shouldBlock

local i=e.shared.Logs[g]
assert(i,"Invalid direction: "..tostring(g))

for j,k in i do
if typeof(j)~="Instance"then continue end

local l=""
pcall(function()l=j.Name end)

if l==f then
if h and not k.Blocked then
k:Block()
elseif not h and k.Blocked then
k:Block()
end

return{
status="success",
message=(h and"Blocked"or"Unblocked").." remote: "..f,
blocked=k.Blocked
}
end
end

error("Remote not found: "..f.." in "..g.." logs. Make sure the remote has been logged at least once.")
end)

c:BindToType("ignore-remote",function(d)
local e=getgenv().Cobalt
if not e and getgenv().MCP_BasicRemoteSpy then
return{
status="unsupported",
message="Not available in basic mode."
}
end
assert(e and e.shared and e.shared.Logs,"Cobalt remote spy is not loaded. Call ensure-remote-spy first.")

local f=d.remoteName
local g=d.direction
local h=d.shouldIgnore

local i=e.shared.Logs[g]
assert(i,"Invalid direction: "..tostring(g))

for j,k in i do
if typeof(j)~="Instance"then continue end

local l=""
pcall(function()l=j.Name end)

if l==f then
if h and not k.Ignored then
k:Ignore()
elseif not h and k.Ignored then
k:Ignore()
end

return{
status="success",
message=(h and"Ignoring"or"Unignored").." remote: "..f,
ignored=k.Ignored
}
end
end

error("Remote not found: "..f.." in "..g.." logs. Make sure the remote has been logged at least once.")
end)




c:BindToType("remote-spy",function(d)
c.Callbacks["ensure-remote-spy"]{}

local e=d.operation
if e=="status"then
local f=getgenv().Cobalt
local function CountLogs(g)
local h=0
if typeof(g)~="table"then return h end
for i in g do
h+=1
end
return h
end

return{
status="loaded",
outgoingRemotes=CountLogs(f.shared and f.shared.Logs and f.shared.Logs.Outgoing),
incomingRemotes=CountLogs(f.shared and f.shared.Logs and f.shared.Logs.Incoming),
}
elseif e=="list"then
return c.Callbacks["get-remote-spy-logs"]{
direction=d.direction,
remoteNameFilter=d.nameFilter,
limit=d.limit,
maxCallsPerRemote=d.maxCallsPerRemote,
summaryOnly=d.summaryOnly,
}
elseif e=="clear"then
return c.Callbacks["clear-remote-spy-logs"]{}
elseif e=="block"or e=="unblock"then
return c.Callbacks["block-remote"]{
remoteName=d.remoteName,
direction=d.direction,
shouldBlock=e=="block",
}
elseif e=="ignore"or e=="unignore"then
return c.Callbacks["ignore-remote"]{
remoteName=d.remoteName,
direction=d.direction,
shouldIgnore=e=="ignore",
}
end

error("Invalid remote-spy operation: "..tostring(e))
end)
end end function a.q():typeof(__modImpl())local b=a.cache.q if not b then b={c=__modImpl()}a.cache.q=b end return b.c end end do local function __modImpl()

return function(b,c)
local d=b.VirtualInputManager

c:BindToType("type-text-box",function(e)
local f=e.path
local g=e.string or e.text
local h=e.enter
local i=e.useKeyPress

local j
if typeof(f)=="string"then
j=loadstring("return "..f)()
else
j=f
end

assert(typeof(j)=="Instance","Path did not resolve to a valid Instance.")
assert(j:IsA"TextBox","Resolved Instance is not a TextBox.")

j:CaptureFocus()
task.wait(0.05)

if i then
local k=pcall(function()
for k=1,#g do
d:SendTextInput(g:sub(k,k),nil,game)
task.wait(0.01)
end
end)

if not k and type(keypress)=="function"then
for l=1,#g do
local m=g:sub(l,l):upper()
local n=m:byte()
if n then
keypress(n)
task.wait(0.01)
if type(keyrelease)=="function"then
keyrelease(n)
end
end
end
end
else
j.Text=g
end

if h then
if i then
if type(keypress)=="function"then
keypress(0x0D)
task.wait(0.01)
if type(keyrelease)=="function"then
keyrelease(0x0D)
end
else
pcall(function()
d:SendKeyEvent(true,Enum.KeyCode.Return,false,game)
task.wait(0.01)
d:SendKeyEvent(false,Enum.KeyCode.Return,false,game)
end)
end
end
j:ReleaseFocus(true)
else
j:ReleaseFocus(false)
end

return{
status="success",
message="Successfully typed into TextBox."
}
end)

c:BindToType("click-button",function(e)
local f=e.path
local g=e.Action or e.action

local h
if typeof(f)=="string"then
h=loadstring("return "..f)()
else
h=f
end

assert(typeof(h)=="Instance","Path did not resolve to a valid Instance.")
assert(h:IsA"GuiButton","Resolved Instance is not a GuiButton (e.g., TextButton or ImageButton).")

local i={"Activated","MouseButton1Down","MouseButton2Down","MouseButton1Click","MouseButton2Click"}
local j="unknown"

if g then
assert(table.find(i,g),"Invalid action provided. Valid actions are: "..table.concat(i,", "))
end

if type(firesignal)=="function"then
j="firesignal"
if g then
firesignal(h[g])
else
for k,l in pairs(i)do
pcall(function()firesignal(h[l])end)
end
end
elseif h.Activate and type(h.Activate)=="function"then
j="Activate"
pcall(function()h:Activate()end)
else
j="VirtualInputManager"
local k,l=pcall(function()
local k=h.AbsolutePosition
local l=h.AbsoluteSize
if k and l then
local m=k.X+l.X/2
local n=k.Y+l.Y/2
pcall(function()
d:SendMouseButton(true,Enum.UserInputType.MouseButton1,Vector2.new(m,n),0,game)
task.wait(0.05)
d:SendMouseButton(false,Enum.UserInputType.MouseButton1,Vector2.new(m,n),0,game)
end)
pcall(function()
d:SendTouchEvent(true,Vector2.new(m,n),0,game)
task.wait(0.05)
d:SendTouchEvent(false,Vector2.new(m,n),0,game)
end)
end
end)
if not k then
error("Failed to click button: "..tostring(l))
end
end

return{
status="success",
message="Successfully clicked Button using method: "..j,
method=j
}
end)
end end function a.r():typeof(__modImpl())local b=a.cache.r if not b then b={c=__modImpl()}a.cache.r=b end return b.c end end do local function __modImpl()

return function(b,c)local d=
b.HttpService
local e=b.base64_encode

c:BindToType("client-screenshot",function(f)
local g=tonumber(f.maxWidth)or 1280
g=math.max(256,math.min(g,2560))

local h=tonumber(f.quality)or 80
h=math.max(20,math.min(h,100))

local i
local j="png"

if type(screenshot)=="function"then
local k,l=pcall(screenshot)
if k and type(l)=="string"and#l>0 then
i=l
end
elseif type(takescreenshot)=="function"then
local k,l=pcall(takescreenshot)
if k and type(l)=="string"and#l>0 then
i=l
end
end

if not i and type(writefile)=="function"and type(readfile)=="function"then
local k="mcp_screenshot_temp.png"
pcall(function()
if type(screenshot)=="function"then
local l=screenshot()
if l then
writefile(k,l)
i=readfile(k)
end
end
end)
pcall(function()
if isfile and isfile(k)then
delfile(k)
end
end)
end

if not i then
local k,l=pcall(function()
if type(http_get)=="function"then
return http_get"screenshot://capture"
end
end)
if k and type(l)=="string"and#l>100 then
i=l
end
end

if not i then
return{
error="Client-side screenshot is not supported by this executor.",
success=false
}
end

local k
if i:match"^data:image/"then
k=i
elseif i:match"^[A-Za-z0-9+/=]+$"then
k="data:image/"..j..";base64,"..i
else
k="data:image/"..j..";base64,"..e(i)
end

return{
imageBase64=k,
mimeType="image/"..j,
success=true,
width=g,
source="client"
}
end)
end end function a.s():typeof(__modImpl())local b=a.cache.s if not b then b={c=__modImpl()}a.cache.s=b end return b.c end end do local function __modImpl()

local b=game:GetService"Players"
local c=game:GetService"Workspace"

local d={
quest={"quest","mission","objective","task","daily","challenge"},
shop={"shop","store","market","buy","purchase","merchant","vendor"},
collection={"collect","gather","harvest","mine","chop","farm","drop","loot","pickup"},
submit={"submit","turnin","turn_in","deliver","claim","reward","complete"},
teleport={"teleport","portal","warp","travel","fasttravel","fast_travel"},
npc={"npc","dialog","talk","conversation","speaker"},
zone={"zone","area","region","territory","spawn","safe"},
currency={"currency","coin","money","cash","gem","diamond","gold"},
inventory={"inventory","backpack","storage","item","tool","equip"},
upgrade={"upgrade","enhance","enchant","forge","craft","rebirth","prestige"},
pet={"pet","egg","hatch","companion","creature"},
trading={"trade","exchange","swap"},
leaderboard={"leaderboard","ranking","topplayer"},
}

local function safeGetFullName(e)
local f,g=pcall(function()return e:GetFullName()end)
return f and g or tostring(e)
end

return function(e,f)

f:BindToType("get-player-state",function(g)
local h=b.LocalPlayer
if not h then
return{error="No local player found."}
end

local i=h.Character
local j=i and i:FindFirstChildOfClass"Humanoid"
local k=i and i:FindFirstChild"HumanoidRootPart"

local l
local m=h:FindFirstChild"leaderstats"
if m then
l={}
for n,o in m:GetChildren()do
local p
pcall(function()p=o.Value end)
l[o.Name]={value=p,className=o.ClassName}
end
end

local n
pcall(function()
local o=h:GetAttributes()
if next(o)then
n={}
for p,q in o do
n[p]=q
end
end
end)

local o
if h.Backpack then
o={}
for p,q in h.Backpack:GetChildren()do
table.insert(o,{name=q.Name,className=q.ClassName})
end
end

local p
if i then
local q=i:FindFirstChildOfClass"Tool"
if q then p=q.Name end
end

local q={}
for r,s in h:GetChildren()do
if s:IsA"Folder"or s:IsA"Configuration"then
local t={name=s.Name,className=s.ClassName,children={}}
for u,v in s:GetChildren()do
local w
pcall(function()w=v.Value end)
table.insert(t.children,{name=v.Name,className=v.ClassName,value=w})
end
if#t.children>0 then
table.insert(q,t)
end
end
end

local r={}
local s=h:FindFirstChildOfClass"PlayerGui"
if s then
for t,u in s:GetChildren()do
if u:IsA"ScreenGui"then
local v=false
pcall(function()v=u.Enabled end)
if v then
table.insert(r,{name=u.Name,path=safeGetFullName(u),childCount=#u:GetChildren()})
end
end
end
end

local t={}
if k then
local u=k.Position
for v,w in c:GetDescendants()do
if#t>=15 then break end
if w:IsA"BasePart"or w:IsA"Model"then
local x
pcall(function()
if w:IsA"BasePart"then
x=w.Position
elseif w:IsA"Model"and w.PrimaryPart then
x=w.PrimaryPart.Position
end
end)
if x then
local y=(u-x).Magnitude
if y<=50 then
local z=w.Name:lower()
local A=false
for B,C in pairs(d)do
for D,E in ipairs(C)do
if string.find(z,E,1,true)then A=true break end
end
if A then break end
end
local B=false
if w:IsA"Model"then
pcall(function()B=w:FindFirstChildOfClass"Humanoid"~=nil end)
end
if A or B then
table.insert(t,{
name=w.Name,className=w.ClassName,
path=safeGetFullName(w),distance=math.floor(y),
hasHumanoid=B,
})
end
end
end
end
end
end

local u=c.CurrentCamera
local v
if u then
v={subject=nil,cameraType=nil}
pcall(function()
if u.CameraSubject then v.subject=tostring(u.CameraSubject)end
v.cameraType=tostring(u.CameraType)
end)
end

return{
player={
name=h.Name,userId=h.UserId,
displayName=h.DisplayName,accountAge=h.AccountAge,
team=h.Team and h.Team.Name or nil,
},
character=i and{
name=i.Name,
health=j and j.Health or nil,
maxHealth=j and j.MaxHealth or nil,
walkSpeed=j and j.WalkSpeed or nil,
jumpPower=j and j.JumpPower or nil,
state=j and tostring(j:GetState())or nil,
position=k and{
x=math.floor(k.Position.X*10)/10,
y=math.floor(k.Position.Y*10)/10,
z=math.floor(k.Position.Z*10)/10,
}or nil,
}or nil,
leaderstats=l,
attributes=n,
backpack=o,
equippedTool=p,
playerDataFolders=#q>0 and q or nil,
visibleGuis=#r>0 and r or nil,
nearby=#t>0 and t or nil,
camera=v,
}
end)

f:BindToType("get-game-guis",function(g)
local h=b.LocalPlayer
if not h then return{error="No local player found."}end

local i=g.includeHidden==true
local j=math.max(1,math.min(tonumber(g.maxDepth)or 3,6))
local k=math.max(1,math.min(tonumber(g.limit)or 10,30))
local l=g.guiFilter or""

local m=h:FindFirstChildOfClass"PlayerGui"
if not m then return{error="No PlayerGui found."}end

local n={}

for o,p in m:GetChildren()do
if#n>=k then break end
if p:IsA"ScreenGui"then
local q=false
pcall(function()q=p.Enabled end)
if q or i then
if l~=""and not string.find(string.lower(p.Name),string.lower(l),1,true)then
continue
end

local r,s,t,u={},{},{},{}

local function scanChildren(v,w)
if w>j then return end
for x,y in v:GetChildren()do
if#r>=20 and#s>=20 and#t>=10 then break end
if y:IsA"TextButton"or y:IsA"ImageButton"then
local z,A
pcall(function()z=y.AbsolutePosition;A=y.AbsoluteSize end)
table.insert(r,{
name=y.Name,
text=y:IsA"TextButton"and y.Text or nil,
path=safeGetFullName(y),visible=y.Visible,
position=z and{x=math.floor(z.X),y=math.floor(z.Y)}or nil,
size=A and{w=math.floor(A.X),h=math.floor(A.Y)}or nil,
})
elseif y:IsA"TextLabel"and#s<20 then
table.insert(s,{name=y.Name,text=y.Text,path=safeGetFullName(y),visible=y.Visible})
elseif y:IsA"TextBox"and#t<10 then
table.insert(t,{name=y.Name,text=y.Text,placeholderText=y.PlaceholderText,path=safeGetFullName(y),visible=y.Visible})
elseif y:IsA"ImageLabel"and#u<10 then
table.insert(u,{name=y.Name,path=safeGetFullName(y),visible=y.Visible})
end
scanChildren(y,w+1)
end
end
scanChildren(p,0)

table.insert(n,{
name=p.Name,path=safeGetFullName(p),enabled=q,childCount=#p:GetChildren(),
buttons=#r>0 and r or nil,
labels=#s>0 and s or nil,
textBoxes=#t>0 and t or nil,
images=#u>0 and u or nil,
})
end
end
end

return{count=#n,results=n}
end)

f:BindToType("trace-game-activity",function(g)
local h=math.max(1,math.min(tonumber(g.duration)or 5,30))
local i=b.LocalPlayer
if not i then return{error="No local player found."}end

local function snapshot()
local j=i.Character
local k=j and j:FindFirstChildOfClass"Humanoid"
local l=j and j:FindFirstChild"HumanoidRootPart"

local m,n,o={},{},{}
local p=i:FindFirstChild"leaderstats"
if p then
for q,r in p:GetChildren()do
local s
pcall(function()s=r.Value end)
m[r.Name]=s
end
end
pcall(function()
for q,r in i:GetAttributes()do n[q]=r end
end)
if i.Backpack then
for q,r in i.Backpack:GetChildren()do table.insert(o,r.Name)end
end

local q
if j then
local r=j:FindFirstChildOfClass"Tool"
if r then q=r.Name end
end

local r={}
local s=i:FindFirstChildOfClass"PlayerGui"
if s then
for t,u in s:GetChildren()do
if u:IsA"ScreenGui"then
local v=false
pcall(function()v=u.Enabled end)
if v then table.insert(r,u.Name)end
end
end
end

local t={}
for u,v in i:GetChildren()do
if v:IsA"Folder"then
for w,x in v:GetChildren()do
if x:IsA"ValueBase"then
local y
pcall(function()y=x.Value end)
t[x:GetFullName()]=y
end
end
end
end

local u
if l then
u={x=math.floor(l.Position.X*10)/10,y=math.floor(l.Position.Y*10)/10,z=math.floor(l.Position.Z*10)/10}
end

return{
stats=m,attributes=n,tools=o,equipped=q,
visibleGuis=r,folderValues=t,position=u,
health=k and k.Health or nil,
}
end

local j=snapshot()
task.wait(h)
local k=snapshot()
local l={}

for m,n in j.stats do
local o=k.stats[m]
if n~=o then
table.insert(l,{type="leaderstat",name=m,before=n,after=o})
end
end
for m,n in k.stats do
if j.stats[m]==nil then
table.insert(l,{type="leaderstat",name=m,before=nil,after=n})
end
end

for m,n in j.attributes do
if n~=k.attributes[m]then
table.insert(l,{type="attribute",name=m,before=n,after=k.attributes[m]})
end
end

local m,n={},{}
for o,p in j.tools do m[p]=true end
for o,p in k.tools do n[p]=true end
for o,p in j.tools do if not n[p]then table.insert(l,{type="tool_removed",name=p})end end
for o,p in k.tools do if not m[p]then table.insert(l,{type="tool_added",name=p})end end

if j.equipped~=k.equipped then
table.insert(l,{type="equipped",before=j.equipped,after=k.equipped})
end

local o,p={},{}
for q,r in j.visibleGuis do o[r]=true end
for q,r in k.visibleGuis do p[r]=true end
for q,r in j.visibleGuis do if not p[r]then table.insert(l,{type="gui_hidden",name=r})end end
for q,r in k.visibleGuis do if not o[r]then table.insert(l,{type="gui_shown",name=r})end end

for q,r in j.folderValues do
if r~=k.folderValues[q]then
table.insert(l,{type="data_changed",path=q,before=r,after=k.folderValues[q]})
end
end
for q,r in k.folderValues do
if j.folderValues[q]==nil then
table.insert(l,{type="data_added",path=q,after=r})
end
end

if j.position and k.position then
local q,r,s=k.position.x-j.position.x,k.position.y-j.position.y,k.position.z-j.position.z
local t=math.sqrt(q*q+r*r+s*s)
if t>1 then
table.insert(l,{type="position_change",distance=math.floor(t*10)/10,before=j.position,after=k.position})
end
end

if j.health~=k.health then
table.insert(l,{type="health",before=j.health,after=k.health})
end

local q
local r=getgenv().Cobalt
if r and r.shared and r.shared.Logs then
q={mode="cobalt",outgoing=0,incoming=0}
pcall(function()
for s,t in r.shared.Logs.Outgoing do
if typeof(s)=="Instance"then q.outgoing+=#t.Calls end
end
for s,t in r.shared.Logs.Incoming do
if typeof(s)=="Instance"then q.incoming+=#t.Calls end
end
end)
elseif getgenv().MCP_BasicRemoteSpy then
q={mode="basic",message="Basic remote inventory mode active."}
end

return{duration=h,changes=l,changeCount=#l,remoteActivity=q,before=j,after=k}
end)

f:BindToType("find-game-systems",function(g)
local h=g.keywords or{}
local i=math.max(1,math.min(tonumber(g.limit)or 20,100))
local j=math.max(1,math.min(tonumber(g.maxDepth)or 8,20))

local k={}
if#h==0 then
for l,m in pairs(d)do k[l]=d[l]end
else
for l,m in h do
local n=string.lower(m)
if d[n]then k[n]=d[n]end
end
if next(k)==nil then
for l,m in pairs(d)do k[l]=d[l]end
end
end

local l={}
local m={}

local function checkInstance(n,o)
if o>j then return end
if#l>=i*2 then return end

local p=string.lower(n.Name)
for q,r in k do
for s,t in r do
if string.find(p,t,1,true)then
local u=n:GetDebugId()
if not m[u]then
m[u]=true
local v={}
pcall(function()
if n:IsA"ValueBase"then v.value=n.Value
elseif n:IsA"RemoteEvent"or n:IsA"RemoteFunction"then v.remoteType=n.ClassName
elseif n:IsA"BasePart"or n:IsA"Model"then
local w
if n:IsA"BasePart"then w=n.Position
elseif n.PrimaryPart then w=n.PrimaryPart.Position end
if w then
v.position={x=math.floor(w.X*10)/10,y=math.floor(w.Y*10)/10,z=math.floor(w.Z*10)/10}
end
local x=n:FindFirstChildOfClass"Humanoid"
if x then v.isNPC=true;v.health=x.Health end
elseif n:IsA"ScreenGui"then
v.enabled=n.Enabled;v.childCount=#n:GetChildren()
end
end)
table.insert(l,{
name=n.Name,className=n.ClassName,path=safeGetFullName(n),
category=q,matchedKeyword=t,
extraInfo=next(v)~=nil and v or nil,
})
end
break
end
end
end

for q,r in n:GetChildren()do
if#l>=i*2 then break end
checkInstance(r,o+1)
end
end

local n={
game:GetService"ReplicatedStorage",c,
}
local o=b.LocalPlayer
if o then table.insert(n,o)end

for p,q in n do
pcall(function()checkInstance(q,0)end)
end

if#l>i then
local p={}
for q=1,i do p[q]=l[q]end
l=p
end

local p={}
for q,r in l do
if not p[r.category]then p[r.category]={}end
table.insert(p[r.category],r)
end

return{
count=#l,categories=p,results=l,
availableCategories=(function()
local q={}
for r,s in pairs(d)do table.insert(q,r)end
table.sort(q)
return q
end)(),
}
end)
end end function a.t():typeof(__modImpl())local b=a.cache.t if not b then b={c=__modImpl()}a.cache.t=b end return b.c end end do local function __modImpl()

local b=game:GetService"Players"
local c=game:GetService"Workspace"
game:GetService"RunService"

local d={
"anticheat","anti_cheat","anti-cheat","antihack","anti-hack",
"security","secure","protector","protect",
"detector","detect","validator","validate",
"sanity","flag","flagger","reporter",
"kick","ban","crash","shutdown",
"exploit","hack","cheat","suspect",
"byfron","hyperion","ac_module",
}

local e={
{pattern="Player:Kick",category="kick",severity="high"},
{pattern=":Kick(",category="kick",severity="high"},
{pattern="Ban",category="ban",severity="high"},
{pattern="FireServer",category="remote_report",severity="medium"},
{pattern="InvokeServer",category="remote_report",severity="medium"},
{pattern="WalkSpeed",category="speed_check",severity="medium"},
{pattern="JumpPower",category="jump_check",severity="medium"},
{pattern="HipHeight",category="movement_check",severity="medium"},
{pattern="CFrame",category="position_check",severity="medium"},
{pattern="Magnitude",category="distance_check",severity="medium"},
{pattern="HumanoidRootPart",category="position_check",severity="low"},
{pattern="teleport",category="teleport_check",severity="medium"},
{pattern="noclip",category="noclip_check",severity="medium"},
{pattern="fly",category="fly_check",severity="medium"},
{pattern="speed",category="speed_check",severity="medium"},
{pattern="getgenv",category="executor_detect",severity="high"},
{pattern="hookfunction",category="executor_detect",severity="high"},
{pattern="hookmetamethod",category="executor_detect",severity="high"},
{pattern="identifyexecutor",category="executor_detect",severity="high"},
{pattern="getrenv",category="executor_detect",severity="high"},
{pattern="getgc",category="executor_detect",severity="medium"},
{pattern="getconnections",category="executor_detect",severity="medium"},
{pattern="getloadedmodules",category="executor_detect",severity="medium"},
{pattern="getscripts",category="executor_detect",severity="medium"},
{pattern="debug.getupvalues",category="executor_detect",severity="medium"},
{pattern="getfenv",category="executor_detect",severity="low"},
{pattern="sethiddenproperty",category="executor_detect",severity="medium"},
{pattern="gethiddenproperty",category="executor_detect",severity="medium"},
{pattern="BasePart",category="physics_check",severity="low"},
{pattern="AssemblyLinearVelocity",category="velocity_check",severity="medium"},
{pattern="AssemblyAngularVelocity",category="velocity_check",severity="medium"},
{pattern="RaycastParams",category="raycast_check",severity="low"},
{pattern="GetPropertyChangedSignal",category="property_check",severity="medium"},
{pattern="CharacterAdded",category="character_check",severity="low"},
{pattern="Humanoid.StateChanged",category="state_check",severity="low"},
{pattern="request",category="http_check",severity="high"},
{pattern="HttpPost",category="http_check",severity="high"},
{pattern="HttpGet",category="http_check",severity="high"},
}

local function safeGetFullName(f)
local g,h=pcall(function()return f:GetFullName()end)
return g and h or tostring(f)
end

local function safeDecompile(f)
if type(decompile)=="function"then
local g,h=pcall(decompile,f)
if g and type(h)=="string"and#h>0 then
return h
end
end
local g,h=pcall(function()return f.Source end)
if g and type(h)=="string"and#h>0 then
return h
end
return nil
end

return function(f,g)

g:BindToType("scan-anticheat",function(h)
local i=math.max(5,math.min(tonumber(h.maxScripts)or 30,100))
local j=h.scanSource~=false
local k={
nameMatches={},
sourceMatches={},
remoteReports={},
summary={},
}

local l={}

local function checkName(m,n)
local o=string.lower(m)
for p,q in d do
if string.find(o,q,1,true)then
local r=n:GetDebugId()
if not l[r]then
l[r]=true
local s={}
pcall(function()
if n:IsA"ModuleScript"then
s.scriptType="ModuleScript"
elseif n:IsA"LocalScript"then
s.scriptType="LocalScript"
elseif n:IsA"Script"then
s.scriptType="Script"
elseif n:IsA"RemoteEvent"or n:IsA"RemoteFunction"then
s.remoteType=n.ClassName
elseif n:IsA"BasePart"or n:IsA"Model"then
local t
if n:IsA"BasePart"then
t=n.Position
elseif n.PrimaryPart then
t=n.PrimaryPart.Position
end
if t then
s.position={x=math.floor(t.X),y=math.floor(t.Y),z=math.floor(t.Z)}
end
end
end)
table.insert(k.nameMatches,{
name=m,
className=n.ClassName,
path=safeGetFullName(n),
matchedPattern=q,
extra=next(s)~=nil and s or nil,
})
end
break
end
end
end

local m={
game:GetService"ReplicatedStorage",
c,
game:GetService"StarterPlayer",
}
local n=b.LocalPlayer
if n then
table.insert(m,n)
local o=n:FindFirstChildOfClass"PlayerGui"
if o then table.insert(m,o)end
end

for o,p in m do
pcall(function()
for q,r in p:GetDescendants()do
checkName(r.Name,r)
end
end)
end

if j then
local o=0
local p={}

pcall(function()
if type(getscripts)=="function"then
for q,r in getscripts()do
if#p>=i*2 then break end
table.insert(p,r)
end
end
end)
pcall(function()
if type(getloadedmodules)=="function"then
for q,r in getloadedmodules()do
if#p>=i*2 then break end
table.insert(p,r)
end
end
end)

for q,r in p do
if o>=i then break end
local s=""
pcall(function()s=r.Name end)
local t=safeGetFullName(r)

local u=safeDecompile(r)
if u then
o+=1
local v={}
for w,x in e do
if string.find(u,x.pattern,1,true)then
if not v[x.category]then
v[x.category]={}
end
table.insert(v[x.category],{
pattern=x.pattern,
severity=x.severity,
})
end
end

if next(v)~=nil then
local w={}
local x="low"
for y,z in v do
table.insert(w,y)
for A,B in z do
if B.severity=="high"then x="high"
elseif B.severity=="medium"and x~="high"then x="medium"
end
end
end

local y
for z,A in e do local
B=string.find(u,A.pattern,1,true)
if B then
local C=B
while C>1 and string.sub(u,C-1,C-1)~="\n"do
C=C-1
end
local D=string.find(u,"\n",B,true)
if not D then D=math.min(B+200,#u)end
y=string.sub(u,C,math.min(D,C+200))
break
end
end

table.insert(k.sourceMatches,{
scriptName=s,
scriptPath=t,
categories=w,
maxSeverity=x,
matchedPatterns=v,
snippet=y,
})
end
end
end
k.summary.scriptsScanned=o
end

local function checkRemotesForReporting()
local o={}
pcall(function()
for p,q in m do
for r,s in q:GetDescendants()do
if s:IsA"RemoteEvent"or s:IsA"RemoteFunction"then
local t=string.lower(s.Name)
for u,v in ipairs{"report","flag","kick","ban","detect","exploit","cheat","log","alert","notify","webhook"}do
if string.find(t,v,1,true)then
table.insert(o,{
name=s.Name,
className=s.ClassName,
path=safeGetFullName(s),
matchedKeyword=v,
})
break
end
end
end
end
end
end)
return o
end
k.remoteReports=checkRemotesForReporting()

local o={high=0,medium=0,low=0}
for p,q in k.sourceMatches do
o[q.maxSeverity]=(o[q.maxSeverity]or 0)+1
end

k.summary.nameMatches=#k.nameMatches
k.summary.sourceMatches=#k.sourceMatches
k.summary.remoteReports=#k.remoteReports
k.summary.highSeverity=o.high
k.summary.mediumSeverity=o.medium
k.summary.lowSeverity=o.low
k.summary.likelyHasAntiCheat=#k.nameMatches>0 or#k.sourceMatches>0

return k
end)

g:BindToType("anticheat-bypass",function(h)
local i=h.target or"auto"
local j=h.mode or"safe"

local k

if i=="auto"then
local l=math.max(5,math.min(tonumber(h.maxScripts)or 20,50))
local m=0
local n={}

pcall(function()
if type(getscripts)=="function"then
for o,p in getscripts()do
if#n>=l*2 then break end
table.insert(n,p)
end
end
end)
pcall(function()
if type(getloadedmodules)=="function"then
for o,p in getloadedmodules()do
if#n>=l*2 then break end
table.insert(n,p)
end
end
end)

local o={}

for p,q in n do
if m>=l then break end
local r=""
local s=""
pcall(function()r=q.Name end)
s=safeGetFullName(q)

local t=string.lower(r)
local u=false
for v,w in d do
if string.find(t,w,1,true)then
u=true
break
end
end

local v=safeDecompile(q)
if v then
m+=1
if not u then
for w,x in e do
if x.severity=="high"and string.find(v,x.pattern,1,true)then
u=true
break
end
end
end

if u then
local w={}
for x,y in e do
if string.find(v,y.pattern,1,true)then
if not w[y.category]then
w[y.category]={}
end
table.insert(w[y.category],y.pattern)
end
end

table.insert(o,{
name=r,
path=s,
script=q,
checks=w,
})
end
end
end

k=o
end

local l={}
local m=type(hookmetamethod)=="function"
local n=type(newcclosure)=="function"
local o=type(hookfunction)=="function"
local p=type(setreadonly)=="function"or type(make_writeable)=="function"or type(set_readonly)=="function"

table.insert(l,"-- Anti-Cheat Bypass Script")
table.insert(l,"-- Detected anti-cheat components: "..tostring(#k))
table.insert(l,"-- Bypass mode: "..j)
table.insert(l,"-- Executor capabilities: hookmetamethod="..tostring(m)..", hookfunction="..tostring(o)..", newcclosure="..tostring(n))
table.insert(l,"")

if#k==0 then
table.insert(l,"-- No anti-cheat scripts detected by name or source scan.")
table.insert(l,"-- If you suspect there's an anti-cheat, try scanning with scan-anticheat tool first.")
table.insert(l,"-- Applying generic protections anyway:")
table.insert(l,"")

if m then
table.insert(l,"local mt = getrawmetatable(game)")
table.insert(l,"local oldNamecall = mt.__namecall")
table.insert(l,"setreadonly(mt, false)")
table.insert(l,"hookmetamethod(game, '__namecall', newcclosure(function(self, ...) ")
table.insert(l,"    local method = getnamecallmethod()")
table.insert(l,"    local args = {...}")
table.insert(l,"    if method == 'FireServer' or method == 'InvokeServer' then")
table.insert(l,"        local remoteName = ''")
table.insert(l,"        pcall(function() remoteName = self.Name end)")
table.insert(l,"        local nameLower = string.lower(remoteName)")
table.insert(l,"        for _, kw in ipairs({'report', 'flag', 'kick', 'ban', 'detect', 'exploit', 'cheat', 'alert', 'webhook'}) do")
table.insert(l,"            if string.find(nameLower, kw, 1, true) then")
table.insert(l,"                return -- Block the remote call")
table.insert(l,"            end")
table.insert(l,"        end")
table.insert(l,"    end")
table.insert(l,"    return oldNamecall(self, ...)")
table.insert(l,"end))")
table.insert(l,"setreadonly(mt, true)")
end
else
for q,r in k do
table.insert(l,"-- Bypassing: "..r.name.." ("..r.path..")")
local s=r.checks.kick~=nil
local t=r.checks.ban~=nil
local u=r.checks.speed_check~=nil
local v=r.checks.position_check~=nil
local w=r.checks.executor_detect~=nil
local x=r.checks.remote_report~=nil
local y=r.checks.velocity_check~=nil
local z=r.checks.property_check~=nil

if j=="safe"then
if o then
table.insert(l,"pcall(function()")
table.insert(l,"    local s = getscripts and getscripts() or {}")
table.insert(l,"    for _, script in ipairs(s) do")
table.insert(l,"        pcall(function()")
table.insert(l,"            local name = string.lower(script.Name)")
table.insert(l,"            if name:find('"..string.lower(r.name).."', 1, true) then")
table.insert(l,"                if script.Disabled ~= nil then script.Disabled = true end")
table.insert(l,"            end")
table.insert(l,"        end)")
table.insert(l,"    end")
table.insert(l,"end)")
end

if s or t then
table.insert(l,"pcall(function()")
table.insert(l,"    local player = game.Players.LocalPlayer")
table.insert(l,"    local mt = getrawmetatable(player)")
if p then table.insert(l,"    setreadonly(mt, false)")end
table.insert(l,"    local oldIndex = mt.__index")
if m and n then
table.insert(l,"    hookmetamethod(player, '__index', newcclosure(function(self, key)")
table.insert(l,"        return oldIndex(self, key)")
table.insert(l,"    end))")
table.insert(l,"    local oldNamecall = mt.__namecall")
table.insert(l,"    hookmetamethod(game, '__namecall', newcclosure(function(self, ...)")
table.insert(l,"        local method = getnamecallmethod()")
table.insert(l,"        if method == 'Kick' then return nil end")
table.insert(l,"        return oldNamecall(self, ...)")
table.insert(l,"    end))")
end
if p then table.insert(l,"    setreadonly(mt, true)")end
table.insert(l,"end)")
end

if u or v or y then
table.insert(l,"pcall(function()")
table.insert(l,"    local player = game.Players.LocalPlayer")
table.insert(l,"    local char = player.Character or player.CharacterAdded:Wait()")
table.insert(l,"    local humanoid = char:WaitForChild('Humanoid')")
if m and n then
table.insert(l,"    local mt = getrawmetatable(humanoid)")
if p then table.insert(l,"    setreadonly(mt, false)")end
table.insert(l,"    local oldIndex = mt.__index")
table.insert(l,"    hookmetamethod(humanoid, '__index', newcclosure(function(self, key)")
table.insert(l,"        if key == 'WalkSpeed' or key == 'JumpPower' or key == 'JumpHeight' then")
table.insert(l,"            return 16 -- Return default WalkSpeed")
table.insert(l,"        end")
table.insert(l,"        if key == 'HipHeight' then return 2 end")
table.insert(l,"        return oldIndex(self, key)")
table.insert(l,"    end))")
if p then table.insert(l,"    setreadonly(mt, true)")end
end
table.insert(l,"end)")
end

if w then
table.insert(l,"pcall(function()")
table.insert(l,"    getgenv().identifyexecutor = function() return 'Roblox' end")
table.insert(l,"    getgenv().getrenv = function() return {} end")
table.insert(l,"    getgenv().getgc = function() return {} end")
if o and n then
table.insert(l,"    hookfunction(getfenv, newcclosure(function() return setmetatable({}, {__index = function() return function() end end}) end))")
end
table.insert(l,"end)")
end

if x then
if m and n then
table.insert(l,"pcall(function()")
table.insert(l,"    local mt = getrawmetatable(game)")
if p then table.insert(l,"    setreadonly(mt, false)")end
table.insert(l,"    local oldNamecall = mt.__namecall")
table.insert(l,"    hookmetamethod(game, '__namecall', newcclosure(function(self, ...)")
table.insert(l,"        local method = getnamecallmethod()")
table.insert(l,"        if method == 'FireServer' or method == 'InvokeServer' then")
table.insert(l,"            local remoteName = ''")
table.insert(l,"            pcall(function() remoteName = self.Name end)")
table.insert(l,"            local nameLower = string.lower(remoteName)")
table.insert(l,"            for _, kw in ipairs({'report', 'flag', 'kick', 'ban', 'detect', 'exploit', 'cheat', 'alert', 'webhook', 'log'}) do")
table.insert(l,"                if string.find(nameLower, kw, 1, true) then")
table.insert(l,"                    return -- Block report")
table.insert(l,"                end")
table.insert(l,"            end")
table.insert(l,"        end")
table.insert(l,"        return oldNamecall(self, ...)")
table.insert(l,"    end))")
if p then table.insert(l,"    setreadonly(mt, true)")end
table.insert(l,"end)")
end
end

if z then
table.insert(l,"pcall(function()")
table.insert(l,"    local player = game.Players.LocalPlayer")
table.insert(l,"    local char = player.Character")
if m and n then
if char then
table.insert(l,"    local hrp = char:FindFirstChild('HumanoidRootPart')")
table.insert(l,"    if hrp then")
table.insert(l,"        local mt = getrawmetatable(hrp)")
if p then table.insert(l,"        setreadonly(mt, false)")end
table.insert(l,"        local oldIndex = mt.__index")
table.insert(l,"        hookmetamethod(hrp, '__index', newcclosure(function(self, key)")
table.insert(l,"            if key == 'CFrame' or key == 'Position' then")
table.insert(l,"                -- Return last known good position to fool checks")
table.insert(l,"                return oldIndex(self, key)")
table.insert(l,"            end")
table.insert(l,"            if key == 'AssemblyLinearVelocity' or key == 'AssemblyAngularVelocity' then")
table.insert(l,"                return Vector3.zero")
table.insert(l,"            end")
table.insert(l,"            return oldIndex(self, key)")
table.insert(l,"        end))")
if p then table.insert(l,"        setreadonly(mt, true)")end
table.insert(l,"    end")
end
end
table.insert(l,"end)")
end
elseif j=="aggressive"then
table.insert(l,"pcall(function()")
if o then
table.insert(l,"    local s = getscripts and getscripts() or {}")
table.insert(l,"    for _, script in ipairs(s) do")
table.insert(l,"        pcall(function()")
table.insert(l,"            local name = string.lower(script.Name)")
table.insert(l,"            if name:find('"..string.lower(r.name).."', 1, true) then")
table.insert(l,"                if script.Disabled ~= nil then script.Disabled = true end")
table.insert(l,"            end")
table.insert(l,"        end)")
table.insert(l,"    end")
end
table.insert(l,"end)")
end

table.insert(l,"")
end
end

table.insert(l,"")
table.insert(l,"-- Bypass applied. Monitor for kicks/bans and adjust if needed.")

local q=table.concat(l,"\n")

return{
bypassCode=q,
detectedCount=#k,
detectedComponents=(function()
local r={}
for s,t in k do
local u={}
for v,w in t.checks do
table.insert(u,v)
end
table.insert(r,{
name=t.name,
path=t.path,
checks=u,
})
end
return r
end)(),
executorCapabilities={
hookmetamethod=m,
hookfunction=o,
newcclosure=n,
setreadonly=p,
},
mode=j,
warning="Review the bypass code before executing. Some anti-cheat systems are server-side and cannot be bypassed from the client. If the anti-cheat uses server-side validation, client hooks may not be sufficient.",
}
end)

end end function a.u():typeof(__modImpl())local b=a.cache.u if not b then b={c=__modImpl()}a.cache.u=b end return b.c end end do local function __modImpl()

return function(b)
local c=b.CreateBridge
local d=b.WaitForBridgeClientId
local e=b.ScriptMappingPipeline
local f=b.StartUploadQueue
local g=b.PublishScriptMappingStatus
local h=b.ResetScriptMappingState
local i=b.StartScriptMapping
local j=b.StartFailedScriptResync
local k=b.ResumeDeferredScriptMappings

local l=1
local m=30
while true do
local n,o=pcall(c)

if not n then
task.wait(l)
l=math.min(l*1.5,m)
continue
end


l=1

local p=d(o)
if p then
e.bridge=o
f()

if e.clientId~=p then
h(p)
end

if not getgenv().DisableInitialScriptDecompMapping then
i(p)
j()
k()
g()
else
e.clientId=p
e.disabled=true
e.stateVersion+=1
g()
end
end

local q={a.m()
,a.n()
,a.o()
,a.p()
,a.q()
,a.r()
,a.s()
,a.t()
,a.u()
,
}
for r,s in q do
s(b,o)
end

o:WaitForDisconnect()

if e.bridge==o then
e.bridge=nil
end
task.wait(l)
l=math.min(l*1.5,m)
end
end end function a.v():typeof(__modImpl())local b=a.cache.v if not b then b={c=__modImpl()}a.cache.v=b end return b.c end end end




if getgenv().MCP_Loaded==true then
return
end

getgenv().MCP_Loaded=true

local b=getgenv().BridgeURL or getgenv().bridgeurl or...or"localhost:16384"
getgenv().BridgeURL=b
getgenv().bridgeurl=b


if not game:IsLoaded()then
game.Loaded:Wait()
end




if getgenv().MCP_DisableAntiAFK~=true then
local c=game:GetService"VirtualUser"
local d=game:GetService"Players"
local e=d.LocalPlayer
if e then
e.Idled:Connect(function()
pcall(function()
c:CaptureController()
c:ClickButton2(Vector2.new())
end)
end)
end
end


local c=cloneref or function(c)return c end

local d:RobloxReplicatedStorage=c(game:GetService"RobloxReplicatedStorage")
local e:VirtualInputManager=c(Instance.new"VirtualInputManager")
local f:MarketplaceService=c(game:GetService"MarketplaceService")
local g:CoreGui=c(game:GetService"CoreGui")
local h:CorePackages=c(game:GetService"CorePackages")
local i:ScriptContext=c(game:GetService"ScriptContext")
local j:HttpService=c(game:GetService"HttpService")
local k:LogService=c(game:GetService"LogService")
local l:Players=c(game:GetService"Players")



local m
do




local n='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'


m=base64encode or function(o)
return((o:gsub('.',function(p)
local q,r='',p:byte()
for s=8,1,-1 do q=q..(r%2^s-r%2^(s-1)>0 and'1'or'0')end
return q
end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(p)
if(#p<6)then return''end
local q=0
for r=1,6 do q=q+(p:sub(r,r)=='1'and 2^(6-r)or 0)end
return n:sub(q+1,q+1)
end)..({'','==','='})[#o%3+1])
end
end



local n=type(getscripthash)=="function"and getscripthash or nil
local o=type(decompile)=="function"and decompile or nil

local p=loadstring(game:HttpGet"https://raw.githubusercontent.com/chadhyatt/LuaEncode/refs/heads/master/src/LuaEncode.lua")()




local q=8
local r=60
local s=500

local function SanitizeForOutput(t,u,v)
u=u or 0
local w=typeof(t)

if w=="Instance"then
local x,y=pcall(function()return t:GetFullName()end)
return x and y or tostring(t)
elseif w=="string"then
if#t>s then
return string.sub(t,1,s)
.."…(+"..(#t-s).." chars omitted)"
end
return t
elseif w=="number"or w=="boolean"or w=="nil"then
return t
elseif w~="table"then

return tostring(t)
end

if u>=q then
return"<table: max depth reached>"
end

v=v or{}
if v[t]then
return"<cyclic table>"
end
v[t]=true

local x={}
local y=0
local z=0
for A,B in pairs(t)do
if y>=r then
z+=1
continue
end
y+=1
local C=A
if typeof(A)~="string"and typeof(A)~="number"then
C=tostring(A)
end
x[C]=SanitizeForOutput(B,u+1,v)
end
if z>0 then
x.__omitted=z.." more entries omitted"
end

v[t]=nil
return x
end



local function StripDecompilerBanner(t)
if typeof(t)~="string"then return t end
return(string.gsub(t,"^%s*%-%-[^\n]*[Dd]ecompiled[^\n]*\n","",1))
end

local t=getnilinstances or function()return{}end


local u=(
typeof(WebSocket)~="nil"and
typeof(WebSocket.connect)=="function"
)and(getgenv().DisableWebSocket~=true)


local function GenerateSessionGuid()
local v,w=pcall(function()
return j:GenerateGUID(false)
end)
if v and type(w)=="string"and w~=""then
return w
end
return tostring(os.clock()).."-"..tostring(math.random(1,1000000000))
end

local function GetClientIdentityKey()
local v=l.LocalPlayer
return table.concat({
tostring(game.PlaceId or 0),
tostring(game.JobId or""),
tostring(v and v.UserId or 0),
},":")
end

local function GetStableClientSessionId()
local v=GetClientIdentityKey()
if type(getgenv().MCP_ClientSessionId)~="string"or getgenv().MCP_ClientIdentityKey~=v then
getgenv().MCP_ClientSessionId=GenerateSessionGuid()
getgenv().MCP_ClientIdentityKey=v
end
return getgenv().MCP_ClientSessionId
end

local function GetRegistrationInfo()
local v=l.LocalPlayer
local w="Unknown"
pcall(function()
local x=f:GetProductInfo(game.PlaceId)
w=x.Name
end)
return{
type="register",
username=v and v.Name or"Unknown",
userId=v and v.UserId or 0,
placeId=game.PlaceId,
jobId=game.JobId,
placeName=w,
sessionId=GetStableClientSessionId(),
}
end


local v=a.a(){
HttpService=j,
BridgeURL=b,
WebSocketAvailable=u,
GetRegistrationInfo=GetRegistrationInfo,
SanitizeForOutput=SanitizeForOutput,
LuaEncode=p,
}
local w=v.CreateBridge


local x=a.b()
local y=a.c()
local z=a.d()
local A=a.e()
local B=a.f()
local C=y.new()
local D=math.max(
1,
math.min(math.floor(tonumber(getgenv().MCP_ScriptMappingWorkers)or 24),64)
)
local E=a.g().new(
C,
D
)
local F=math.max(
5,
math.min(tonumber(getgenv().MCP_FailedScriptResyncInterval)or 30,600)
)
local G=a.h().new(C,{
IntervalSeconds=F,
MaxDelaySeconds=math.max(F,300),
BatchSize=math.max(
1,
math.min(math.floor(tonumber(getgenv().MCP_FailedScriptResyncBatchSize)or 8),32)
),
})
local H=a.i().new(
C,
G
)
local I=a.j(){
ScriptMappingPipeline=C,
HttpService=j,
BridgeURL=b,
JobStatus=H,
}
local J=a.k(){
ScriptMappingPipeline=C,
HttpService=j,
BridgeURL=b,
StripDecompilerBanner=StripDecompilerBanner,
base64_encode=m,
BuiltInDecompile=o,
GetScriptHash=n,
DecompilerAttemptState=A,
PreparedScript=B,
Concurrency=E,
}
local K=a.l(){
ScriptMappingPipeline=C,
WorkerPool=x,
UploadSession=z,
GenerateSessionGuid=GenerateSessionGuid,
CoreGui=g,
CorePackages=h,
ScriptContext=i,
getnilinstances=t,
WorkerCount=D,
Concurrency=E,
JobStatus=H,
FailedResync=G,
UploadClient=I,
DecompilerClient=J,
}
local L=I.StartUploadQueue
local function PublishScriptMappingStatus()
H:Publish()
end
local M=K.StartScriptMapping
local N=K.StartFailedScriptResync
local O=K.ResetScriptMappingState
local P=K.ResumeDeferredScriptMappings
local Q=K.GetScriptByDebugId
local R=K.QueueMappedScriptSource
local S=K.DecompileScriptSource

local function WaitForBridgeClientId(T)
local U=os.clock()+5
repeat
if T.ClientId then
return T.ClientId
end
if not T.Connected then
return nil
end
task.wait(0.05)
until os.clock()>U

return nil
end a.v()

{
CreateBridge=w,
WaitForBridgeClientId=WaitForBridgeClientId,
ScriptMappingPipeline=C,
StartUploadQueue=L,
PublishScriptMappingStatus=PublishScriptMappingStatus,
ResetScriptMappingState=O,
StartScriptMapping=M,
StartFailedScriptResync=N,
ResumeDeferredScriptMappings=P,
GetScriptByDebugId=Q,
DecompileScriptSource=S,
QueueMappedScriptSource=R,
LogService=k,
MarketplaceService=f,
RobloxReplicatedStorage=d,
VirtualInputManager=e,
LuaEncode=p,
HttpService=j,
base64_encode=m,
}