local Players=game:GetService("Players")
local TS=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local RunS=game:GetService("RunService")
local CS=game:GetService("CollectionService")
local PPS=game:GetService("ProximityPromptService")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local C=require(RS:WaitForChild("HairConfig"))
local R=RS:WaitForChild("HairRemotes")
local Notify,FX,Shop=R:WaitForChild("Notify"),R:WaitForChild("FX"),R:WaitForChild("Shop")
local player=Players.LocalPlayer
local camera=workspace.CurrentCamera

local PINK=Color3.fromRGB(255,110,165)
local PLUM=Color3.fromRGB(55,35,70)
local GOLD=Color3.fromRGB(255,205,90)
local GREEN=Color3.fromRGB(120,240,140)
local WHITE=Color3.new(1,1,1)

local function snd(id,vol,loop)
	local s=Instance.new("Sound") s.SoundId="rbxassetid://"..id s.Volume=vol s.Looped=loop or false s.Parent=SoundService return s
end
local sCoin,sPop,music=snd(C.SoundCoin,0.7),snd(C.SoundPop,0.5),snd(C.Music,0.2,true)
music:Play()

------------------------------------------------------------------ HAIR (drawn locally for every player)
local SEG=C.Segments
local DIRS={}
do
	local N,g,cand=500,math.pi*(3-math.sqrt(5)),{}
	for i=0,N-1 do
		local y=1-2*(i+0.5)/N
		local r=math.sqrt(1-y*y)
		local x,z=math.cos(i*g)*r,math.sin(i*g)*r
		if (z<-0.25 and y>0.5) or (z>=-0.25 and z<0.25 and y>0.1) or (z>=0.25 and y>-0.3) then table.insert(cand,Vector3.new(x,y,z)) end
	end
	local step=math.max(1,math.ceil(#cand/C.Locks))
	for i=1,#cand,step do table.insert(DIRS,cand[i]) end
end

local rigs={}
local function newPart(m,head)
	local p=Instance.new("Part")
	p.CanCollide=false p.CanQuery=false p.CanTouch=false p.Massless=true p.CastShadow=false
	p.Material=Enum.Material.SmoothPlastic p.Transparency=1 p.Size=Vector3.new(0.1,0.1,0.1)
	local w=Instance.new("Weld") w.Part0=head w.Part1=p w.Parent=p
	p.Parent=m
	return p,w
end

local function buildRig(plr,char)
	local head=char:WaitForChild("Head",10)
	if not head or not char.Parent then return end
	local old=char:FindFirstChild("HairVisual") if old then old:Destroy() end
	local m=Instance.new("Model") m.Name="HairVisual"
	local hs=head.Size
	local capP,capW=newPart(m,head)
	capP.Size=Vector3.one
	local mesh=Instance.new("SpecialMesh") mesh.MeshType=Enum.MeshType.Sphere mesh.Parent=capP
	capW.C0=CFrame.new(0,hs.Y*0.17,hs.Z*0.1)
	local rng=Random.new(plr.UserId)
	local locks={}
	for i,d in ipairs(DIRS) do
		local segs={}
		for k=1,SEG do local p,w=newPart(m,head) segs[k]={part=p,weld=w} end
		local side=d:Cross(Vector3.yAxis)
		side=side.Magnitude>0.01 and side.Unit or Vector3.xAxis
		local fall=Vector3.new(d.X*0.15+rng:NextNumber(-0.08,0.08),-1,math.max(d.Z,0)*0.15+(d.Z<0 and 0.8 or 0.4)+rng:NextNumber(-0.08,0.08)).Unit
		locks[i]={dir=(d.Z<0) and (d+Vector3.new(0,0.4,-d.Z*1.8)).Unit or d,root=d*hs/2*0.92,fall=fall,side=side,lm=rng:NextNumber(0.8,1.15),shade=rng:NextNumber(-0.12,0.12),phase=rng:NextNumber(0,6.28),hue=i/#DIRS,segs=segs}
	end
	local bb=Instance.new("BillboardGui") bb.Name="HairTag" bb.Size=UDim2.fromOffset(240,50) bb.StudsOffset=Vector3.new(0,2.8,0) bb.MaxDistance=80 bb.Adornee=head bb.Parent=m
	local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Font=Enum.Font.FredokaOne t.TextScaled=true t.RichText=true
	t.TextColor3=WHITE t.TextStrokeColor3=PLUM t.TextStrokeTransparency=0 t.Parent=bb
	m.Parent=char
	rigs[char]={player=plr,char=char,head=head,model=m,cap=capP,mesh=mesh,hs=hs,locks=locks,shown=-1,typeShown=0,tag=t,tagKey=""}
end

local function lockColor(T,lk,now)
	if T.rainbow then return Color3.fromHSV((lk.hue+now*0.15)%1,0.55,1) end
	if lk.shade>0 then return T.color:Lerp(Color3.new(1,0.95,0.85),lk.shade) end
	return T.color:Lerp(Color3.new(0,0,0),-lk.shade)
end

local function draw(rig,len,T)
	local f=math.clamp(len/T.cap,0,1)
	local vis=f*T.vis
	local hs=rig.hs
	local now=os.clock()
	if len<0.01 then rig.cap.Transparency=1 else
		rig.cap.Transparency=0
		rig.cap.Color=T.rainbow and Color3.fromHSV((now*0.15)%1,0.45,1) or T.color
		rig.cap.Reflectance=T.shine
		local g=1.03+0.07*math.min(f*4,1)
		rig.mesh.Scale=Vector3.new(hs.X*g,hs.Y*0.8*g,hs.Z*g)
	end
	local w=0.1+0.2*math.min(f*3,1)
	for _,lk in ipairs(rig.locks) do
		local L=vis*lk.lm
		if L<0.06 then
			for _,s in ipairs(lk.segs) do s.part.Transparency=1 end
		else
			local segLen=L/SEG
			local droop=math.clamp(L/0.5,0,1)
			local pos=lk.root
			local col=lockColor(T,lk,now)
			for k,s in ipairs(lk.segs) do
				local t=math.clamp((0.4+0.3*(k-1))*droop,0,1)
				local dir=lk.dir:Lerp(lk.fall,t)
				if T.curl then dir+=lk.side*math.sin(k*2.3+lk.phase)*0.7*droop end
				dir=dir.Unit
				local c=pos+dir*segLen/2
				local up=lk.dir
				if math.abs(dir:Dot(up))>0.97 then up=math.abs(dir.Y)>0.9 and Vector3.xAxis or Vector3.yAxis end
				s.weld.C0=CFrame.lookAt(c,c+dir,up)
				local ww=w*(1-0.17*(k-1))
				s.part.Size=Vector3.new(ww,ww*0.55,segLen+ww*0.5)
				s.part.Color=col s.part.Reflectance=T.shine s.part.Transparency=0
				pos+=dir*segLen
			end
		end
	end
end

local function recolor(rig,T)
	local now=os.clock()
	rig.cap.Color=Color3.fromHSV((now*0.15)%1,0.45,1)
	for _,lk in ipairs(rig.locks) do
		local col=lockColor(T,lk,now)
		for _,s in ipairs(lk.segs) do s.part.Color=col end
	end
end

local function hook(plr)
	plr.CharacterAdded:Connect(function(c) buildRig(plr,c) end)
	if plr.Character then task.spawn(buildRig,plr,plr.Character) end
end
for _,p in ipairs(Players:GetPlayers()) do hook(p) end
Players.PlayerAdded:Connect(hook)

RunS.Heartbeat:Connect(function(dt)
	for char,rig in pairs(rigs) do
		if not char.Parent then rigs[char]=nil continue end
		local plr=rig.player
		local ti=plr:GetAttribute("HairType") or 1
		local T=C.Types[ti] or C.Types[1]
		local target=plr:GetAttribute("HairLen") or 0
		local changed=false
		if rig.typeShown~=ti then rig.typeShown=ti changed=true end
		if rig.shown~=target then
			rig.shown+=(target-rig.shown)*math.min(1,dt*10)
			if math.abs(target-rig.shown)<0.02*T.cap/25 or rig.shown<0 then rig.shown=target end
			changed=true
		end
		if changed then draw(rig,rig.shown,T)
		elseif T.rainbow and rig.shown>0 then recolor(rig,T) end
		local key=ti..":"..math.floor(target)
		if key~=rig.tagKey then
			rig.tagKey=key
			rig.tag.Text=string.format('%s\n<font color="#%s">%s Hair</font> - %d cm',plr.DisplayName,C.RarityColors[T.rarity]:ToHex(),T.name,math.floor(target))
		end
	end
end)

local function clippings(char)
	local rig=rigs[char] if not rig then return end
	for i=1,#rig.locks,3 do
		local p=rig.locks[i].segs[SEG].part
		if p.Transparency<1 then
			local c=p:Clone() c:ClearAllChildren()
			c.Massless=false c.CanCollide=true c.CFrame=p.CFrame c.Parent=workspace
			c.AssemblyLinearVelocity=Vector3.new(math.random(-12,12),math.random(8,16),math.random(-12,12))
			Debris:AddItem(c,2.5)
		end
	end
	rig.shown=0
	draw(rig,0,C.Types[rig.typeShown] or C.Types[1])
end

------------------------------------------------------------------ HUD
local gui=Instance.new("ScreenGui") gui.Name="HairHUD" gui.ResetOnSpawn=false gui.IgnoreGuiInset=true
gui.Parent=player:WaitForChild("PlayerGui")
local function deco(o,radius,col,th)
	local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,radius) c.Parent=o
	if col then local s=Instance.new("UIStroke") s.Color=col s.Thickness=th s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=o end
end
local function label(parent,size,pos,color,stroke)
	local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Size=size t.Position=pos or UDim2.new()
	t.Font=Enum.Font.FredokaOne t.TextScaled=true t.TextColor3=color or WHITE t.Parent=parent
	if stroke then local s=Instance.new("UIStroke") s.Color=stroke s.Thickness=2.5 s.Parent=t end
	return t
end
local function frame(parent,size,pos,anchor,color)
	local f=Instance.new("Frame") f.Size=size f.Position=pos f.AnchorPoint=anchor or Vector2.zero
	f.BackgroundColor3=color or PLUM f.Parent=parent return f
end
local function button(parent,text,size,pos,anchor,color)
	local b=Instance.new("TextButton") b.Size=size b.Position=pos b.AnchorPoint=anchor or Vector2.zero b.BackgroundColor3=color
	b.Font=Enum.Font.FredokaOne b.TextScaled=true b.Text=text b.TextColor3=WHITE b.Parent=parent
	local s=Instance.new("UIStroke") s.Color=PLUM s.Thickness=2 s.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual s.Parent=b
	local pad=Instance.new("UIPadding",b) pad.PaddingTop=UDim.new(0.18,0) pad.PaddingBottom=UDim.new(0.18,0) pad.PaddingLeft=UDim.new(0,8) pad.PaddingRight=UDim.new(0,8)
	return b
end

-- Cash
local cashF=frame(gui,UDim2.fromOffset(230,64),UDim2.new(0,18,1,-18),Vector2.new(0,1),PLUM)
deco(cashF,20,GOLD,3)
local coin=frame(cashF,UDim2.fromOffset(40,40),UDim2.new(0,12,0.5,0),Vector2.new(0,0.5),GOLD) deco(coin,20,Color3.fromRGB(255,240,180),2)
label(coin,UDim2.fromScale(1,1),nil,PLUM).Text="$"
local cashL=label(cashF,UDim2.new(1,-74,1,-16),UDim2.fromOffset(62,8),GREEN,PLUM)
cashL.TextXAlignment=Enum.TextXAlignment.Left

-- Hair panel
local typeL=label(gui,UDim2.fromOffset(420,30),UDim2.new(0.5,0,1,-122),WHITE,PLUM)
typeL.AnchorPoint=Vector2.new(0.5,1) typeL.RichText=true
local bar=frame(gui,UDim2.fromOffset(400,38),UDim2.new(0.5,0,1,-80),Vector2.new(0.5,1),PLUM)
bar.ClipsDescendants=true deco(bar,19,WHITE,3)
local fill=frame(bar,UDim2.fromScale(0,1),UDim2.new(),nil,WHITE) fill.BorderSizePixel=0 deco(fill,19)
local g2=Instance.new("UIGradient",fill) g2.Color=ColorSequence.new(Color3.fromRGB(255,150,200),GOLD)
local barL=label(bar,UDim2.new(1,-20,1,-10),UDim2.fromOffset(10,5),WHITE,PLUM) barL.ZIndex=2
local status=label(gui,UDim2.fromOffset(520,40),UDim2.new(0.5,0,1,-28),WHITE,PLUM) status.AnchorPoint=Vector2.new(0.5,1)
local stScale=Instance.new("UIScale",status)

-- Side buttons
local shopBtn=button(gui,"HAIR TYPES",UDim2.fromOffset(160,54),UDim2.new(0,18,0.5,0),Vector2.new(0,0.5),Color3.fromRGB(90,205,170))
deco(shopBtn,16,WHITE,3)
local mBtn=button(gui,"MUSIC: ON",UDim2.fromOffset(130,38),UDim2.new(1,-18,0,70),Vector2.new(1,0),PLUM)
deco(mBtn,12,GOLD,2)
mBtn.Activated:Connect(function()
	if music.Playing then music:Pause() mBtn.Text="MUSIC: OFF" else music:Resume() mBtn.Text="MUSIC: ON" end
end)

-- Shop window
local shop=frame(gui,UDim2.fromOffset(580,450),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5),Color3.fromRGB(255,244,236))
shop.Visible=false deco(shop,24,PLUM,4)
local shopScale=Instance.new("UIScale",shop)
local title=label(shop,UDim2.new(1,-120,0,46),UDim2.fromOffset(24,14),PINK,PLUM) title.Text="HAIR TYPES" title.TextXAlignment=Enum.TextXAlignment.Left
local sub=label(shop,UDim2.new(1,-48,0,22),UDim2.fromOffset(24,62),Color3.fromRGB(110,90,120)) sub.Text="Better hair = more cash per cm + more hair you can carry"
sub.TextXAlignment=Enum.TextXAlignment.Left
local close=button(shop,"X",UDim2.fromOffset(46,46),UDim2.new(1,-14,0,14),Vector2.new(1,0),Color3.fromRGB(240,90,110)) deco(close,23,WHITE,3)
local list=Instance.new("ScrollingFrame") list.Size=UDim2.new(1,-36,1,-112) list.Position=UDim2.fromOffset(18,96)
list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=8 list.ScrollBarImageColor3=PLUM
list.AutomaticCanvasSize=Enum.AutomaticSize.Y list.CanvasSize=UDim2.new() list.Parent=shop
local lay=Instance.new("UIListLayout",list) lay.Padding=UDim.new(0,8) lay.SortOrder=Enum.SortOrder.LayoutOrder
local rows={}
for i,T in ipairs(C.Types) do
	local r=frame(list,UDim2.new(1,-16,0,74),UDim2.new(),nil,WHITE) r.LayoutOrder=i
	deco(r,16,C.RarityColors[T.rarity],3)
	local sw=frame(r,UDim2.fromOffset(52,52),UDim2.new(0,12,0.5,0),Vector2.new(0,0.5),T.color) deco(sw,26,PLUM,2)
	if T.rainbow then
		sw.BackgroundColor3=WHITE
		local g=Instance.new("UIGradient",sw)
		g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,0.6,1)),ColorSequenceKeypoint.new(0.33,Color3.fromHSV(0.33,0.6,1)),ColorSequenceKeypoint.new(0.66,Color3.fromHSV(0.66,0.6,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(0.9,0.6,1))})
	end
	local nm=label(r,UDim2.new(1,-230,0,30),UDim2.fromOffset(76,8),PLUM) nm.TextXAlignment=Enum.TextXAlignment.Left nm.RichText=true
	nm.Text=string.format('%s Hair  <font color="#%s">%s</font>',T.name,C.RarityColors[T.rarity]:ToHex(),T.rarity:upper())
	local st=label(r,UDim2.new(1,-230,0,22),UDim2.fromOffset(76,42),Color3.fromRGB(110,90,120)) st.TextXAlignment=Enum.TextXAlignment.Left
	st.Text=string.format("x%s cash   |   holds %s cm",tostring(T.mult),C.Format(T.cap))
	local b=button(r,"",UDim2.fromOffset(136,48),UDim2.new(1,-12,0.5,0),Vector2.new(1,0.5),PINK) deco(b,14,PLUM,2)
	b.Activated:Connect(function() Shop:FireServer("type",i) end)
	rows[i]=b
