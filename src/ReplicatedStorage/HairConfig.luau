-- GROW HAIR! settings. Shared by server and client.
local C={
	StartCash=0,
	WalkSpeed=24,
	Locks=70,               -- hair locks drawn per head
	Segments=4,
	Regrow=6,               -- seconds for a farm tuft to regrow
	SellCooldown=1.5,
	AutosaveInterval=60,
	ZoneStart=64, ZoneDepth=70, ZoneWidth=80,
	SoundCoin="5314631765", SoundPop="133119114309377", Music="100333487341753",
	RarityColors={
		Common=Color3.fromRGB(190,190,190), Uncommon=Color3.fromRGB(110,220,110), Rare=Color3.fromRGB(80,165,255),
		Epic=Color3.fromRGB(185,100,255), Legendary=Color3.fromRGB(255,195,50), Mythical=Color3.fromRGB(255,100,185),
	},
	-- Hair types: mult = cash per cm, cap = max hair you can carry (cm), vis = max hair length on the head (studs)
	Types={
		{name="Patchy",  rarity="Common",    mult=1,   cap=25,   price=0,      color=Color3.fromRGB(150,130,110), vis=2.2, shine=0},
		{name="Straight",rarity="Uncommon",  mult=1.5, cap=50,   price=100,    color=Color3.fromRGB(105,65,35),   vis=2.8, shine=0},
		{name="Wavy",    rarity="Rare",      mult=2.5, cap=100,  price=600,    color=Color3.fromRGB(225,175,95),  vis=3.4, shine=0.03, curl=true},
		{name="Curly",   rarity="Epic",      mult=4,   cap=200,  price=3000,   color=Color3.fromRGB(205,85,40),   vis=4.0, shine=0.03, curl=true},
		{name="Silky",   rarity="Epic",      mult=7,   cap=400,  price=15000,  color=Color3.fromRGB(35,30,45),    vis=4.8, shine=0.25},
		{name="Golden",  rarity="Legendary", mult=12,  cap=800,  price=75000,  color=Color3.fromRGB(255,200,60),  vis=5.4, shine=0.3},
		{name="Rainbow", rarity="Mythical",  mult=25,  cap=1600, price=400000, color=Color3.fromRGB(255,130,200), vis=6.0, shine=0.15, rainbow=true},
	},
	-- Hair farms: amount = cm per tuft
	Zones={
		{name="Fuzz Farm",     price=0,      amount=1,  ground=Color3.fromRGB(255,236,215), soil=Color3.fromRGB(185,140,110), tuft=Color3.fromRGB(150,125,100)},
		{name="Curly Fields",  price=300,    amount=3,  ground=Color3.fromRGB(255,205,225), soil=Color3.fromRGB(215,120,155), tuft=Color3.fromRGB(220,100,50)},
		{name="Silk Garden",   price=3000,   amount=8,  ground=Color3.fromRGB(220,205,255), soil=Color3.fromRGB(150,120,205), tuft=Color3.fromRGB(45,40,60)},
		{name="Golden Meadow", price=25000,  amount=20, ground=Color3.fromRGB(255,243,200), soil=Color3.fromRGB(225,185,95),  tuft=Color3.fromRGB(255,200,60)},
		{name="Rainbow Valley",price=200000, amount=60, ground=Color3.fromRGB(205,255,238), soil=Color3.fromRGB(120,205,180), tuft=Color3.fromRGB(255,130,200), rainbow=true},
	},
}
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
