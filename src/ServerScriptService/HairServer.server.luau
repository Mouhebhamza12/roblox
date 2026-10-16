--[[ GROW HAIR! server
	- Saving (safe load/save, Studio uses its own test save)
	- Tycoon plots: claim, buy buttons, building items
	- Hair beds: grow over time, harvest onto your head, Auto-Clipper passive cash
	- Barbershop selling, hair-type shop
]]
local Players=game:GetService("Players")
local DSS=game:GetService("DataStoreService")
local RS=game:GetService("ReplicatedStorage")
local CS=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local C=require(RS:WaitForChild("HairConfig"))
local R=RS:WaitForChild("HairRemotes")
local Notify,FX,Shop,Action=R.Notify,R.FX,R.Shop,R.Action
local PINK=Color3.fromRGB(255,120,180)
local RED=Color3.fromRGB(255,110,110)

local function now() return workspace:GetServerTimeNow() end

------------------------------------------------------------------ DATA
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
	d.Cash=math.floor(cleanNumber(raw.Cash,C.StartCash,0,1e15))
	d.Length=cleanNumber(raw.Length,0,0,C.Types[d.Type].cap)
	d.Version=math.floor(cleanNumber(raw.Version,0,0,1e12)) -- save counter, used to block stale saves
	d.Owned={}
	if typeof(raw.Owned)=="table" then
		for _,id in ipairs(raw.Owned) do
			if typeof(id)=="string" and C.ItemById[id] then d.Owned[id]=true end
		end
	end
	return d
end

local function sync(p)
	local d=data[p] if not d then return end
	p:SetAttribute("HairLen",d.Length)
	p:SetAttribute("HairType",d.Type)
	d.CashStat.Value=d.Cash
	d.HairStat.Value=math.floor(d.Length)
end

-- Save with UpdateAsync. If the stored Version is not the one this server loaded/last wrote,
-- another server saved newer data, so this server cancels instead of overwriting it.
local function save(p)
	local d=data[p]
	if not d or not store or d.noSave then return end
	while d.saving do task.wait(0.1) end
	if d.noSave then return end
	d.saving=true
	local owned={}
	for id in pairs(d.Owned) do table.insert(owned,id) end
	local payload={Cash=d.Cash,Length=d.Length,Type=d.Type,Owned=owned}
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

------------------------------------------------------------------ BUILD HELPERS
local CREAM=Color3.fromRGB(255,244,236)
local PLUM=Color3.fromRGB(70,45,85)
local GOLD=Color3.fromRGB(255,205,90)
local LPINK=Color3.fromRGB(255,190,215)
local HOTPINK=Color3.fromRGB(255,120,175)

local function P(props,parent)
	local p=Instance.new("Part")
	p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
	p.Material=Enum.Material.SmoothPlastic
	for k,v in pairs(props) do p[k]=v end
	p.Parent=parent
	return p
end
local function textGui(part,face,text,color,stroke)
	local g=Instance.new("SurfaceGui") g.Face=face g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud=40 g.LightInfluence=0 g.Parent=part
	local t=Instance.new("TextLabel") t.Name="Text" t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.TextScaled=true
	t.Font=Enum.Font.FredokaOne t.Text=text t.TextColor3=color t.Parent=g
	local s=Instance.new("UIStroke") s.Color=stroke or PLUM s.Thickness=4 s.Parent=t
	local pad=Instance.new("UIPadding",t) pad.PaddingLeft=UDim.new(0.05,0) pad.PaddingRight=UDim.new(0.05,0) pad.PaddingTop=UDim.new(0.08,0) pad.PaddingBottom=UDim.new(0.08,0)
	return t
end
local function board(part,text,color,studs,offset)
	local bb=Instance.new("BillboardGui") bb.Name="Board" bb.Size=UDim2.new(studs.X,0,studs.Y,0) bb.StudsOffset=offset bb.LightInfluence=0 bb.MaxDistance=90 bb.Parent=part
	local t=Instance.new("TextLabel") t.Name="Text" t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.TextScaled=true t.Font=Enum.Font.FredokaOne
	t.Text=text t.TextColor3=color t.Parent=bb
	local s=Instance.new("UIStroke") s.Color=PLUM s.Thickness=3 s.Parent=t
	return t