end

local ls=player:WaitForChild("leaderstats")
local cash=ls:WaitForChild("Cash")

local function refreshShop()
	local cur=player:GetAttribute("HairType") or 1
	for i,T in ipairs(C.Types) do
		local b=rows[i]
		if i==cur then b.Text="EQUIPPED" b.BackgroundColor3=PINK b.AutoButtonColor=false
		elseif i<cur then b.Text="OWNED" b.BackgroundColor3=Color3.fromRGB(185,175,195) b.AutoButtonColor=false
		else b.Text="$"..C.Format(T.price) b.AutoButtonColor=true
			b.BackgroundColor3=cash.Value>=T.price and Color3.fromRGB(80,200,115) or Color3.fromRGB(225,95,105)
		end
	end
end
local function openShop()
	refreshShop()
	shop.Visible=true shopScale.Scale=0.6
	TS:Create(shopScale,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Scale=1}):Play()
end
shopBtn.Activated:Connect(function() if shop.Visible then shop.Visible=false else openShop() end end)
close.Activated:Connect(function() shop.Visible=false end)
PPS.PromptTriggered:Connect(function(pr) if pr.Name=="MarketPrompt" then openShop() end end)

-- Stats display
local shown=Instance.new("NumberValue") shown.Value=cash.Value
shown.Changed:Connect(function(v) cashL.Text=C.Format(v) end)
cashL.Text=C.Format(cash.Value)
cash.Changed:Connect(function(v)
	TS:Create(shown,TweenInfo.new(0.8,Enum.EasingStyle.Quad),{Value=v}):Play()
	cashF.Size=UDim2.fromOffset(250,70)
	TS:Create(cashF,TweenInfo.new(0.3,Enum.EasingStyle.Back),{Size=UDim2.fromOffset(230,64)}):Play()
	if shop.Visible then refreshShop() end
end)

