--!nocheck

arg0,arg1 = ...

-- 8 2-input functions
local function x1(a, b)	return a + b end
local function x2(a, b)	return a - b end
local function x3(a, b)	return b - a end
local function x4(a, b)	return tonumber(tostring(b%1000) .. tostring(math.abs(a%1000))) end
local function x5(a, b)	return tonumber(tostring(b%1337) .. tostring(math.abs(a%1337))) end
local function x6(a, b)	return (a % 1000) * (b % 1000) end
local function x7(a, b)	return (a % 1337) * (b % 1337) end
local function x8(a, b)	return x6(x1(a,b),x2(a,b)) end

-- shuffle list to ensure code must emulate our RNG
local sh = {1,2,3,4,5,6,7,8}
local r = Random.new(5)
for i = 1,32 do
	local j = r:NextInteger(1,8)
	local k = r:NextInteger(1,8)
	local t = sh[j]
	sh[j] = sh[k]
	sh[k] = t
end
local bf = {}
bf[sh[1]] = x1
bf[sh[2]] = x2
bf[sh[3]] = x3
bf[sh[4]] = x4
bf[sh[5]] = x5
bf[sh[6]] = x6
bf[sh[7]] = x7
bf[sh[8]] = x8

local function x9(a, b)
	local acc = 393
	local cnt = 1
	-- create and iterate over table in a way that iteration order matters.
	for i = 1, 16 do
		local em = (math.abs(b+acc+cnt) % 8) + 1
		local f = bf[em]
		acc = (acc + f(acc+a, b)) % 10000000
		cnt = cnt + 1
	end
	return acc
end
return x9(arg0,arg1)