end

------------------------------------------------------------------ PLOTS
local plotsFolder=workspace:WaitForChild("Plots")
local plots={}
for i=1,C.PlotCount do
	local m=plotsFolder:WaitForChild("Plot"..i)
	plots[i]=m
end
local function top(plot) local b=plot.Base return b.CFrame*CFrame.new(0,b.Size.Y/2,0) end
local function at(plot,v) return top(plot)*CFrame.new(v) end
local function setTitle(plot,text) local t=plot.Sign:FindFirstChild("Text",true) if t then t.Text=text end end

-- Each item kind has a builder that makes its model inside plot.Items
local builders={}

builders.bed=function(plot,it,m)
	local cf=at(plot,it.pos)
	local wood=Color3.fromRGB(235,190,150)
	P({Size=Vector3.new(10,1.4,0.7),CFrame=cf*CFrame.new(0,0.7,-3.85),Color=wood},m)
	P({Size=Vector3.new(10,1.4,0.7),CFrame=cf*CFrame.new(0,0.7,3.85),Color=wood},m)
	P({Size=Vector3.new(0.7,1.4,7),CFrame=cf*CFrame.new(-4.65,0.7,0),Color=wood},m)
	P({Size=Vector3.new(0.7,1.4,7),CFrame=cf*CFrame.new(4.65,0.7,0),Color=wood},m)
	local soil=P({Name="Soil",Size=Vector3.new(9.3,1.1,7.7),CFrame=cf*CFrame.new(0,0.55,0),Color=Color3.fromRGB(150,105,90),Material=Enum.Material.Fabric},m)
	soil:SetAttribute("Owner",plot:GetAttribute("Owner"))
	soil:SetAttribute("GrowStart",now())
	soil:SetAttribute("GrowTime",C.BedGrowTime)
	soil:SetAttribute("Yield",C.BedYield)
	CS:AddTag(soil,"HairBed")
end

builders.fence=function(plot,it,m)
	local h=C.PlotSize/2
	local col=Color3.fromRGB(255,255,255)
	local function rail(a,b)
		local mid=(a+b)/2 local len=(b-a).Magnitude
		local cf=CFrame.lookAt(mid,b)
		P({Size=Vector3.new(0.5,0.5,len),CFrame=at(plot,Vector3.zero)*cf*CFrame.new(0,2.6,0),Color=col},m)
		P({Size=Vector3.new(0.5,0.5,len),CFrame=at(plot,Vector3.zero)*cf*CFrame.new(0,1.4,0),Color=col},m)
	end
	local pts={Vector3.new(-h,0,-h),Vector3.new(-h,0,h),Vector3.new(h,0,h),Vector3.new(h,0,-h)}
	rail(pts[1],pts[2]) rail(pts[2],pts[3]) rail(pts[3],pts[4])
	rail(Vector3.new(-h,0,-h),Vector3.new(-8,0,-h)) rail(Vector3.new(8,0,-h),Vector3.new(h,0,-h))
	for _,v in ipairs({pts[1],pts[2],pts[3],pts[4],Vector3.new(-8,0,-h),Vector3.new(8,0,-h)}) do
		P({Size=Vector3.new(1,3.6,1),CFrame=at(plot,v+Vector3.new(0,1.8,0)),Color=HOTPINK},m)
	end
end

builders.sign=function(plot,it,m)
	local h=C.PlotSize/2
	for _,x in ipairs({-8,8}) do P({Size=Vector3.new(1.6,14,1.6),CFrame=at(plot,Vector3.new(x,7,-h+0.5)),Color=HOTPINK},m) end
	P({Size=Vector3.new(19,4.6,1),CFrame=at(plot,Vector3.new(0,15,-h+0.5)),Color=GOLD,Material=Enum.Material.Metal},m)
	local b=P({Size=Vector3.new(18,3.8,1.2),CFrame=at(plot,Vector3.new(0,15,-h+0.5)),Color=CREAM},m)
	local name=plot:GetAttribute("OwnerName") or "My"
	textGui(b,Enum.NormalId.Front,name.."'s Hair Salon",HOTPINK)
	textGui(b,Enum.NormalId.Back,name.."'s Hair Salon",HOTPINK)