local full=false
local function refresh()
	local ti=player:GetAttribute("HairType") or 1
	local T=C.Types[ti] or C.Types[1]
	local len=player:GetAttribute("HairLen") or 0
	local f=math.clamp(len/T.cap,0,1)
	TS:Create(fill,TweenInfo.new(0.3),{Size=UDim2.fromScale(f,1)}):Play()
	barL.Text=string.format("%d / %s cm   |   $%s",math.floor(len),C.Format(T.cap),C.Format(C.Value(len,ti)))
	typeL.Text=string.format('<font color="#%s">%s HAIR</font>   x%s cash',C.RarityColors[T.rarity]:ToHex(),T.name:upper(),tostring(T.mult))
	full=len>=T.cap
	if full then status.Text="HAIR FULL!  Go to the BARBERSHOP" status.TextColor3=PINK
	elseif len>0 then status.Text="Keep collecting, or sell at the Barbershop" status.TextColor3=WHITE
	else status.Text="Walk into the HAIR FARMS to collect hair!" status.TextColor3=WHITE end
	if shop.Visible then refreshShop() end
end
player:GetAttributeChangedSignal("HairLen"):Connect(refresh)
player:GetAttributeChangedSignal("HairType"):Connect(refresh)
refresh()

task.spawn(function()
	while true do
		if full then
			TS:Create(stScale,TweenInfo.new(0.35,Enum.EasingStyle.Sine),{Scale=1.12}):Play() task.wait(0.35)
			TS:Create(stScale,TweenInfo.new(0.35,Enum.EasingStyle.Sine),{Scale=1}):Play() task.wait(0.35)
		else task.wait(0.2) end
	end
end)

