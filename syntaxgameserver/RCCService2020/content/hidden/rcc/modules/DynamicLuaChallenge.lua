local kUInt32Max = 4294967295
local kInt32Max = 2147483647

local function makeRandomChallenge(seed)
	local lotto = seed % 128

    local rng = Random.new(seed)
	local code = {}
	--local function append(s) code[#code+1] = s .. "\n" end
	local function append(s, ...) code[#code+1] = string.format(s, ...) end
	local function appraw(s) code[#code+1] = s end
	local function randSel(t) return t[rng:NextInteger(1,#t)] end
	local function rand(n) return rng:NextInteger(1,n) end
	local function registerCode(t,f) t[#t+1] = f end
	local leafOp = {}
	registerCode(leafOp, function(a,b,c) return string.format("((%s + (%s + %s)))", a, b, c) end)
	registerCode(leafOp, function(a,b,c) return string.format("((%s + (%s - %s)))", a, b, c) end)
	registerCode(leafOp, function(a,b,c) return string.format("((%s - (%s + %s)))", a, b, c) end)
	registerCode(leafOp, function(a,b,c) return string.format("((%s - (%s - %s)))", a, b, c) end)

	local numLeaf = 8
	local numUp = 4
	local numMt = 4
	local numInner = 4
	
	-- x, y are the inputs to the generated function
	append("xv, yv = ...")
	append("local x = {v=xv}")
	append("local y = {v=yv}")
	-- u and u1..un are two ways to reach globals
	append("local u = {}")
	for i = 1,numUp do
		append("local u%d = %d", i, rng:NextInteger(1,kInt32Max))
		append("u[%d] = u%d", i, i)
	end
	append("local rng = Random.new(xv+yv)")
	
	for i = 1,numLeaf do
		append("local function f%d(a,b)", i)
		append(" local r = {v=u[%d]}", rand(numUp))
		-- select random function
		appraw(" r.v = bit32.bor(" .. randSel(leafOp)("r.v", "a.v", "b.v") .. ", 0)")
		appraw(" u[1] = bit32.bor(" .. randSel(leafOp)("u[1]", "r.v", "rng:NextInteger(1,2147483647)") .. ", 0)")
		local idx = rand(numUp)
		local idy = rand(numUp)
		local idz = rand(numUp)
		append(" u[%d], u[%d] = u[%d], u[%d]", idx, idy, idy, idx)
		append(" u[1], u[%d] = u[%d], u[1]", idz, idz)
		-- select random metafunction
		append(" setmetatable(r, getmetatable(%s))", (rand(2)==1) and "a" or "b")
		append(" return r")
		append("end")
	end
	
	-- make metatables
	append("local mt = {}")
	for i = 1,numMt do
		append(" local mt%d = {__add = f%d, __sub = f%d}", i, rand(numLeaf), rand(numLeaf))
		append(" mt[%d] = mt%d", i, i)
	end
	append("setmetatable(x, mt[%d])", rand(numMt))
	append("setmetatable(y, mt[%d])", rand(numMt))
		
	-- make functions
	for i = 1, numInner do
		append("local function n%d(a,b)", i)
		append(" local r = {v=u[%d]}", rand(numUp))
		append(" setmetatable(r, mt%d)", rand(numMt))
		-- shuffle and update globals
		local k = rand(numUp)
		append(" u[%d] = bit32.bor(u[%d] + u[%d], 0)", k, k, rand(numUp))
		-- select random function
		appraw(" r =" .. randSel(leafOp)("r", "a", "b"))
		append(" r = f%d(r, %s)", rand(numLeaf), (rand(2)==1) and "a" or "b")
		appraw(" u[1] = " .. randSel(leafOp)("u[1]", "r.v", "rng:NextInteger(1,2147483647)"))
		append(" return r")
		append("end")
	end
		
	-- order functions
	append("local acc = 0")
	append("local funcs = {")
	for i = 1, numInner do
		append(" n%d%s", i, (i==numInner) and "}" or ",")
	end
	append("for i = #funcs,2,-1 do")
	append(" local j = rng:NextInteger(1,i)")
	append(" funcs[i], funcs[j] = funcs[j], funcs[i]")
	append("end")

	-- accumulate
	append("acc = x+y")
	for i = 1,numInner do
		append("acc = funcs[%d](acc, %s)", i, (i%2 == 1) and "x" or "y")
	end
	append("acc = acc.v")
	append("for i = 1,%d do", numUp)
	append( "acc = bit32.bor(acc + u[i], 0)")
	append("end")

	-- probe
	append("local ji = game.JobId")
	append("for i=1,#ji do acc = acc + ji:byte(i) end")

	-- Roblox has UserSettings, vanilla gives different error
	append("local tmpstr")
	append("xpcall(function() tmpstr = tostring(UserSettings()) end, function() tmpstr = \"nope\" end)")
	append("for i=1,#tmpstr do acc = acc + tmpstr:byte(i) end")

	-- Roblox has 3 arg xpcall, vanilla errors
	append("local tmpstr2")
	append("xpcall(function(...) tmpstr2 = tostring(UserSettings()) .. ... end, function() tmpstr2 = \"nope\" end, \"yep\")")
	append("for i=1,#tmpstr2 do acc = acc + tmpstr2:byte(i) end")

	-- Roblox does not have os.exit, vanilla exits
	append("xpcall(function() os.exit() end, function() acc = acc + 9001 end)")

	-- studio, client/server, and vanilla all behave differently.
	append("xpcall(function() acc = game:GetService(\"RunService\"):IsStudio() and (acc+256) or (acc+1024) end, function() acc = acc + 512 end)")	

	-- namecall test
	append("xpcall(function() local obj = newproxy(true) getmetatable(obj).__namecall = function(self, arg) return 42 + arg end acc = acc + obj:Foo(10) end, function() acc = acc + 2000 end)")
	
	-- done
	append("return acc")
	
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