end

builders.sprinkler=function(plot,it,m)
	P({Size=Vector3.new(56,0.4,0.4),CFrame=at(plot,Vector3.new(0,5,7)),Color=Color3.fromRGB(120,190,255),Material=Enum.Material.Metal},m)
	for _,x in ipairs({-28,28}) do P({Size=Vector3.new(0.5,5,0.5),CFrame=at(plot,Vector3.new(x,2.5,7)),Color=Color3.fromRGB(120,190,255),Material=Enum.Material.Metal},m) end
	for _,x in ipairs({-21,-7,7,21}) do
		local head=P({Shape=Enum.PartType.Ball,Size=Vector3.new(0.9,0.9,0.9),CFrame=at(plot,Vector3.new(x,4.7,7)),Color=Color3.fromRGB(200,230,255),CanCollide=false},m)
		local pe=Instance.new("ParticleEmitter") pe.Rate=10 pe.Lifetime=NumberRange.new(0.6,0.9) pe.Speed=NumberRange.new(6,9)
		pe.SpreadAngle=Vector2.new(70,70) pe.Acceleration=Vector3.new(0,-25,0) pe.Size=NumberSequence.new(0.18,0.05)
		pe.Color=ColorSequence.new(Color3.fromRGB(150,210,255)) pe.Transparency=NumberSequence.new(0.2,1) pe.EmissionDirection=Enum.NormalId.Bottom pe.Parent=head
	end
end

builders.fertilizer=function(plot,it,m)
	for i=0,2 do
		P({Size=Vector3.new(2.2,1.4,1.4),CFrame=at(plot,Vector3.new(28,0.7+i*1.2,4+i%2*0.4))*CFrame.Angles(0,math.rad(i*12),0),Color=Color3.fromRGB(150,220,140),Material=Enum.Material.Fabric},m)
	end
end

builders.lamps=function(plot,it,m)
	for _,x in ipairs({-14,0,14}) do
		P({Size=Vector3.new(0.6,9,0.6),CFrame=at(plot,Vector3.new(x,4.5,7)),Color=PLUM},m)
		P({Size=Vector3.new(4,0.4,1.4),CFrame=at(plot,Vector3.new(x,9,7)),Color=PLUM},m)
		local l=P({Size=Vector3.new(3.6,0.3,1),CFrame=at(plot,Vector3.new(x,8.75,7)),Color=GOLD,Material=Enum.Material.Neon,CanCollide=false},m)
		local pl=Instance.new("SpotLight") pl.Face=Enum.NormalId.Bottom pl.Range=14 pl.Angle=110 pl.Brightness=2 pl.Color=Color3.fromRGB(255,215,140) pl.Parent=l
	end
end

builders.chairs=function(plot,it,m)
	for i,x in ipairs({-28,-22,-16}) do
		local cf=at(plot,Vector3.new(x,0,-22))
		P({Shape=Enum.PartType.Cylinder,Size=Vector3.new(0.4,2.2,2.2),CFrame=cf*CFrame.new(0,0.2,0)*CFrame.Angles(0,0,math.rad(90)),Color=Color3.fromRGB(200,200,210),Material=Enum.Material.Metal},m)
		P({Size=Vector3.new(0.5,1.4,0.5),CFrame=cf*CFrame.new(0,1.1,0),Color=Color3.fromRGB(200,200,210),Material=Enum.Material.Metal},m)
		P({Size=Vector3.new(2.6,0.7,2.4),CFrame=cf*CFrame.new(0,2,0),Color=HOTPINK},m)
		P({Size=Vector3.new(2.6,2.8,0.5),CFrame=cf*CFrame.new(0,3.5,-1.1),Color=HOTPINK},m)
		P({Size=Vector3.new(0.4,0.5,2.2),CFrame=cf*CFrame.new(-1.3,2.6,0),Color=CREAM},m)
		P({Size=Vector3.new(0.4,0.5,2.2),CFrame=cf*CFrame.new(1.3,2.6,0),Color=CREAM},m)
	end
end

