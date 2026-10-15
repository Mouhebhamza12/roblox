local Players=game:GetService("Players")
local DSS=game:GetService("DataStoreService")
local RS=game:GetService("ReplicatedStorage")
local CS=game:GetService("CollectionService")
local C=require(RS:WaitForChild("HairConfig"))
local R=RS:WaitForChild("HairRemotes")
local Notify,FX,Shop=R.Notify,R.FX,R.Shop
local PINK=Color3.fromRGB(255,120,180)

local store
pcall(function() store=DSS:GetDataStore("HairData_v3") end)
local data={}

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

local function save(p)
	local d=data[p]
	if not (store and d) then return end
	local ok,err=pcall(function() store:SetAsync("u"..p.UserId,{Cash=d.Cash,Length=d.Length,Type=d.Type,Zone=d.Zone}) end)
	if not ok then warn("[Hair] save failed:",err) end
end

local function onJoin(p)
	local saved
	if store then
		local ok,res=pcall(function() return store:GetAsync("u"..p.UserId) end)
		if ok then saved=res else warn("[Hair] load failed:",res) end
	end
	saved=saved or {}
	if not p.Parent then return end
	local d={Cash=saved.Cash or C.StartCash,Length=saved.Length or 0,Type=saved.Type or 1,Zone=saved.Zone or 1,lastSell=0,lastFull=0}
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
	if not d or kind~="type" or typeof(i)~="number" then return end
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
	for p in pairs(data) do task.spawn(save,p) end
	task.wait(2)
end)
while true do
	task.wait(C.AutosaveInterval)
	for p in pairs(data) do task.spawn(save,p) end
end