-- Popups
local function popup(text,color,y,size)
	local t=label(gui,size or UDim2.fromOffset(560,60),UDim2.fromScale(0.5,y or 0.42),color,PLUM)
	t.AnchorPoint=Vector2.new(0.5,0.5) t.Text=text
	local sc=Instance.new("UIScale",t) sc.Scale=0.4
	TS:Create(sc,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Scale=1}):Play()
	local info=TweenInfo.new(1.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,0.4)
	TS:Create(t,info,{Position=UDim2.fromScale(0.5,(y or 0.42)-0.08),TextTransparency=1}):Play()
	TS:Create(t:FindFirstChildOfClass("UIStroke"),info,{Transparency=1}):Play()
	task.delay(1.7,function() t:Destroy() end)
end
Notify.OnClientEvent:Connect(function(text,color) popup(text,color or WHITE) end)

-- Camera shake
local shakeUntil=0
RunS:BindToRenderStep("HairShake",Enum.RenderPriority.Camera.Value+1,function()
	if os.clock()<shakeUntil then
		local k=(shakeUntil-os.clock())*0.25
		camera.CFrame=camera.CFrame*CFrame.Angles(math.rad(math.random(-10,10)*k),math.rad(math.random(-10,10)*k),0)
	end
end)

local function coinBurst(n)
	local from=status.AbsolutePosition+status.AbsoluteSize/2
	local to=cashF.AbsolutePosition+Vector2.new(32,32)
	for i=1,n do
		local c=frame(gui,UDim2.fromOffset(26,26),UDim2.fromOffset(from.X,from.Y),Vector2.new(0.5,0.5),GOLD)
		deco(c,13,Color3.fromRGB(255,240,180),2)
		local mid=UDim2.fromOffset(from.X+math.random(-160,160),from.Y-math.random(80,200))
		task.delay(i*0.03,function()
			local t1=TS:Create(c,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=mid})
			t1:Play() t1.Completed:Wait()
			local t2=TS:Create(c,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.fromOffset(to.X,to.Y),Size=UDim2.fromOffset(12,12)})
			t2:Play() t2.Completed:Wait() c:Destroy()
		end)
	end