builders.fountain=function(plot,it,m)
	local cf=at(plot,Vector3.new(22,0,-21))
	P({Shape=Enum.PartType.Cylinder,Size=Vector3.new(1.4,9,9),CFrame=cf*CFrame.new(0,0.7,0)*CFrame.Angles(0,0,math.rad(90)),Color=LPINK},m)
	P({Shape=Enum.PartType.Cylinder,Size=Vector3.new(0.3,8,8),CFrame=cf*CFrame.new(0,1.3,0)*CFrame.Angles(0,0,math.rad(90)),Color=Color3.fromRGB(120,220,230),Material=Enum.Material.Glass,Transparency=0.3,CanCollide=false},m)
	P({Shape=Enum.PartType.Cylinder,Size=Vector3.new(3,1.6,1.6),CFrame=cf*CFrame.new(0,2.5,0)*CFrame.Angles(0,0,math.rad(90)),Color=CREAM},m)
	local top2=P({Shape=Enum.PartType.Ball,Size=Vector3.new(1.4,1.4,1.4),CFrame=cf*CFrame.new(0,4.3,0),Color=GOLD,Material=Enum.Material.Metal},m)
	local pe=Instance.new("ParticleEmitter") pe.Rate=25 pe.Lifetime=NumberRange.new(0.8,1.1) pe.Speed=NumberRange.new(7,9)
	pe.SpreadAngle=Vector2.new(20,20) pe.Acceleration=Vector3.new(0,-22,0) pe.Size=NumberSequence.new(0.25,0.08)
	pe.Color=ColorSequence.new(Color3.fromRGB(160,230,255)) pe.Transparency=NumberSequence.new(0.1,1) pe.Parent=top2
end

builders.statue=function(plot,it,m)
	local cf=at(plot,Vector3.new(0,0,-12))
	P({Size=Vector3.new(5,1.5,5),CFrame=cf*CFrame.new(0,0.75,0),Color=CREAM},m)
	P({Size=Vector3.new(4,0.4,4),CFrame=cf*CFrame.new(0,1.7,0),Color=GOLD,Material=Enum.Material.Metal},m)
	-- giant golden comb
	P({Size=Vector3.new(7,1.6,0.6),CFrame=cf*CFrame.new(0,7.2,0),Color=GOLD,Material=Enum.Material.Metal},m)
	for i=0,9 do
		P({Size=Vector3.new(0.35,4,0.5),CFrame=cf*CFrame.new(-3.15+i*0.7,4.4,0),Color=GOLD,Material=Enum.Material.Metal},m)
	end
	P({Size=Vector3.new(0.8,4.5,0.8),CFrame=cf*CFrame.new(0,3.6,0),Color=GOLD,Material=Enum.Material.Metal,Transparency=1},m)
end

