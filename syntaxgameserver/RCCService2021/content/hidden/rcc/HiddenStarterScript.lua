--[[
Description: Starts scripts that are only run on RCC and are 
            hidden to other builds.
]]--

game:DefineFastInt("DynamicDlc", 0) -- make sure the value doesn't leak.
game:DefineFastInt("DynamicDlc2", 0)
game:DefineFastFlag("SaferHss", false)

local decodedDlc = bit32.bxor(bit32.rrotate(bit32.bxor(game:GetFastInt("DynamicDlc"), 777777777),13), 888888888)
decodedDlc = decodedDlc + (4294967296 * game:GetFastInt("DynamicDlc2"))

local core = game:GetService("CorePackages")
function safeLoad(module, flag)
	local pass, ret = pcall(function()
		if flag == nil or settings():GetFFlag(flag) == true then
			require(core.hidden.rcc.modules[module])()
		end
	end)
	if pass == false and settings():GetFFlag("DebugShowRccLoadErrors") then
		warn("Module " .. module .. " failed to load: " .. tostring(ret))
	end
	return pass
end

if game:GetFastFlag("SaferHss") == true then
	-- bot detection heuristic
	if false == safeLoad("BotHeuristic") then
		game:GetService("Players"):SetRealPlace(true)
	end
end

-- Load the Dynamic Lua Challenge
if (game:GetFastInt("DynamicDlc") ~= 0) then
	if game:GetFastFlag("SaferHss") == true then
		spawn(function()
			require(decodedDlc)
		end)
	else
		require(decodedDlc)
	end
else
	if game:GetFastInt("DlcVersion") == 2 then
		require(core.hidden.rcc.modules.DynamicLuaChallenge2)
	else
		require(core.hidden.rcc.modules.DynamicLuaChallenge)
	end
end

if game:GetFastFlag("SaferHss") ~= true then
	-- bot detection heuristic
	safeLoad("BotHeuristic")
end

-- bot reporting
safeLoad("BotInfo", "JumpScaresP2")
