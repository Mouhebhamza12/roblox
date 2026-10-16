--[[ GROW HAIR! client
	- Soft strand hair (Beams) for every player's head and for hair beds
	- Bed timers, harvest prompts (only on your own beds)
	- HUD, hair-type shop, effects, guide line
]]
local Players=game:GetService("Players")
local TS=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local RunS=game:GetService("RunService")
local CS=game:GetService("CollectionService")
local PPS=game:GetService("ProximityPromptService")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local C=require(RS:WaitForChild("HairConfig"))
local R=RS:WaitForChild("HairRemotes")
local Notify,FX,Shop,Action=R:WaitForChild("Notify"),R:WaitForChild("FX"),R:WaitForChild("Shop"),R:WaitForChild("Action")
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

-- Escape text before putting it inside RichText (display names can contain < > &)
local function esc(s)
	s=s:gsub("&","&amp;") s=s:gsub("<","&lt;") s=s:gsub(">","&gt;") s=s:gsub('"',"&quot;") s=s:gsub("'","&apos;")
	return s
end

-- CFrame whose X axis (the axis Beams curve along) points along `dir`
local function axisCF(pos,dir)
	local up=math.abs(dir.Y)<0.95 and Vector3.yAxis or Vector3.xAxis
	local z=dir:Cross(up).Unit
	local y=z:Cross(dir).Unit
	return CFrame.fromMatrix(pos,dir,y,z)
end

local function newBeam(a0,a1,parent)
	local b=Instance.new("Beam")
	b.Attachment0=a0 b.Attachment1=a1 b.FaceCamera=true b.Segments=8
	b.LightInfluence=1 b.LightEmission=0 b.Transparency=NumberSequence.new(0) b.Enabled=false
	b.Parent=parent
	return b
end

local function hairColors(base,shade)
	local c=shade>0 and base:Lerp(Color3.new(1,0.95,0.85),shade) or base:Lerp(Color3.new(0,0,0),-shade)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0,c:Lerp(Color3.new(0,0,0),0.25)),
		ColorSequenceKeypoint.new(0.6,c),
		ColorSequenceKeypoint.new(1,c:Lerp(Color3.new(1,1,1),0.18)),
	})
end
local function typeColor(T,hue,t)
	if T.rainbow then return Color3.fromHSV((hue+t*0.12)%1,0.55,1) end
	return T.color
end