builders.autoclip=function(plot,it,m)
	-- clipper machine (left) -> conveyor -> hair press (right) -> cash collector (front right)
	local mach=at(plot,Vector3.new(-24,0,26))
	P({Name="Machine",Size=Vector3.new(7,6,6),CFrame=mach*CFrame.new(0,3,0),Color=Color3.fromRGB(190,170,240)},m)
	P({Size=Vector3.new(7.4,0.6,6.4),CFrame=mach*CFrame.new(0,6.3,0),Color=GOLD,Material=Enum.Material.Metal},m)
	local blade=P({Name="Blades",Size=Vector3.new(0.4,4,1),CFrame=mach*CFrame.new(0,8,0)*CFrame.Angles(0,0,math.rad(25)),Color=Color3.fromRGB(220,225,235),Material=Enum.Material.Metal,CanCollide=false},m)
	P({Name="Blades2",Size=Vector3.new(0.4,4,1),CFrame=mach*CFrame.new(0,8,0)*CFrame.Angles(0,0,math.rad(-25)),Color=Color3.fromRGB(220,225,235),Material=Enum.Material.Metal,CanCollide=false},m)
	local cs=P({Name="ConvStart",Size=Vector3.new(1,1,1),CFrame=at(plot,Vector3.new(-19,1.6,26)),Transparency=1,CanCollide=false},m)
	local ce=P({Name="ConvEnd",Size=Vector3.new(1,1,1),CFrame=at(plot,Vector3.new(19,1.6,26)),Transparency=1,CanCollide=false},m)
	P({Name="Belt",Size=Vector3.new(38,0.6,3),CFrame=at(plot,Vector3.new(0,1,26)),Color=Color3.fromRGB(60,55,75),Material=Enum.Material.Rubber},m)
	P({Size=Vector3.new(38,0.3,0.4),CFrame=at(plot,Vector3.new(0,1.4,24.4)),Color=GOLD,Material=Enum.Material.Metal},m)
	P({Size=Vector3.new(38,0.3,0.4),CFrame=at(plot,Vector3.new(0,1.4,27.6)),Color=GOLD,Material=Enum.Material.Metal},m)
	local press=at(plot,Vector3.new(24,0,26))
	P({Name="Press",Size=Vector3.new(6,7,6),CFrame=press*CFrame.new(0,3.5,0),Color=Color3.fromRGB(255,170,200)},m)
	local sg=P({Size=Vector3.new(5,1.6,0.3),CFrame=press*CFrame.new(0,5.5,-3.1),Color=CREAM},m)
	textGui(sg,Enum.NormalId.Front,"HAIR PRESS",HOTPINK)
	local col=P({Name="Collector",Size=Vector3.new(5,0.4,5),CFrame=at(plot,Vector3.new(26,0.2,-8)),Color=Color3.fromRGB(110,235,140),Material=Enum.Material.Neon,Transparency=0.15,CanCollide=false},m)
	col:SetAttribute("Stored",0)
	board(col,"$0\nstep to collect",Color3.fromRGB(140,255,170),Vector2.new(8,3),Vector3.new(0,4,0))
end

local function itemModel(plot,id) return plot.Items:FindFirstChild(id) end

-- Grow speed and yield depend on owned upgrades
local function applyUpgrades(plot,d)
	local t=C.BedGrowTime*(d.Owned.sprinkler and (2/3) or 1)
	local y=C.BedYield*(d.Owned.fertilizer and 2 or 1)*(d.Owned.lamps and 2 or 1)
	for _,soil in ipairs(CS:GetTagged("HairBed")) do
		if soil:IsDescendantOf(plot) then
			soil:SetAttribute("GrowTime",t)
			soil:SetAttribute("Yield",y)
			if d.Owned.fertilizer then soil.Color=Color3.fromRGB(110,75,65) end
		end
	end
end

local function buildItem(plot,id)
	local it=C.ItemById[id]
	if not it or itemModel(plot,id) then return end
	local m=Instance.new("Model") m.Name=id
	builders[it.kind](plot,it,m)
	m.Parent=plot.Items
end

local refreshButtons -- defined below

local function buy(p,id)
	local d=data[p] local it=C.ItemById[id]
	if not d or not it or not d.plot then return end
	if d.Owned[id] then return end
	if it.requires and not d.Owned[it.requires] then return end
	if d.Cash<it.price then Notify:FireClient(p,"You need $"..C.Format(it.price-d.Cash).." more!",RED) return end
	d.Cash-=it.price
	d.Owned[id]=true
	sync(p)
	buildItem(d.plot,id)
	applyUpgrades(d.plot,d)
	refreshButtons(p)
	FX:FireClient(p,"bought",it.name)
end

refreshButtons=function(p)
	local d=data[p] if not d or not d.plot then return end
	local plot=d.plot
	for _,b in ipairs(plot.Buttons:GetChildren()) do
		local it=C.ItemById[b.Name]
		if not it or d.Owned[b.Name] or (it.requires and not d.Owned[it.requires]) then b:Destroy() end
	end
	for _,it in ipairs(C.Items) do
		if not d.Owned[it.id] and (not it.requires or d.Owned[it.requires]) and not plot.Buttons:FindFirstChild(it.id) then
			local b=P({Name=it.id,Size=Vector3.new(4,0.5,4),CFrame=at(plot,(it.btn or it.pos)+Vector3.new(0,0.25,0)),
				Color=it.price==0 and Color3.fromRGB(110,235,140) or Color3.fromRGB(255,140,185),Material=Enum.Material.Neon,CanCollide=false},plot.Buttons)
			local label=it.name.."\n"..(it.price==0 and "FREE" or "$"..C.Format(it.price))
			if it.desc then label=label.."\n("..it.desc..")" end
			board(b,label,Color3.new(1,1,1),Vector2.new(9,it.desc and 4.5 or 3),Vector3.new(0,3.2,0))
			local busy=false
			b.Touched:Connect(function(hit)
				if busy then return end
				local who=Players:GetPlayerFromCharacter(hit.Parent)
				if who~=p then return end
				busy=true
				buy(p,it.id)
				task.wait(0.6)
				busy=false
			end)
		end
	end