end

local function headPop(char,amount)
	local head=char and char:FindFirstChild("Head") if not head then return end
	local bb=Instance.new("BillboardGui") bb.Adornee=head bb.Size=UDim2.fromOffset(200,60) bb.StudsOffset=Vector3.new(0,4,0) bb.AlwaysOnTop=true bb.Parent=gui
	local t=label(bb,UDim2.fromScale(1,1),nil,GREEN,PLUM) t.Text="+$"..C.Format(amount)
	TS:Create(bb,TweenInfo.new(1.5,Enum.EasingStyle.Quad),{StudsOffset=Vector3.new(0,8,0)}):Play()
	TS:Create(t,TweenInfo.new(1.5,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1}):Play()
	task.delay(1.6,function() bb:Destroy() end)
end

local function flyBall(pos,color)
	local char=player.Character local head=char and char:FindFirstChild("Head") if not head then return end
	local b=Instance.new("Part") b.Shape=Enum.PartType.Ball b.Size=Vector3.new(0.9,0.9,0.9) b.Anchored=true
	b.CanCollide=false b.CanQuery=false b.CanTouch=false b.Material=Enum.Material.Neon b.Color=color b.Position=pos b.Parent=workspace
	local start=os.clock()
	local conn
	conn=RunS.RenderStepped:Connect(function()
		local a=math.min(1,(os.clock()-start)/0.3)
		if not head.Parent then a=1 end
		b.Position=pos:Lerp(head.Position,a)+Vector3.new(0,math.sin(a*math.pi)*3,0)
		b.Size=Vector3.one*0.9*(1-a*0.7)
		if a>=1 then conn:Disconnect() b:Destroy() end
	end)
