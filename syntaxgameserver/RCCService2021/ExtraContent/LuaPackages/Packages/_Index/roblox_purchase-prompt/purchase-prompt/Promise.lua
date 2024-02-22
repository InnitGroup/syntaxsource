--[[
	An implementation of Promises similar to Promise/A+.
]]

local PROMISE_DEBUG = false

--[[
	Packs a number of arguments into a table and returns its length.
	Used to cajole varargs without dropping sparse values.
]]
local function pack(...)
	local len = select("#", ...)

	return len, { ... }
end

--[[
	wpcallPacked is a version of xpcall that:
	* Returns the length of the result first
	* Returns the result packed into a table
	* Passes extra arguments through to the passed function, which xpcall does not
	* Issues a warning if PROMISE_DEBUG is enabled
]]
local function wpcallPacked(f, ...)
	local argsLength, args = pack(...)

	local body = function()
		return f(unpack(args, 1, argsLength))
	end

	local resultLength, result = pack(xpcall(body, debug.traceback))

	-- If promise debugging is on, warn whenever a pcall fails.
	-- This is useful for debugging issues within the Promise implementation
	-- itself.
	if PROMISE_DEBUG and not result[1] then
		warn(result[2])
	end

	return resultLength, result
end

--[[
	Creates a function that invokes a callback with correct error handling and
	resolution mechanisms.
]]
local function createAdvancer(callback, resolve, reject)
	return function(...)
		local resultLength, result = wpcallPacked(callback, ...)
		local ok = result[1]

		if ok then
			resolve(unpack(result, 2, resultLength))
		else
			reject(unpack(result, 2, resultLength))
		end
	end
end

local function isEmpty(t)
	return next(t) == nil
end

local Promise = {}
Promise.__index = Promise

Promise.Status = {
	Started = "Started",
	Resolved = "Resolved",
	Rejected = "Rejected",
}

--[[
	Constructs a new Promise with the given initializing callback.
	This is generally only called when directly wrapping a non-promise API into
	a promise-based version.
	The callback will receive 'resolve' and 'reject' methods, used to start
	invoking the promise chain.
	For example:
		local function get(url)
			return Promise.new(function(resolve, reject)
				spawn(function()
					resolve(HttpService:GetAsync(url))
				end)
			end)
		end
		get("https://google.com")
			:andThen(function(stuff)
				print("Got some stuff!", stuff)
			end)
]]
function Promise.new(callback)
	local promise = {
		-- Used to locate where a promise was created
		_source = debug.traceback(),

		-- A tag to identify us as a promise
		_type = "Promise",

		_status = Promise.Status.Started,

		-- A table containing a list of all results, whether success or failure.
		-- Only valid if _status is set to something besides Started
		_values = nil,

		-- Lua doesn't like sparse arrays very much, so we explicitly store the
		-- length of _values to handle middle nils.
		_valuesLength = -1,

		-- If an error occurs with no observers, this will be set.
		_unhandledRejection = false,

		-- Queues representing functions we should invoke when we update!
		_queuedResolve = {},
		_queuedReject = {},
	}

	setmetatable(promise, Promise)

	local function resolve(...)
		promise:_resolve(...)
	end

	local function reject(...)
		promise:_reject(...)
	end

	local _, result = wpcallPacked(callback, resolve, reject)
	local ok = result[1]
	local err = result[2]

	if not ok and promise._status == Promise.Status.Started then
		reject(err)
	end

	return promise
end

--[[
	Create a promise that represents the immediately resolved value.
]]
function Promise.resolve(value)
	return Promise.new(function(resolve)
		resolve(value)
	end)
end

--[[
	Create a promise that represents the immediately rejected value.
]]
function Promise.reject(value)
	return Promise.new(function(_, reject)
		reject(value)
	end)
end

--[[
	Returns a new promise that:
		* is resolved when all input promises resolve
		* is rejected if ANY input promises reject
]]
function Promise.all(...)
	local promises = {...}

	-- check if we've been given a list of promises, not just a variable number of promises
	if type(promises[1]) == "table" and promises[1]._type ~= "Promise" then
		-- we've been given a table of promises already
		promises = promises[1]
	end

	return Promise.new(function(resolve, reject)
		local isResolved = false
		local results = {}
		local totalCompleted = 0
		local promiseCount = 0

		-- If we're agnostic about whether the promises are a table
		-- or a list, users can provide tables with useful keys if they like
		for _ in pairs(promises) do
			promiseCount = promiseCount + 1
		end

		local function promiseCompleted(key, result)
			if isResolved then
				return
			end

			results[key] = result
			totalCompleted = totalCompleted + 1

			if totalCompleted == promiseCount then
				resolve(results)
				isResolved = true
			end
		end

		if promiseCount == 0 then
			resolve(results)
			isResolved = true
			return
		end

		for key, promise in pairs(promises) do
			-- if a promise isn't resolved yet, add listeners for when it does
			if promise._status == Promise.Status.Started then
				promise:andThen(function(result)
					promiseCompleted(key, result)
				end):catch(function(reason)
					isResolved = true
					reject(reason)
				end)

			-- if a promise is already resolved, move on
			elseif promise._status == Promise.Status.Resolved then
				promiseCompleted(key, unpack(promise._values))

			-- if a promise is rejected, reject the whole chain
			else --if promise._status == Promise.Status.Rejected then
				-- We catch here to indicate that the intermediate rejection
				-- has been handled and seen
				promise:catch(function(reason)
					isResolved = true
					reject(unpack(promise._values))
				end)
			end
		end
	end)