end

local function claimPlot(p)
	local d=data[p]
	for _,plot in ipairs(plots) do
		if (plot:GetAttribute("Owner") or 0)==0 then
			plot:SetAttribute("Owner",p.UserId)
			plot:SetAttribute("OwnerName",p.DisplayName)
			setTitle(plot,p.DisplayName.."'s Plot")
			d.plot=plot
			p:SetAttribute("Plot",plot.Name)
			for _,it in ipairs(C.Items) do if d.Owned[it.id] then buildItem(plot,it.id) end end
			applyUpgrades(plot,d)
			refreshButtons(p)
			return plot
		end
	end
end

local function releasePlot(p,d)
	local plot=d and d.plot
	if not plot then return end
	plot.Items:ClearAllChildren()
	plot.Buttons:ClearAllChildren()
	plot:SetAttribute("Owner",0)
	plot:SetAttribute("OwnerName",nil)
	setTitle(plot,"EMPTY PLOT")
end

------------------------------------------------------------------ CHARACTERS
local function strip(a)
	if not a:IsA("Accessory") then return end
	local h=a:FindFirstChild("Handle")
	if a.AccessoryType==Enum.AccessoryType.Hair or a.AccessoryType==Enum.AccessoryType.Hat
		or (h and (h:FindFirstChild("HairAttachment") or h:FindFirstChild("HatAttachment"))) then
		task.defer(a.Destroy,a)
	end
end
local function onCharacter(p,char)
	for _,c in ipairs(char:GetChildren()) do strip(c) end
	char.ChildAdded:Connect(strip)
	local hum=char:WaitForChild("Humanoid",10)
	if hum then hum.WalkSpeed=C.WalkSpeed hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
	-- spawn at your own plot
	local d=data[p]
	local hrp=char:WaitForChild("HumanoidRootPart",10)
	if d and d.plot and hrp then
		task.wait(0.1)
		char:PivotTo(at(d.plot,Vector3.new(0,4,-26))*CFrame.Angles(0,math.pi,0))
	end
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
	d.lastSell=0 d.lastFull=0 d.lastShop=0 d.lastAction=0
	local ls=Instance.new("Folder") ls.Name="leaderstats"
	d.CashStat=Instance.new("IntValue") d.CashStat.Name="Cash" d.CashStat.Parent=ls
	d.HairStat=Instance.new("IntValue") d.HairStat.Name="Hair" d.HairStat.Parent=ls
	ls.Parent=p
	data[p]=d
	sync(p)
	if not claimPlot(p) then Notify:FireClient(p,"All plots are taken!",RED) end
	p.CharacterAdded:Connect(function(c) onCharacter(p,c) end)
	if p.Character then task.spawn(onCharacter,p,p.Character) end
end

local function fullNotice(p,d)
	if os.clock()-d.lastFull>3 then
		d.lastFull=os.clock()
		Notify:FireClient(p,"Your hair is FULL! Sell it at the Barbershop",PINK)
	end
end