end

FX.OnClientEvent:Connect(function(kind,a,b,c)
	if kind=="collect" then
		sPop.PlaybackSpeed=0.9+math.random()*0.35 sPop:Play()
		flyBall(b,c)
		popup("+"..a.." cm",Color3.fromRGB(140,255,210),0.6,UDim2.fromOffset(240,40))
	elseif kind=="cut" then
		clippings(a)
		headPop(a,b)
		if c==player then
			sCoin:Play()
			shakeUntil=os.clock()+0.25
			coinBurst(math.clamp(math.floor(b/5),6,16))
			popup("HAIRCUT!  +$"..C.Format(b),GREEN,0.36)
		end
	elseif kind=="unlock" then
		sCoin:Play()
		popup("UNLOCKED "..C.Zones[a].name:upper().."!",GOLD,0.36)
	elseif kind=="typeBought" then
		sCoin:Play()
		popup("NEW HAIR: "..C.Types[a].name:upper().."!",C.RarityColors[C.Types[a].rarity],0.36)
	end
end)

------------------------------------------------------------------ Gates + guide beam
local beam=Instance.new("Beam") beam.Color=ColorSequence.new(PINK) beam.Width0=0.7 beam.Width1=0.7 beam.FaceCamera=true
beam.LightEmission=0.6 beam.Transparency=NumberSequence.new(0.25) beam.Segments=1 beam.Enabled=false beam.Parent=workspace.Terrain
local a0=Instance.new("Attachment")
local function attachA0(char)
	local hrp=char:WaitForChild("HumanoidRootPart",10)
	if hrp then a0.Parent=hrp a0.Position=Vector3.new(0,-1.5,0) beam.Attachment0=a0 end