------------------------------------------------------------------ HEAD HAIR
local DIRS={}
do
	local N,g,cand=600,math.pi*(3-math.sqrt(5)),{}
	for i=0,N-1 do
		local y=1-2*(i+0.5)/N
		local r=math.sqrt(1-y*y)
		local x,z=math.cos(i*g)*r,math.sin(i*g)*r
		if (z<-0.25 and y>0.5) or (z>=-0.25 and z<0.25 and y>0.1) or (z>=0.25 and y>-0.3) then table.insert(cand,Vector3.new(x,y,z)) end
	end
	local step=math.max(1,math.floor(#cand/C.HeadStrands))
	for i=1,#cand,step do table.insert(DIRS,cand[i]) end
end

local rigs={}

local function buildRig(plr,char)
	local head=char:WaitForChild("Head",10)
	if not head or not char.Parent then return end
	local old=head:FindFirstChild("HairVisual") if old then old:Destroy() end
	local folder=Instance.new("Folder") folder.Name="HairVisual"
	local hs=head.Size
	-- solid cap so the scalp never shows through
	local cap=Instance.new("Part") cap.Name="Cap" cap.Size=Vector3.one cap.CanCollide=false cap.CanQuery=false cap.CanTouch=false
	cap.Massless=true cap.CastShadow=false cap.Material=Enum.Material.SmoothPlastic cap.Transparency=1
	local mesh=Instance.new("SpecialMesh") mesh.MeshType=Enum.MeshType.Sphere mesh.Parent=cap
	local w=Instance.new("Weld") w.Part0=head w.Part1=cap w.C0=CFrame.new(0,hs.Y*0.17,hs.Z*0.1) w.Parent=cap
	cap.Parent=folder
	local rng=Random.new(plr.UserId)
	local locks={}
	for i,d in ipairs(DIRS) do
		local out=(d.Z<0) and (d+Vector3.new(0,0.4,-d.Z*1.8)).Unit or d
		local side=d:Cross(Vector3.yAxis) side=side.Magnitude>0.01 and side.Unit or Vector3.xAxis
		local fall=Vector3.new(d.X*0.2+rng:NextNumber(-0.08,0.08),-1,math.max(d.Z,0)*0.2+(d.Z<0 and 0.85 or 0.45)+rng:NextNumber(-0.08,0.08)).Unit
		local a0=Instance.new("Attachment") a0.Name="H" a0.Parent=head
		local a1=Instance.new("Attachment") a1.Name="H" a1.Parent=head
		local a2=Instance.new("Attachment") a2.Name="H" a2.Parent=head
		locks[i]={root=d*hs/2*0.95,out=out,fall=fall,side=side,lm=rng:NextNumber(0.8,1.15),shade=rng:NextNumber(-0.12,0.12),
			phase=rng:NextNumber(0,6.28),hue=i/#DIRS,a={a0,a1,a2},b1=newBeam(a0,a1,folder),b2=newBeam(a1,a2,folder)}
	end
	local bb=Instance.new("BillboardGui") bb.Name="HairTag" bb.Size=UDim2.fromOffset(240,50) bb.StudsOffset=Vector3.new(0,2.8,0) bb.MaxDistance=60 bb.Adornee=head bb.Parent=folder
	local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Font=Enum.Font.FredokaOne t.TextScaled=true t.RichText=true
	t.TextColor3=WHITE t.TextStrokeColor3=PLUM t.TextStrokeTransparency=0 t.Parent=bb
	folder.Parent=head
	-- clean up attachments with the head
	local atts={} for _,lk in ipairs(locks) do for _,a in ipairs(lk.a) do table.insert(atts,a) end end
	folder.Destroying:Connect(function() for _,a in ipairs(atts) do a:Destroy() end end)
	rigs[char]={player=plr,char=char,head=head,folder=folder,cap=cap,mesh=mesh,hs=hs,locks=locks,shown=-1,typeShown=0,tag=t,tagKey="",lastSway=0,lastColor=0}
end

local function setRigColors(rig,T,t)
	local cap=typeColor(T,0,t)
	rig.cap.Color=cap rig.cap.Reflectance=T.shine
	for _,lk in ipairs(rig.locks) do
		local cs=hairColors(typeColor(T,lk.hue,t),lk.shade)
		lk.b1.Color=cs lk.b2.Color=cs
		lk.b1.LightEmission=T.shine*0.6 lk.b2.LightEmission=T.shine*0.6
	end
end

local function drawRig(rig,len,T,t)
	local f=math.clamp(len/T.cap,0,1)
	local vis=f*T.vis
	local hs=rig.hs
	if len<0.01 then rig.cap.Transparency=1 else
		rig.cap.Transparency=0
		local g=1.03+0.06*math.min(f*4,1)
		rig.mesh.Scale=Vector3.new(hs.X*g,hs.Y*0.8*g,hs.Z*g)
	end
	local w=0.16+0.12*math.min(f*3,1)
	for _,lk in ipairs(rig.locks) do
		local L=vis*lk.lm
		if L<0.05 then
			lk.b1.Enabled=false lk.b2.Enabled=false
		else
			local root=lk.root
			local mid=root+lk.out*(0.22*L)+lk.fall*(0.42*L)
			local tip=root+lk.out*(0.25*L)+lk.fall*L
			if T.curl then mid+=lk.side*0.22*L tip-=lk.side*0.15*L end
			tip+=lk.side*math.sin(t*1.6+lk.phase)*0.05*L
			lk.a[1].CFrame=axisCF(root,lk.out)
			lk.a[2].CFrame=axisCF(mid,(tip-root).Unit)
			lk.a[3].CFrame=axisCF(tip,lk.fall)
			lk.b1.CurveSize0=0.25*L lk.b1.CurveSize1=0.2*L
			lk.b2.CurveSize0=0.2*L lk.b2.CurveSize1=0.15*L
			lk.b1.Width0=w lk.b1.Width1=w*0.8
			lk.b2.Width0=w*0.8 lk.b2.Width1=0.035
			lk.b1.Enabled=true lk.b2.Enabled=true
		end
	end
end

local function hook(plr)
	plr.CharacterAdded:Connect(function(c) buildRig(plr,c) end)
	if plr.Character then task.spawn(buildRig,plr,plr.Character) end
end
for _,p in ipairs(Players:GetPlayers()) do hook(p) end
Players.PlayerAdded:Connect(hook)

RunS.Heartbeat:Connect(function(dt)
	local t=os.clock()
	local camPos=camera.CFrame.Position
	for char,rig in pairs(rigs) do
		if not char.Parent or not rig.head.Parent then rigs[char]=nil continue end
		local plr=rig.player
		local ti=plr:GetAttribute("HairType") or 1
		local T=C.Types[ti] or C.Types[1]
		local target=plr:GetAttribute("HairLen") or 0
		local changed=false
		if rig.typeShown~=ti then rig.typeShown=ti setRigColors(rig,T,t) changed=true end
		if rig.shown~=target then
			rig.shown+=(target-rig.shown)*math.min(1,dt*8)
			if math.abs(target-rig.shown)<0.02*T.cap/25 or rig.shown<0 then rig.shown=target end
			changed=true
		end
		local near=(rig.head.Position-camPos).Magnitude<70
		if near and rig.shown>0 and t-rig.lastSway>1/15 then rig.lastSway=t changed=true end
		if changed then drawRig(rig,rig.shown,T,t) end
		if T.rainbow and rig.shown>0 and t-rig.lastColor>0.2 then rig.lastColor=t setRigColors(rig,T,t) end
		local key=ti..":"..math.floor(target)
		if key~=rig.tagKey then
			rig.tagKey=key
			rig.tag.Text=string.format('%s\n<font color="#%s">%s Hair</font> - %d cm',esc(plr.DisplayName),C.RarityColors[T.rarity]:ToHex(),T.name,math.floor(target))
		end
	end
end)

local function clippings(char)
	local rig=rigs[char] if not rig then return end
	local T=C.Types[rig.typeShown] or C.Types[1]
	for i=1,16 do
		local c=Instance.new("Part") c.Size=Vector3.new(0.08,0.08,math.random(6,14)/10) c.CanCollide=true c.CanQuery=false c.CanTouch=false
		c.Color=typeColor(T,i/16,os.clock()) c.Material=Enum.Material.SmoothPlastic
		c.CFrame=rig.head.CFrame*CFrame.new(math.random(-8,8)/10,0.6,math.random(-8,8)/10)*CFrame.Angles(math.random()*6,math.random()*6,0)
		c.Parent=workspace
		c.AssemblyLinearVelocity=Vector3.new(math.random(-10,10),math.random(6,14),math.random(-10,10))
		Debris:AddItem(c,2.5)
	end
	rig.shown=0
	drawRig(rig,0,T,os.clock())
end

------------------------------------------------------------------ HAIR BEDS
local beds={}
local function serverNow() return workspace:GetServerTimeNow() end

local function bedOwnerType(soil)
	local p=Players:GetPlayerByUserId(soil:GetAttribute("Owner") or 0)
	return C.Types[p and p:GetAttribute("HairType") or 1] or C.Types[1]
end

local function buildBed(soil)
	local rng=Random.new(math.floor(soil.Position.X*7+soil.Position.Z*13))
	local folder=Instance.new("Folder") folder.Name="BedHair"
	local strands={}
	local sx,sz=soil.Size.X-1.2,soil.Size.Z-1.2
	local n=C.BedStrands
	local cols=math.ceil(math.sqrt(n*sx/sz))
	local rows=math.ceil(n/cols)
	for i=0,n-1 do
		local cx,cz=i%cols,math.floor(i/cols)
		local x=-sx/2+(cx+0.5)*sx/cols+rng:NextNumber(-0.3,0.3)
		local z=-sz/2+(cz+0.5)*sz/rows+rng:NextNumber(-0.3,0.3)
		local a0=Instance.new("Attachment") a0.Parent=soil
		local a1=Instance.new("Attachment") a1.Parent=soil
		local ang=rng:NextNumber(0,math.pi*2)
		table.insert(strands,{root=Vector3.new(x,soil.Size.Y/2,z),bend=Vector3.new(math.cos(ang),0,math.sin(ang)),
			lm=rng:NextNumber(0.75,1.15),shade=rng:NextNumber(-0.12,0.12),phase=rng:NextNumber(0,6.28),hue=i/n,a0=a0,a1=a1,beam=newBeam(a0,a1,folder)})
	end
	folder.Parent=soil
	local bed={soil=soil,folder=folder,strands=strands,typeShown=0,lastG=-1}
	-- owner-only UI: progress board + harvest prompt
	if soil:GetAttribute("Owner")==player.UserId then
		local bb=Instance.new("BillboardGui") bb.Size=UDim2.fromOffset(130,34) bb.StudsOffset=Vector3.new(0,6.5,0) bb.MaxDistance=45 bb.AlwaysOnTop=false bb.Parent=folder bb.Adornee=soil
		local back=Instance.new("Frame") back.Size=UDim2.fromScale(1,1) back.BackgroundColor3=PLUM back.Parent=bb
		Instance.new("UICorner",back).CornerRadius=UDim.new(0,10)
		local fill=Instance.new("Frame") fill.Size=UDim2.fromScale(0,1) fill.BackgroundColor3=PINK fill.BorderSizePixel=0 fill.Parent=back
		Instance.new("UICorner",fill).CornerRadius=UDim.new(0,10)
		local txt=Instance.new("TextLabel") txt.Size=UDim2.fromScale(1,1) txt.BackgroundTransparency=1 txt.Font=Enum.Font.FredokaOne txt.TextScaled=true
		txt.TextColor3=WHITE txt.ZIndex=2 txt.Parent=back
		local st=Instance.new("UIStroke",txt) st.Color=PLUM st.Thickness=2
		local pr=Instance.new("ProximityPrompt") pr.ActionText="Harvest Hair" pr.HoldDuration=0.25 pr.MaxActivationDistance=12
		pr.RequiresLineOfSight=false pr.Enabled=false pr.Parent=soil
		pr.Triggered:Connect(function() Action:FireServer("harvest",soil) end)
		bed.fill=fill bed.txt=txt bed.prompt=pr
	end
	beds[soil]=bed
	return bed
end

local function destroyBed(bed)
	for _,s in ipairs(bed.strands) do s.a0:Destroy() s.a1:Destroy() end
	if bed.prompt then bed.prompt:Destroy() end
	bed.folder:Destroy()
	beds[bed.soil]=nil
end

local function drawBed(bed,t)
	local soil=bed.soil
	local start,gt=soil:GetAttribute("GrowStart") or 0,soil:GetAttribute("GrowTime") or C.BedGrowTime
	local g=math.clamp((serverNow()-start)/gt,0,1)
	local T=bedOwnerType(soil)
	local tiNow=table.find(C.Types,T)
	if bed.typeShown~=tiNow or (T.rainbow and t-(bed.lastColor or 0)>0.25) then
		bed.typeShown=tiNow bed.lastColor=t
		for _,s in ipairs(bed.strands) do s.beam.Color=hairColors(typeColor(T,s.hue,t),s.shade) s.beam.LightEmission=T.shine*0.6 end
	end
	local droop=g^1.5
	local downBend
	for _,s in ipairs(bed.strands) do
		local L=C.BedMaxLength*(0.06+0.94*g)*s.lm
		local sway=Vector3.new(math.sin(t*1.7+s.phase),0,math.cos(t*1.3+s.phase))*0.07*L*g
		local tip=s.root+Vector3.yAxis*L*(1-0.45*droop)+s.bend*L*0.55*droop+sway
		downBend=(s.bend+Vector3.new(0,-0.9,0)).Unit
		s.a0.CFrame=axisCF(s.root,Vector3.yAxis)
		s.a1.CFrame=axisCF(tip,Vector3.yAxis:Lerp(downBend,droop).Unit)
		s.beam.CurveSize0=L*0.5 s.beam.CurveSize1=L*0.35*droop
		s.beam.Width0=0.1+0.1*g s.beam.Width1=0.025
		s.beam.Enabled=true
	end
	if bed.fill then
		local ready=g>=1
		bed.fill.Size=UDim2.fromScale(g,1)
		bed.fill.BackgroundColor3=ready and Color3.fromRGB(90,210,120) or PINK
		bed.txt.Text=ready and ("READY! +"..(soil:GetAttribute("Yield") or 0).." cm") or (math.floor(g*100).."%")
		bed.prompt.Enabled=ready
		bed.prompt.ObjectText="+"..(soil:GetAttribute("Yield") or 0).." cm"
	end
end

-- Build strands only for nearby beds; update ~12 times a second
local lastBedTick=0
RunS.Heartbeat:Connect(function()
	local t=os.clock()
	if t-lastBedTick<1/12 then return end
	lastBedTick=t
	local camPos=camera.CFrame.Position
	for _,soil in ipairs(CS:GetTagged("HairBed")) do
		local d=(soil.Position-camPos).Magnitude
		local bed=beds[soil]
		if d<160 then
			bed=bed or buildBed(soil)
			drawBed(bed,t)
		elseif bed and d>190 then
			destroyBed(bed)
		end
	end
	for soil,bed in pairs(beds) do if not soil.Parent then destroyBed(bed) end end
end)

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

local cashF=frame(gui,UDim2.fromOffset(230,64),UDim2.new(0,18,1,-18),Vector2.new(0,1),PLUM)
deco(cashF,20,GOLD,3)
local coin=frame(cashF,UDim2.fromOffset(40,40),UDim2.new(0,12,0.5,0),Vector2.new(0,0.5),GOLD) deco(coin,20,Color3.fromRGB(255,240,180),2)
label(coin,UDim2.fromScale(1,1),nil,PLUM).Text="$"
local cashL=label(cashF,UDim2.new(1,-74,1,-16),UDim2.fromOffset(62,8),GREEN,PLUM)
cashL.TextXAlignment=Enum.TextXAlignment.Left

local typeL=label(gui,UDim2.fromOffset(420,30),UDim2.new(0.5,0,1,-122),WHITE,PLUM)
typeL.AnchorPoint=Vector2.new(0.5,1) typeL.RichText=true
local bar=frame(gui,UDim2.fromOffset(400,38),UDim2.new(0.5,0,1,-80),Vector2.new(0.5,1),PLUM)
bar.ClipsDescendants=true deco(bar,19,WHITE,3)
local fill=frame(bar,UDim2.fromScale(0,1),UDim2.new(),nil,WHITE) fill.BorderSizePixel=0 deco(fill,19)
local g2=Instance.new("UIGradient",fill) g2.Color=ColorSequence.new(Color3.fromRGB(255,150,200),GOLD)
local barL=label(bar,UDim2.new(1,-20,1,-10),UDim2.fromOffset(10,5),WHITE,PLUM) barL.ZIndex=2
local status=label(gui,UDim2.fromOffset(520,40),UDim2.new(0.5,0,1,-28),WHITE,PLUM) status.AnchorPoint=Vector2.new(0.5,1)
local stScale=Instance.new("UIScale",status)

local shopBtn=button(gui,"HAIR TYPES",UDim2.fromOffset(160,54),UDim2.new(0,18,0.5,0),Vector2.new(0,0.5),Color3.fromRGB(90,205,170))
deco(shopBtn,16,WHITE,3)
local homeBtn=button(gui,"MY PLOT",UDim2.fromOffset(160,54),UDim2.new(0,18,0.5,64),Vector2.new(0,0.5),PINK)
deco(homeBtn,16,WHITE,3)
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
	if full then status.Text="HAIR FULL!  Sell it at the BARBERSHOP" status.TextColor3=PINK
	elseif len>0 then status.Text="Harvest more, or sell at the Barbershop" status.TextColor3=WHITE
	else status.Text="Harvest your HAIR BEDS when they're ready!" status.TextColor3=WHITE end
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
	local bb=Instance.new("BillboardGui") bb.Adornee=head bb.Size=UDim2.fromOffset(200,60) bb.StudsOffset=Vector3.new(0,4,0) bb.MaxDistance=60 bb.Parent=gui
	local t=label(bb,UDim2.fromScale(1,1),nil,GREEN,PLUM) t.Text="+$"..C.Format(amount)
	TS:Create(bb,TweenInfo.new(1.5,Enum.EasingStyle.Quad),{StudsOffset=Vector3.new(0,8,0)}):Play()
	TS:Create(t,TweenInfo.new(1.5,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1}):Play()
	task.delay(1.6,function() bb:Destroy() end)
end

local function ball(color,size)
	local b=Instance.new("Part") b.Shape=Enum.PartType.Ball b.Size=Vector3.one*size b.Anchored=true
	b.CanCollide=false b.CanQuery=false b.CanTouch=false b.Material=Enum.Material.Fabric b.Color=color b.Parent=workspace
	return b
end

local function flyBall(pos,color)
	local char=player.Character local head=char and char:FindFirstChild("Head") if not head then return end
	local b=ball(color,0.9) b.Position=pos
	local start=os.clock()
	local conn
	conn=RunS.RenderStepped:Connect(function()
		local a=math.min(1,(os.clock()-start)/0.35)
		if not head.Parent then a=1 end
		b.Position=pos:Lerp(head.Position,a)+Vector3.new(0,math.sin(a*math.pi)*3,0)
		b.Size=Vector3.one*0.9*(1-a*0.7)
		if a>=1 then conn:Disconnect() b:Destroy() end
	end)
end

-- Auto-Clipper: a hair ball travels bed -> clipper -> conveyor -> press
local function autoBall(soil,auto)
	if not (soil and soil.Parent and auto and auto.Parent) then return end
	if (soil.Position-camera.CFrame.Position).Magnitude>200 then return end
	local cs,ce,press=auto:FindFirstChild("ConvStart"),auto:FindFirstChild("ConvEnd"),auto:FindFirstChild("Press")
	if not (cs and ce and press) then return end
	local T=bedOwnerType(soil)
	local b=ball(typeColor(T,math.random(),os.clock()),1.1)
	b.Position=soil.Position+Vector3.new(0,1.5,0)
	local steps={{cs.Position+Vector3.new(0,0.4,0),0.8},{ce.Position+Vector3.new(0,0.4,0),2.2},{press.Position,0.4}}
	task.spawn(function()
		for _,s in ipairs(steps) do
			local tw=TS:Create(b,TweenInfo.new(s[2],Enum.EasingStyle.Linear),{Position=s[1]})
			tw:Play() tw.Completed:Wait()
		end
		b:Destroy()
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
	elseif kind=="auto" then
		autoBall(a,b)
	elseif kind=="collectCash" then
		sCoin:Play()
		coinBurst(math.clamp(math.floor(a/5),6,16))
		popup("+$"..C.Format(a),GREEN,0.36)
	elseif kind=="bought" then
		sCoin:Play()
		popup("BUILT: "..string.upper(a).."!",GOLD,0.36)
	elseif kind=="typeBought" then
		sCoin:Play()
		popup("NEW HAIR: "..C.Types[a].name:upper().."!",C.RarityColors[C.Types[a].rarity],0.36)
	end
end)

------------------------------------------------------------------ GUIDE LINE + MY PLOT BUTTON
local beam=Instance.new("Beam") beam.Color=ColorSequence.new(PINK) beam.Width0=0.7 beam.Width1=0.7 beam.FaceCamera=true
beam.LightEmission=0.6 beam.Transparency=NumberSequence.new(0.25) beam.Segments=1 beam.Enabled=false beam.Parent=workspace.Terrain
local a0=Instance.new("Attachment")
local function attachA0(char)
	local hrp=char:WaitForChild("HumanoidRootPart",10)
	if hrp then a0.Parent=hrp a0.Position=Vector3.new(0,-1.5,0) beam.Attachment0=a0 end
end
player.CharacterAdded:Connect(attachA0)
if player.Character then task.spawn(attachA0,player.Character) end

local function myPlotGuide()
	local name=player:GetAttribute("Plot")
	local plots=workspace:FindFirstChild("Plots")
	local plot=name and plots and plots:FindFirstChild(name)
	return plot and plot.Base:FindFirstChild("Guide")
end
local showHomeUntil=0
homeBtn.Activated:Connect(function() showHomeUntil=os.clock()+12 end)

task.spawn(function()
	while true do
		local ti=player:GetAttribute("HairType") or 1
		local len=player:GetAttribute("HairLen") or 0
		local target
		local city=workspace:FindFirstChild("HairCity")
		local home=myPlotGuide()
		local hrp=a0.Parent
		if len>=C.Types[ti].cap and city and city:FindFirstChild("HaircutZone") then
			target=city.HaircutZone:FindFirstChild("Guide")
		elseif home and hrp and (os.clock()<showHomeUntil or (len==0 and (hrp.Position-home.WorldPosition).Magnitude>90)) then
			target=home
		end
		beam.Attachment1=target
		beam.Enabled=target~=nil and a0.Parent~=nil
		task.wait(0.3)
	end
end)

------------------------------------------------------------------ WORLD ANIMATION
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