end

--[[
	Is the given object a Promise instance?
]]
function Promise.is(object)
	if type(object) ~= "table" then
		return false
	end

	return object._type == "Promise"
end

--[[
	Construct a promise from a yielding function
]]
function Promise.promisify(callback)
	return function(...)
		local args = {...}
		local argLength = select("#", ...)

		return Promise.new(function(resolve, reject)
			spawn(function()
				local success, result = pcall(callback, unpack(args, 1, argLength))

				if success then
					resolve(result)
				else
					reject(result)
				end
			end)
		end)
	end
end

function Promise:getStatus()
	return self._status
end

--[[
	Creates a new promise that receives the result of this promise.
	The given callbacks are invoked depending on that result.
]]
function Promise:andThen(successHandler, failureHandler)
	self._unhandledRejection = false

	-- Create a new promise to follow this part of the chain
	return Promise.new(function(resolve, reject)
		-- Our default callbacks just pass values onto the next promise.
		-- This lets success and failure cascade correctly!

		local successCallback = resolve
		if successHandler then
			successCallback = createAdvancer(successHandler, resolve, reject)
		end

		local failureCallback = reject
		if failureHandler then
			failureCallback = createAdvancer(failureHandler, resolve, reject)
		end

		if self._status == Promise.Status.Started then
			-- If we haven't resolved yet, put ourselves into the queue
			table.insert(self._queuedResolve, successCallback)
			table.insert(self._queuedReject, failureCallback)
		elseif self._status == Promise.Status.Resolved then
			-- This promise has already resolved! Trigger success immediately.
			successCallback(unpack(self._values, 1, self._valuesLength))
		elseif self._status == Promise.Status.Rejected then
			-- This promise died a terrible death! Trigger failure immediately.
			failureCallback(unpack(self._values, 1, self._valuesLength))
		end
	end)
end

--[[
	Used to catch any errors that may have occurred in the promise.
]]
function Promise:catch(failureCallback)
	return self:andThen(nil, failureCallback)
end

--[[
	Yield until the promise is completed.
	This matches the execution model of normal Roblox functions.
]]
function Promise:await()
	self._unhandledRejection = false

	if self._status == Promise.Status.Started then
		local result
		local resultLength
		local bindable = Instance.new("BindableEvent")

		self:andThen(function(...)
			result = {...}
			resultLength = select("#", ...)
			bindable:Fire(true)
		end, function(...)
			result = {...}
			resultLength = select("#", ...)
			bindable:Fire(false)
		end)

		local ok = bindable.Event:Wait()
		bindable:Destroy()

		return ok, unpack(result, 1, resultLength)
	elseif self._status == Promise.Status.Resolved then
		return true, unpack(self._values, 1, self._valuesLength)
	elseif self._status == Promise.Status.Rejected then
		return false, unpack(self._values, 1, self._valuesLength)
	end
end

function Promise:_resolve(...)
	if self._status ~= Promise.Status.Started then
		return
	end

	local argLength = select("#", ...)

	-- If the resolved value was a Promise, we chain onto it!
	if Promise.is((...)) then
		-- Without this warning, arguments sometimes mysteriously disappear
		if argLength > 1 then
			local message = (
				"When returning a Promise from andThen, extra arguments are " ..
				"discarded! See:\n\n%s"
			):format(
				self._source
			)
			warn(message)
		end

		(...):andThen(function(...)
			self:_resolve(...)
		end, function(...)
			self:_reject(...)
		end)

		return
	end

	self._status = Promise.Status.Resolved
	self._values = {...}
	self._valuesLength = argLength

	-- We assume that these callbacks will not throw errors.
	for _, callback in ipairs(self._queuedResolve) do
		callback(...)
	end
end

function Promise:_reject(...)
	if self._status ~= Promise.Status.Started then
		return
	end

	self._status = Promise.Status.Rejected
	self._values = {...}
	self._valuesLength = select("#", ...)

	-- If there are any rejection handlers, call those!
	if not isEmpty(self._queuedReject) then
		-- We assume that these callbacks will not throw errors.
		for _, callback in ipairs(self._queuedReject) do
			callback(...)
		end
	else
		-- At this point, no one was able to observe the error.
		-- An error handler might still be attached if the error occurred
		-- synchronously. We'll wait one tick, and if there are still no
		-- observers, then we should put a message in the console.

		self._unhandledRejection = true
		local err = tostring((...))

		spawn(function()
			-- Someone observed the error, hooray!
			if not self._unhandledRejection then
				return
			end

			-- Build a reasonable message
			local message = ("Unhandled promise rejection:\n\n%s\n\n%s"):format(
				err,
				self._source
			)
			warn(message)
		end)
	end
end

return Promise