end
player.CharacterAdded:Connect(attachA0)
if player.Character then task.spawn(attachA0,player.Character) end

task.spawn(function()
	while true do
		local z=player:GetAttribute("Zone") or 1
		for _,g in ipairs(CS:GetTagged("ZoneGate")) do
			local open=(g:GetAttribute("Zone") or 99)<=z
			g.CanCollide=not open g.Transparency=open and 1 or 0
			for _,sg in ipairs(g:GetChildren()) do if sg:IsA("SurfaceGui") then sg.Enabled=not open end end
		end
		for _,k in ipairs(CS:GetTagged("ZoneKiosk")) do
			local open=(k:GetAttribute("Zone") or 99)<=z
			local pr=k:FindFirstChildWhichIsA("ProximityPrompt",true) if pr then pr.Enabled=not open end
			for _,d in ipairs(k:GetDescendants()) do if d:IsA("SurfaceGui") then d.Enabled=not open end end
			k.Transparency=open and 1 or 0
		end
		local ti=player:GetAttribute("HairType") or 1
		local len=player:GetAttribute("HairLen") or 0
		local target
		local city=workspace:FindFirstChild("HairCity")
		local farms=workspace:FindFirstChild("HairFarms")
		if len>=C.Types[ti].cap and city and city:FindFirstChild("HaircutZone") then target=city.HaircutZone:FindFirstChild("Guide")
		elseif len==0 and cash.Value==0 and farms and farms:FindFirstChild("FarmGuide") then target=farms.FarmGuide:FindFirstChild("Guide") end
		beam.Attachment1=target
		beam.Enabled=target~=nil and a0.Parent~=nil
		task.wait(0.3)
	end
end)

------------------------------------------------------------------ World animation
local poleCols={Color3.fromRGB(235,60,80),WHITE,Color3.fromRGB(70,120,235),WHITE}
local poleT,poleK=0,0
RunS.RenderStepped:Connect(function(dt)
	local t=os.clock()
	for _,m in ipairs(CS:GetTagged("Spin")) do
		local bp=m:GetAttribute("BasePivot")
		if bp then m:PivotTo(bp*CFrame.Angles(0,t*0.35,0)) end
	end
	poleT+=dt
	if poleT>0.12 then
		poleT=0 poleK+=1
		local city=workspace:FindFirstChild("HairCity")
		if city then
			for _,pole in ipairs(city:GetChildren()) do
				if pole.Name=="BarberPole" then
					local i=0
					for _,s in ipairs(pole:GetChildren()) do
						if s.Name=="Stripe" then i+=1 s.Color=poleCols[(i+poleK)%4+1] end
					end
				end
			end
		end
	end
end)
