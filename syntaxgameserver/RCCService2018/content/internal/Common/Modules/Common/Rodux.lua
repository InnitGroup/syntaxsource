--[[
	Wraps around Rodux and applies a compatibility patch to deal with API
	breakages since the last Rodux upgrade.

	Things that have changed:
	* Store API is now camelCase instead of PascalCase to match standards
	* Signal API is now camelCase instead of PascalCase (affects store.changed signal)
	* Thunks are no longer enabled by default

	This file should not be modifying any objects in CorePackages, only wrapping them!
]]

local CorePackages = game:GetService("CorePackages")

local Logging = require(CorePackages.Logging)

local Rodux = require(CorePackages.Rodux)
local Signal = require(CorePackages.RoduxImpl.Signal)

local function getWarningMessage(className, funcNameCamelCase)
	return string.format(
		"%s:%s() has been deprecated, use %s()\n%s]",
		className,
		funcNameCamelCase:sub(1, 1):upper() .. funcNameCamelCase:sub(2),
		funcNameCamelCase,
		debug.traceback()
	)
end

local StoreCompat = {}

function StoreCompat.new(reducer, initialState)
	--[[
		Older consumers of Rodux expect Thunks to be enabled by default, so we
		introduce the thunk middleware by default here.
	]]
	local store = Rodux.Store.new(reducer, initialState, { Rodux.thunkMiddleware })

	--[[
		Create PascalCase compatibility versions of regular Store methods
		It's easier to do this here since we'd otherwise have to deal with
		reassigning the store's metatable
	]]
	store.Dispatch = function(...)
		Logging.warn(getWarningMessage("Store", "dispatch"))
		return store.dispatch(...)
	end

	store.GetState = function(...)
		Logging.warn(getWarningMessage("Store", "getState"))
		return store.getState(...)
	end
	store.Destruct = function(...)
		Logging.warn(getWarningMessage("Store", "destruct"))
		return store.destruct(...)
	end
	store.Flush = function(...)
		Logging.warn(getWarningMessage("Store", "flush"))
		return store.flush(...)
	end

	-- Store's changed signal also needs a compatibility layer added to it
	store.changed.connect = function(...)
		local connection = Signal.connect(...)

		-- 'disconnect' is created for every connection.
		connection.Disconnect = function(...)
			Logging.warn(getWarningMessage("Connection", "disconnect"))
			return connection.disconnect(...)
		end

		return connection
	end

	-- Create PascalCase versions of regular Signal methods
	store.changed.Connect = function(...)
		Logging.warn(getWarningMessage("Signal", "connect"))
		return store.changed.connect(...)
	end

	--[[
		Note: We deliberately exclude 'Signal.fire' because users
		should never call it anyways!
	]]

	-- Provide PascalCase compatibility accessor to store.changed
	store.Changed = store.changed

	return store
end

--[[
	Manually recreate Rodux's interface using our augmented version
	of the Store functionality
]]
local RoduxCompat = {
	Store = StoreCompat,
	createReducer = Rodux.createReducer,
	combineReducers = Rodux.combineReducers,
	loggerMiddleware = Rodux.loggerMiddleware,
	thunkMiddleware = Rodux.thunkMiddleware,
}

return RoduxCompat