------------------------------------------------------------------ HARVEST (client asks, server checks everything)
Action.OnServerEvent:Connect(function(p,kind,soil)
	local d=data[p]
	if not d or kind~="harvest" then return end
	if os.clock()-d.lastAction<0.15 then return end
	d.lastAction=os.clock()
	if typeof(soil)~="Instance" or not soil:IsA("BasePart") or not CS:HasTag(soil,"HairBed") then return end
	if not d.plot or not soil:IsDescendantOf(d.plot) then return end
	local char=p.Character local hrp=char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position-soil.Position).Magnitude>C.HarvestRange then return end
	local start,gt=soil:GetAttribute("GrowStart"),soil:GetAttribute("GrowTime")
	if now()<start+gt then return end
	local cap=C.Types[d.Type].cap
	if d.Length>=cap then fullNotice(p,d) return end
	local add=math.min(soil:GetAttribute("Yield"),cap-d.Length)
	d.Length+=add
	soil:SetAttribute("GrowStart",now())
	sync(p)
	FX:FireClient(p,"collect",add,soil.Position,C.Types[d.Type].color)
	if d.Length>=cap then fullNotice(p,d) end
end)

------------------------------------------------------------------ AUTO-CLIPPER + COLLECTOR
task.spawn(function()
	while true do
		task.wait(1)
		local t=now()
		for p,d in pairs(data) do
			if d.plot and d.Owned.autoclip then
				local auto=itemModel(d.plot,"autoclip")
				local col=auto and auto:FindFirstChild("Collector")
				if col then
					for _,soil in ipairs(CS:GetTagged("HairBed")) do
						if soil:IsDescendantOf(d.plot) then
							local readyAt=soil:GetAttribute("GrowStart")+soil:GetAttribute("GrowTime")
							if t>=readyAt+C.AutoDelay then
								local cash=math.max(1,math.floor(soil:GetAttribute("Yield")*C.AutoRate*C.Types[d.Type].mult))
								soil:SetAttribute("GrowStart",t)
								col:SetAttribute("Stored",col:GetAttribute("Stored")+cash)
								FX:FireAllClients("auto",soil,auto)
							end
						end
					end
					local txt=col:FindFirstChild("Text",true)
					if txt then txt.Text="$"..C.Format(col:GetAttribute("Stored")).."\nstep to collect" end
				end
			end
		end
	end
end)

-- Collector pads: owner steps on to collect stored cash
local function hookCollectors()
	for _,plot in ipairs(plots) do
		plot.Items.DescendantAdded:Connect(function(x)
			if x.Name=="Collector" and x:IsA("BasePart") then
				x.Touched:Connect(function(hit)
					local p=Players:GetPlayerFromCharacter(hit.Parent)
					local d=p and data[p]
					if not d or d.plot~=plot then return end
					local s=x:GetAttribute("Stored") or 0
					if s<=0 then return end
					x:SetAttribute("Stored",0)
					d.Cash+=s
					sync(p)
					local txt=x:FindFirstChild("Text",true) if txt then txt.Text="$0\nstep to collect" end
					FX:FireClient(p,"collectCash",s)
				end)
			end
		end)
	end
end
hookCollectors()

------------------------------------------------------------------ BARBERSHOP SELLING
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

------------------------------------------------------------------ HAIR TYPE SHOP
Shop.OnServerEvent:Connect(function(p,kind,i)
	local d=data[p]
	if not d or kind~="type" or typeof(i)~="number" or i~=i then return end
	if os.clock()-d.lastShop<0.25 then return end -- simple rate limit
	d.lastShop=os.clock()
	i=math.floor(i)
	local T=C.Types[i]
	if not T or i<=d.Type then return end
	if d.Cash<T.price then Notify:FireClient(p,"You need $"..C.Format(T.price-d.Cash).." more!",RED) return end
	d.Cash-=T.price d.Type=i
	sync(p)
	FX:FireClient(p,"typeBought",i)
end)

------------------------------------------------------------------ LIFECYCLE
Players.PlayerAdded:Connect(onJoin)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(onJoin,p) end
-- Move any uncollected Auto-Clipper cash into the player's cash before saving
local function bankCollector(d)
	if not (d and d.plot) then return end
	local auto=itemModel(d.plot,"autoclip")
	local col=auto and auto:FindFirstChild("Collector")
	if col then
		d.Cash+=col:GetAttribute("Stored") or 0
		col:SetAttribute("Stored",0)
	end
end
Players.PlayerRemoving:Connect(function(p)
	local d=data[p]
	bankCollector(d)
	save(p)
	releasePlot(p,d)
	data[p]=nil
end)
game:BindToClose(function()
	local pending=0
	for p,d in pairs(data) do
		bankCollector(d)
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
