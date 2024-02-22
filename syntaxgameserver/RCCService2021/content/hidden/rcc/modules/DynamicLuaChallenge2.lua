local kUInt32Max = 4294967295
local kInt32Max = 2147483647
local alphabet = "\nbcdghjklmnpqrtvwyz23456789BCDGHJKLMNPQRTVWYZ"



local options = {
	polynomials = {0xEDB88320, 0x82F63B78, 0xEB31D82E, 0x992C1A4C},
	gui = {"TextButton", "TextBox", "TextLabel"},
	--gui = {"Frame"},
	ha = {"Enum.HorizontalAlignment.Right", "Enum.HorizontalAlignment.Left", "Enum.HorizontalAlignment.Center"},
	va = {"Enum.VerticalAlignment.Top", "Enum.VerticalAlignment.Bottom", "Enum.VerticalAlignment.Center"},
	fillDirection = {"Enum.FillDirection.Horizontal", "Enum.FillDirection.Vertical"},
	borderMode = {"Enum.BorderMode.Outline", "Enum.BorderMode.Middle", "Enum.BorderMode.Inset" },
	boolean = {"true","false"}
}

local function makeRandomChallenge(seed)
	local rng = Random.new(seed)
	local code = {"-- hi"}
	local function replace(ctx) return function(s, o)
		if s == "rand" then return string.sub(rng:NextNumber(),1,5) end
		if s == "text" then
			local str = ""
			for i=1,rng:NextInteger(1,10) do
				local idx = rng:NextInteger(0,#alphabet)
				str = str .. alphabet:sub(idx,idx):gsub("\n","\\n")
			end
			return str
		end
		if tonumber(s) then return ctx[tonumber(s)] end
		local list = options[s]
		return list[rng:NextInteger(1, #list)]
	end end
	local function append(s,...) code[#code+1] = s:gsub("%$%{([a-z0-9][a-zA-Z]*)%}", replace({...})) end
	append("local xv, yv = ...")
	
	append([==[
	local result = {};
	local r = Random.new(xv+yv)
	local function rand() return r:NextInteger(0,0x400)/0x400 end

	local b = Instance.new("Frame")
	b.Name = "Base"
	local elements = {b}

	local function crc32(s,crc)
		crc = crc and bit32.bnot(crc) or 0xFFFFFFFF
		for i=1,#s do
			local l = bit32.rshift(crc,8)
			crc = bit32.bxor(bit32.band(crc, 0xFF), s:byte(i))
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = (bit32.band(crc,1) == 1) and bit32.bxor(bit32.rshift(crc,1), ${polynomials}) or bit32.rshift(crc,1)
			crc = bit32.bxor(l, crc)
		end
		return bit32.bnot(crc)
	end
	local result = 0
	local function a(...)
		local str = string.format(...)
		result = crc32(str, result)
		--print(str)
	end

	local e = nil
	]==])

	for i=1,rng:NextInteger(10,15) do
		append([==[
			e = Instance.new("${gui}")
			e.BorderSizePixel = r:NextInteger(1,10)
			e.AnchorPoint = Vector2.new(4*rand()*${rand}, rand())
			e.Rotation = r:NextInteger(0,360)
			e.Position = UDim2.new(2*rand(), r:NextInteger(1,100), 2*rand(), r:NextInteger(1,100))
			e.Size = UDim2.new(2*rand(), r:NextInteger(1,100), 2*rand(), r:NextInteger(1,100))
			e.BackgroundColor3 = Color3.new(rand(), rand(), rand())
			--e.BorderMode = ${borderMode}
			e.Parent = elements[#elements]
			e.Name = "${text}"
			elements[#elements+1] = e
		]==])

		if rng:NextInteger(0,2) == 0 then
			append([==[
				e = Instance.new("UIScale")
				e.Scale = 4 * ${rand} * rand()
				e.Name = "Modifier-${text}"
				e.Parent = elements[#elements]
			]==])
		end

		if rng:NextInteger(0,2) == 0 then
			append([==[
				e = Instance.new("UIPadding")
				e.PaddingTop = UDim.new(4*rand()*${rand}, r:NextInteger(1,100)*${rand})
				e.PaddingLeft = UDim.new(4*rand()*${rand}, r:NextInteger(1,100)*${rand})
				e.PaddingBottom = UDim.new(4*rand()*${rand}, r:NextInteger(1,100)*${rand})
				e.PaddingRight = UDim.new(4*rand()*${rand}, r:NextInteger(1,100)*${rand})
				e.Name = "Modifier-${text}"
				e.Parent = elements[#elements]
			]==])
		end

		if rng:NextInteger(0,2) == 0 then
			append([==[
				e = Instance.new("UIListLayout")
				e.Name = "Modifier-${text}"
				e.HorizontalAlignment = ${ha}
				e.VerticalAlignment = ${va}
				e.FillDirection = ${fillDirection}
				e.Parent = elements[#elements]
			]==])
		end
	end

	append("a(game.JobId)")
	
	append([==[
	for k,v in ipairs(elements) do
		a("%d) %d,%d %dx%d %d %s", k,
			v.AbsolutePosition.X, v.AbsolutePosition.Y,
			v.AbsoluteSize.X, v.AbsoluteSize.Y,
			v.Rotation, BrickColor.new(v.BackgroundColor3).Name
		)
	end

	--b.Parent = script.Parent

	]==])
	append("return result")
	
	return table.concat(code,"\n")
end

local seed = ...
if seed == nil then
    seed = Random.new():NextInteger(0, kUInt32Max)
end

local code = makeRandomChallenge(seed)
local rs = game:GetService("RunService")
if rs:IsServer() and not rs:IsClient() then
	game:GetService("NetworkServer"):RegisterDynLuaChallenge(code, seed)
end
return code
