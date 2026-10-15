local Players=game:GetService("Players")
local DSS=game:GetService("DataStoreService")
local RS=game:GetService("ReplicatedStorage")
local CS=game:GetService("CollectionService")
local C=require(RS:WaitForChild("HairConfig"))
local R=RS:WaitForChild("HairRemotes")
local Notify,FX,Shop=R.Notify,R.FX,R.Shop
local PINK=Color3.fromRGB(255,120,180)

local RunService=game:GetService("RunService")
local IS_STUDIO=RunService:IsStudio()
-- Studio playtests use their own save so testing never changes real player progress.
local STORE_NAME=IS_STUDIO and "HairData_v3_STUDIO" or "HairData_v3"
local store
pcall(function() store=DSS:GetDataStore(STORE_NAME) end)
local data={}

local function key(p) return "u"..p.UserId end

-- Run a DataStore call up to `tries` times, waiting 2s, 4s... between attempts.
local function retry(fn,tries)
	local lastErr
	for i=1,tries do
		local ok,res=pcall(fn)
		if ok then return true,res end
		lastErr=res
		if i<tries then task.wait(2^i) end
	end
	return false,lastErr
end

-- Turn whatever is stored into safe, in-range values (protects against corrupt or old data).
local function cleanNumber(v,default,min,max)
	if typeof(v)~="number" or v~=v or v==math.huge or v==-math.huge then return default end
	return math.clamp(v,min,max)
