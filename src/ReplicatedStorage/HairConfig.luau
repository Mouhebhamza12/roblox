-- GROW HAIR! settings. Shared by server and client.
local C={
	StartCash=0,
	WalkSpeed=24,
	SellCooldown=1.5,
	AutosaveInterval=60,
	SoundCoin="5314631765", SoundPop="133119114309377", Music="100333487341753",

	-- Head hair (drawn with soft curved strands)
	HeadStrands=110,

	-- Tycoon plots
	PlotCount=8,
	PlotRadius=165,         -- distance of each plot from the city centre
	PlotSize=64,

	-- Hair beds
	BedGrowTime=20,         -- seconds for a bed to fully grow
	BedYield=5,             -- cm of hair from one full bed
	BedStrands=36,          -- strands drawn per bed
	BedMaxLength=4.5,       -- studs, fully grown
	AutoRate=0.5,           -- cash per cm (x hair-type multiplier) from the Auto-Clipper
	AutoDelay=5,            -- Auto-Clipper waits this long after a bed is ready (gives you time to harvest yourself)
	HarvestRange=16,

	RarityColors={
		Common=Color3.fromRGB(190,190,190), Uncommon=Color3.fromRGB(110,220,110), Rare=Color3.fromRGB(80,165,255),
		Epic=Color3.fromRGB(185,100,255), Legendary=Color3.fromRGB(255,195,50), Mythical=Color3.fromRGB(255,100,185),
	},
	-- Hair types: mult = cash per cm, cap = max hair you can carry (cm), vis = max head-hair length (studs)
	Types={
		{name="Patchy",  rarity="Common",    mult=1,   cap=25,   price=0,      color=Color3.fromRGB(150,130,110), vis=2.2, shine=0},
		{name="Straight",rarity="Uncommon",  mult=1.5, cap=50,   price=100,    color=Color3.fromRGB(105,65,35),   vis=2.8, shine=0},
		{name="Wavy",    rarity="Rare",      mult=2.5, cap=100,  price=600,    color=Color3.fromRGB(225,175,95),  vis=3.4, shine=0.05, curl=true},
		{name="Curly",   rarity="Epic",      mult=4,   cap=200,  price=3000,   color=Color3.fromRGB(205,85,40),   vis=4.0, shine=0.05, curl=true},
		{name="Silky",   rarity="Epic",      mult=7,   cap=400,  price=15000,  color=Color3.fromRGB(35,30,45),    vis=4.8, shine=0.25},
		{name="Golden",  rarity="Legendary", mult=12,  cap=800,  price=75000,  color=Color3.fromRGB(255,200,60),  vis=5.4, shine=0.3},
		{name="Rainbow", rarity="Mythical",  mult=25,  cap=1600, price=400000, color=Color3.fromRGB(255,130,200), vis=6.0, shine=0.15, rainbow=true},
	},

	-- Tycoon items, bought by stepping on buttons on your plot.
	-- pos = where the item is built (plot space: -Z is the front, facing the city). btn = button spot if different from pos.
	Items={
		{id="bed1",      name="Hair Bed",          price=0,     kind="bed",       pos=Vector3.new(-21,0,0)},
		{id="bed2",      name="Hair Bed",          price=40,    kind="bed",       pos=Vector3.new(-7,0,0),   requires="bed1"},
		{id="fence",     name="Fence",             price=60,    kind="fence",     btn=Vector3.new(-6,0,-20), requires="bed1"},
		{id="bed3",      name="Hair Bed",          price=120,   kind="bed",       pos=Vector3.new(7,0,0),    requires="bed2"},
		{id="sign",      name="Salon Sign",        price=150,   kind="sign",      btn=Vector3.new(6,0,-20),  requires="bed2"},
		{id="sprinkler", name="Sprinklers",        price=250,   kind="sprinkler", btn=Vector3.new(-28,0,7),  requires="bed3", desc="beds grow 1.5x faster"},
		{id="bed4",      name="Hair Bed",          price=400,   kind="bed",       pos=Vector3.new(21,0,0),   requires="bed3"},
		{id="autoclip",  name="Auto-Clipper",      price=700,   kind="autoclip",  btn=Vector3.new(0,0,26),   requires="bed4", desc="earns cash by itself"},
		{id="chairs",    name="Salon Chairs",      price=300,   kind="chairs",    btn=Vector3.new(-22,0,-20),requires="autoclip"},
		{id="bed5",      name="Hair Bed",          price=1000,  kind="bed",       pos=Vector3.new(-21,0,14), requires="bed4"},
		{id="bed6",      name="Hair Bed",          price=1800,  kind="bed",       pos=Vector3.new(-7,0,14),  requires="bed5"},
		{id="fertilizer",name="Fertilizer",        price=2500,  kind="fertilizer",btn=Vector3.new(28,0,7),   requires="bed6", desc="2x hair per bed"},
		{id="bed7",      name="Hair Bed",          price=3500,  kind="bed",       pos=Vector3.new(7,0,14),   requires="bed6"},
		{id="fountain",  name="Fountain",          price=1500,  kind="fountain",  btn=Vector3.new(22,0,-20), requires="fertilizer"},
		{id="bed8",      name="Hair Bed",          price=5000,  kind="bed",       pos=Vector3.new(21,0,14),  requires="bed7"},
		{id="lamps",     name="Golden Grow Lamps", price=10000, kind="lamps",     btn=Vector3.new(0,0,7),    requires="bed8", desc="2x hair per bed"},
		{id="statue",    name="Hair Statue",       price=5000,  kind="statue",    btn=Vector3.new(0,0,-12),  requires="lamps"},
	},
}
C.ItemById={}
for i,it in ipairs(C.Items) do it.order=i C.ItemById[it.id]=it end

function C.Value(len,typeIndex)
	local T=C.Types[typeIndex] or C.Types[1]
	return math.floor(len*T.mult+0.5)
end
local S={"","K","M","B","T","Qa","Qi","Sx"}
function C.Format(n)
	local i=1
	while n>=1000 and i<#S do n/=1000 i+=1 end
	if i==1 then return tostring(math.floor(n)) end
	return string.format("%.1f%s",n,S[i])
end
return C