end
local function sanitize(raw)
	raw=typeof(raw)=="table" and raw or {}
	local d={}
	d.Type=math.floor(cleanNumber(raw.Type,1,1,#C.Types))
	d.Zone=math.floor(cleanNumber(raw.Zone,1,1,#C.Zones))
	d.Cash=math.floor(cleanNumber(raw.Cash,C.StartCash,0,1e15))
	d.Length=cleanNumber(raw.Length,0,0,C.Types[d.Type].cap)
	d.Version=math.floor(cleanNumber(raw.Version,0,0,1e12)) -- save counter, used to block stale saves
	return d
end

local function sync(p)
	local d=data[p] if not d then return end
	p:SetAttribute("HairLen",d.Length)
	p:SetAttribute("HairType",d.Type)
	p:SetAttribute("Zone",d.Zone)
	d.CashStat.Value=d.Cash
	d.HairStat.Value=math.floor(d.Length)
end

local function strip(a)
	if not a:IsA("Accessory") then return end
	local h=a:FindFirstChild("Handle")
	if a.AccessoryType==Enum.AccessoryType.Hair or a.AccessoryType==Enum.AccessoryType.Hat
		or (h and (h:FindFirstChild("HairAttachment") or h:FindFirstChild("HatAttachment"))) then
		task.defer(a.Destroy,a)
	end
end
local function onCharacter(char)
	for _,c in ipairs(char:GetChildren()) do strip(c) end
	char.ChildAdded:Connect(strip)
	local hum=char:WaitForChild("Humanoid",10)
	if hum then hum.WalkSpeed=C.WalkSpeed hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
end

-- Save with UpdateAsync. If the stored Version is not the one this server loaded/last wrote,
-- another server saved newer data, so this server cancels instead of overwriting it.
local function save(p)
	local d=data[p]
	if not d or not store or d.noSave then return end
	while d.saving do task.wait(0.1) end
	if d.noSave then return end
	d.saving=true
	local payload={Cash=d.Cash,Length=d.Length,Type=d.Type,Zone=d.Zone}
	local stale=false
	local ok,err=retry(function()
		return store:UpdateAsync(key(p),function(old)
			local oldV=(typeof(old)=="table" and tonumber(old.Version)) or 0
			if oldV~=d.Version then stale=true return nil end
			stale=false
			payload.Version=d.Version+1
			return payload
		end)
	end,3)
	if ok and not stale then
		d.Version=payload.Version
	elseif ok and stale then
		d.noSave=true
		warn("[Hair] Not saving "..p.Name..": newer data was saved by another server.")
	else
		warn("[Hair] Save failed for "..p.Name..": "..tostring(err))
	end
	d.saving=false
end

local function onJoin(p)
	-- status: "loaded" (has a save), "new" (no save yet) or "failed" (could not read)
	local status,raw
	if not store then
		status="failed"
	elseif IS_STUDIO and workspace:GetAttribute("DebugFailLoad") then
		status="failed" -- Studio-only switch to test the failure path
	else
		local ok,res=retry(function() return store:GetAsync(key(p)) end,3)
		if not ok then status="failed" warn("[Hair] Load failed for "..p.Name..": "..tostring(res))
		elseif res==nil then status="new"
		else status="loaded" raw=res end
	end
	if not p.Parent then return end
	if status=="failed" then
		-- Never let a failed load turn into a fresh save that wipes real progress.
		p:Kick("Your hair data couldn't load, so we stopped the game to protect your progress. Please rejoin!")
		return
	end
	local d=sanitize(raw)
	d.lastSell=0 d.lastFull=0 d.lastShop=0
	local ls=Instance.new("Folder") ls.Name="leaderstats"
	d.CashStat=Instance.new("IntValue") d.CashStat.Name="Cash" d.CashStat.Parent=ls
	d.HairStat=Instance.new("IntValue") d.HairStat.Name="Hair" d.HairStat.Parent=ls
	ls.Parent=p
	data[p]=d
	sync(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then task.spawn(onCharacter,p.Character) end
end

local function fullNotice(p,d)
	if os.clock()-d.lastFull>3 then
		d.lastFull=os.clock()
		Notify:FireClient(p,"Your hair is FULL! Cut it at the Barbershop",PINK)
	end
end

-- Farm tufts: walk into them to collect hair
for _,t in ipairs(CS:GetTagged("Tuft")) do
	local zone=t:GetAttribute("Zone") or 1
	local Z=C.Zones[zone]
	local hit=t.PrimaryPart
	local vis={}
	for _,v in ipairs(t:GetDescendants()) do if v:IsA("BasePart") and v~=hit then table.insert(vis,v) end end
	local ready=true
	hit.Touched:Connect(function(h)
		if not ready then return end
		local p=Players:GetPlayerFromCharacter(h.Parent)
		local d=p and data[p]
		if not d or zone>d.Zone then return end
		local cap=C.Types[d.Type].cap
		if d.Length>=cap then fullNotice(p,d) return end
		ready=false
		local add=math.min(Z.amount,cap-d.Length)
		d.Length+=add
		sync(p)
		for _,v in ipairs(vis) do v.Transparency=1 end
		FX:FireClient(p,"collect",add,hit.Position,Z.tuft)
		if d.Length>=cap then fullNotice(p,d) end
		task.delay(C.Regrow,function()
			for _,v in ipairs(vis) do v.Transparency=0 end
			ready=true
		end)
	end)
end

-- Barbershop: step into the haircut zone to sell
local city=workspace:WaitForChild("HairCity")
local pad=city:WaitForChild("HaircutZone")
pad.Touched:Connect(function(h)
	local p=Players:GetPlayerFromCharacter(h.Parent)
	local d=p and data[p]
	if not d or d.Length<=0 then return end
	if os.clock()-d.lastSell<C.SellCooldown then return end
	d.lastSell=os.clock()
	local v=math.max(1,C.Value(d.Length,d.Type))
	d.Cash+=v
	d.Length=0
	sync(p)
	FX:FireAllClients("cut",p.Character,v,p)
end)

-- Farm gates
for _,k in ipairs(CS:GetTagged("ZoneKiosk")) do
	local i=k:GetAttribute("Zone")
	local Z=C.Zones[i]
	local pr=k:FindFirstChildWhichIsA("ProximityPrompt",true)
	pr.Triggered:Connect(function(p)
		local d=data[p] if not d or d.Zone>=i then return end
		if d.Zone<i-1 then Notify:FireClient(p,"Unlock "..C.Zones[i-1].name.." first!",PINK) return end
		if d.Cash<Z.price then Notify:FireClient(p,"You need $"..C.Format(Z.price-d.Cash).." more!",Color3.fromRGB(255,110,110)) return end
		d.Cash-=Z.price d.Zone=i
		sync(p)
		FX:FireClient(p,"unlock",i)
	end)
end

-- Hair type shop
Shop.OnServerEvent:Connect(function(p,kind,i)
	local d=data[p]
	if not d or kind~="type" or typeof(i)~="number" or i~=i then return end
	if os.clock()-d.lastShop<0.25 then return end -- simple rate limit
	d.lastShop=os.clock()
	i=math.floor(i)
	local T=C.Types[i]
	if not T or i<=d.Type then return end
	if d.Cash<T.price then Notify:FireClient(p,"You need $"..C.Format(T.price-d.Cash).." more!",Color3.fromRGB(255,110,110)) return end
	d.Cash-=T.price d.Type=i
	sync(p)
	FX:FireClient(p,"typeBought",i)
end)

Players.PlayerAdded:Connect(onJoin)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(onJoin,p) end
Players.PlayerRemoving:Connect(function(p) save(p) data[p]=nil end)
game:BindToClose(function()
	local pending=0
	for p in pairs(data) do
		pending+=1
		task.spawn(function() save(p) pending-=1 end)
	end
	local start=os.clock()
	while pending>0 and os.clock()-start<25 do task.wait(0.1) end
end)
while true do
	task.wait(C.AutosaveInterval)
	for p in pairs(data) do task.spawn(save,p) end
end
