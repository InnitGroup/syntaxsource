local LocalizationService = game:GetService("LocalizationService")
local CorePackages = game:GetService("CorePackages")
local GetFFlagUseDateTimeType = require(CorePackages.AppTempCommon.LuaApp.Flags.GetFFlagUseDateTimeType)

--[[
	This is a Lua implementation of the DateTime API proposal. It'll eventually
	be implemented in C++ and merged into the rest of the codebase if this model
	of working with dates ends up being useful.
]]

local TimeZone = require(script.Parent.TimeZone)
local TimeUnit = require(script.Parent.TimeUnit)

local LuaDateTime = {}

local monthShortNames = {
	"Jan", "Feb", "Mar", "Apr",
	"May", "Jun", "Jul", "Aug",
	"Sep", "Oct", "Nov", "Dec"
}

local monthLongNames = {
	"January", "February", "March", "April",
	"May", "June", "July", "August",
	"September", "October", "November", "December"
}

local dayShortNames = {
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
}

local dayLongNames = {
	"Sunday", "Monday", "Tuesday", "Wednesday",
	"Thursday", "Friday", "Saturday"
}

--[[
	We structure tokens like this to preserve order, since Lua associative
	arrays have no inherent order.
]]
local tokens = {
	{"YYYY", function(values)
		return tostring(values.Year)
	end},
	{"MMMM", function(values)
		return monthLongNames[values.Month]
	end},
	{"MMM", function(values)
		return monthShortNames[values.Month]
	end},
	{"MM", function(values)
		return ("%02d"):format(values.Month)
	end},
	{"M", function(values)
		return tostring(values.Month)
	end},
	{"DDDD", function(values)
		return dayLongNames[values.WeekDay]
	end},
	{"DDD", function(values)
		return dayShortNames[values.WeekDay]
	end},
	{"DD", function(values)
		return ("%02d"):format(values.Day)
	end},
	{"D", function(values)
		return tostring(values.Day)
	end},
	{"HH", function(values)
		local hour = values.Hour

		return ("%02d"):format(hour)
	end},
	{"H", function(values)
		local hour = values.Hour

		return tostring(hour)
	end},
	{"hh", function(values)
		local hour = values.Hour % 12
		if hour == 0 then
			hour = 12
		end

		return ("%02d"):format(hour)
	end},
	{"h", function(values)
		local hour = values.Hour % 12
		if hour == 0 then
			hour = 12
		end

		return tostring(hour)
	end},
	{"mm", function(values)
		return ("%02d"):format(values.Minute)
	end},
	{"m", function(values)
		return tostring(values.Minute)
	end},
	{"ss", function(values)
		return ("%02d"):format(values.Seconds)
	end},
	{"s", function(values)
		return tostring(values.Seconds)
	end},
	{"A", function(values)
		return values.Hour >= 12 and "PM" or "AM"
	end},
	{"a", function(values)
		return values.Hour >= 12 and "pm" or "am"
	end}
}

local tokenKeys = {}
for _, pair in ipairs(tokens) do
	table.insert(tokenKeys, pair[1])
end

local tokenMap = {}
for _, pair in ipairs(tokens) do
	tokenMap[pair[1]] = pair[2]
end

--[[
	What's the next token in this source?
]]
local function getToken(source, i)
	local char = source:sub(i, i)

	for _, token in ipairs(tokenKeys) do
		-- Only keep checking if the first character matches the token
		if token:sub(1, 1) == char then
			local match = source:sub(i, i + token:len() - 1)

			if match == token then
				return token
			end
		end
	end
end

--[[
	An estimate of the current time zone's offset from UTC in seconds.

	This might fail for weird timezones (UTC +/- 14), but we can fix that by
	picking a reference time that's further away from the Unix epoch.
]]
local function getTimeZoneOffset()
	local actualEpoch = 86400 + 43200
	local epoch = os.time({year = 1970, month = 1, day = 2, isdst = -1})
	if epoch then
		return actualEpoch - epoch
	else
		return 0
	end
end

-- Remove all above functions and tables when clean up GetFFlagUseDateTimeType()

--[[
	Create a DateTime with the given values in UTC.

	All values are optional!
]]
function LuaDateTime.new(year, month, day, hour, minute, seconds, milliseconds)
	if GetFFlagUseDateTimeType() then
		local self = {}
		self.dateTime = DateTime.fromUniversalTime(
			year or 1970,
			month or 1,
			day or 1,
			hour or 0,
			minute or 0,
			seconds or 0,
			milliseconds or 0)
		setmetatable(self, LuaDateTime)
		return self
	end

	local tzOffset = getTimeZoneOffset()
	local timestamp = os.time({
		year = year or 1970,
		month = month or 1,
		day = day or 1,
		hour = hour or 0,
		min = minute or 0,
		sec = seconds or 0,
		isdst = -1
	})
	if timestamp == nil then
		timestamp = 0
	end

	if seconds then
		local subseconds = seconds - math.floor(seconds)
		timestamp = timestamp + subseconds
	end

	return LuaDateTime.fromUnixTimestamp(timestamp + tzOffset)
end

--[[
	Create a DateTime representing now.
]]
function LuaDateTime.now()
	if GetFFlagUseDateTimeType() then
		local self = {}
		self.dateTime = DateTime.now()
		setmetatable(self, LuaDateTime)
		return self
	end

	return LuaDateTime.fromUnixTimestamp(os.time())
end

--[[
	Create a Datetime from the given Unix timestamp.

	Limited to the range [0, 2^32) when GetFFlagUseDateTimeType() is off, which lets us represent
	dates out to about 2038.

	When GetFFlagUseDateTimeType() is on, year range is 1400-9999, and timestamp range is between
	first second of year 1400 to the last second of year 9999.
]]
function LuaDateTime.fromUnixTimestamp(timestamp)
	assert(type(timestamp) == "number", "Invalid argument #1 to fromUnixTimestamp, expected number.")

	if GetFFlagUseDateTimeType() then
		local self = {}
		self.dateTime = DateTime.fromUnixTimestampMillis(timestamp*1000)
		setmetatable(self, LuaDateTime)
		return self
	end

	local self = {}

	self.value = timestamp

	setmetatable(self, LuaDateTime)

	return self
end

--[[
	Attempt to create a DateTime from an ISO 8601 date-time string.

	Will return nil on failure and output a warning to a console denoting what
	went wrong. This can probably turned into a second return value if we need
	to handle that data programmatically.
]]
function LuaDateTime.fromIsoDate(isoDate)
	assert(type(isoDate) == "string", "Invalid argument #1 to DateTime.fromIsoDate, expected string.")

	if GetFFlagUseDateTimeType() then
		local self = {}
		self.dateTime = DateTime.fromIsoDate(isoDate)
		setmetatable(self, LuaDateTime)
		return self
	end

	local datePattern = "^(%d+)%-(%d+)%-(%d+)" -- 0000-00-00
	local timePattern = "T(%d+):(%d+):(%d+%.?%d*)" -- T00:00:00
	local utcPattern = "Z$"
	local timeZonePattern = "([+-]%d+):(%d+)$" -- either Z or +/- followed by "00:00"

	local timezone = 0
	local values = {1970, 1, 1, 0, 0, 0}
	local year, month, day = isoDate:match(datePattern)

	if not year then
		warn(("Invalid ISO 8601 date: %q"):format(isoDate))
		return nil
	end

	values[1] = tonumber(year)
	values[2] = tonumber(month)
	values[3] = tonumber(day)

	local hour, minute, seconds = isoDate:match(timePattern)

	if hour then
		values[4] = tonumber(hour)
		values[5] = tonumber(minute)
		values[6] = tonumber(seconds)

		local isUtc = isoDate:match(utcPattern)

		if not isUtc then
			local offsetHours, offsetMinutes = isoDate:match(timeZonePattern)

			if not offsetHours then
				local offsetTotal = getTimeZoneOffset()
				offsetHours = offsetTotal / 3600
				offsetMinutes = 0

				warn(("Invalid time zone in ISO 8601 date: %q -- falling back to local time"):format(isoDate))
			end

			timezone = 3600 * tonumber(offsetHours) + 60 * tonumber(offsetMinutes)
		end
	end

	local date = LuaDateTime.new(unpack(values))
	date.value = date.value - timezone

	return date
end

--[[
	Format our current date using a formatting string. Look at the DateTime
	proposal to see information about the different formatting tokens.
	Generally, they try to resemble LDML and/or Moment.js-style formatting.

	The time zone parameter is optional and defaults to the current time zone,
	TimeZone.Current.
]]
function LuaDateTime:Format(formatString, tz, localeId)
	assert(type(formatString) == "string", "Invalid argument #1 to Format, expected string.")

	if GetFFlagUseDateTimeType() then
		tz = tz or TimeZone.Current
		localeId = localeId or LocalizationService.RobloxLocaleId

		if tz == TimeZone.UTC then
			return self.dateTime:FormatUniversalTime(formatString, localeId)
		elseif tz == TimeZone.Current then
			return self.dateTime:FormatLocalTime(formatString, localeId)
		else
			error(("Invalid TimeZone \"%s\""):format(tostring(tz)), 2)
		end
	end

	tz = tz or TimeZone.Current

	local values = self:GetValues(tz)

	local buffer = {}

	local i = 1
	while i <= formatString:len() do
		local char = formatString:sub(i, i)
		local token = getToken(formatString, i)

		if token then
			table.insert(buffer, tokenMap[token](values))
			i = i + token:len()
		elseif char == "[" then
			-- Crawl forward until the next ] and interpret that text literally
			local j = i
			while j <= formatString:len() do
				j = j + 1

				if formatString:sub(j, j) == "]" then
					break
				end
			end

			table.insert(buffer, formatString:sub(i + 1, j - 1))
			i = j + 1
		else
			table.insert(buffer, char)
			i = i + 1
		end
	end

	local result = table.concat(buffer)

	return result
end

--[[
	Get a table of values representing the date-time in the given timezone.

	The time zone parameter is optional and defaults to the current zime zone,
	TimeZone.Current.

	When GetFFlagUseDateTimeType() is true, table would include
	{Year, Month, Day, Hour, Minute, Second, Millisecond}
]]
function LuaDateTime:GetValues(tz)
	if GetFFlagUseDateTimeType() then
		tz = tz or TimeZone.Current

		if tz == TimeZone.UTC then
			return self.dateTime:ToUniversalTime()
		elseif tz == TimeZone.Current then
			return self.dateTime:ToLocalTime()
		else
			error(("Invalid TimeZone \"%s\""):format(tostring(tz)), 2)
		end
	end

	tz = tz or TimeZone.Current

	local reference

	if tz == TimeZone.Current then
		reference = os.date("*t", self.value)
	elseif tz == TimeZone.UTC then
		reference = os.date("!*t", self.value)
	end

	if not reference then
		error(("Invalid TimeZone \"%s\""):format(tostring(tz)), 2)
	end

	return {
		Year = reference.year,
		Month = reference.month,
		Day = reference.day,
		Hour = reference.hour,
		Minute = reference.min,
		Seconds = reference.sec,
		WeekDay = reference.wday
	}
end

--[[
	Recover a Unix timestamp representing the DateTime's value.
]]
function LuaDateTime:GetUnixTimestamp()
	if GetFFlagUseDateTimeType() then
		if self.dateTime:ToUniversalTime().Millisecond > 0 then
			return self.dateTime.UnixTimestamp + (self.dateTime.UnixTimestampMillis % 1000)/1000
		else
			return self.dateTime.UnixTimestamp
		end
	end

	return self.value
end

--[[
	Format the DateTime as an ISO 8601 date string with time attached.

	Always formats the time as UTC. There generally aren't many reasons to
	generate an ISO 8601 date in another time zone.
]]
function LuaDateTime:GetIsoDate()
	if GetFFlagUseDateTimeType() then
		return self.dateTime:ToIsoDate()
	end

	return self:Format("YYYY-MM-DD[T]HH:mm:ss[Z]", TimeZone.UTC)
end

-- Used by IsSame
-- Remove when clean up GetFFlagUseDateTimeType()
local descendingGranularityUnits = {
	{
		unit = TimeUnit.Years,
		key = "Year"
	},
	{
		unit = TimeUnit.Months,
		key = "Month"
	},
	{
		unit = TimeUnit.Days,
		key = "Day"
	},
	{
		unit = TimeUnit.Hours,
		key = "Hour"
	},
	{
		unit = TimeUnit.Minutes,
		key = "Minute"
	},
	{
		unit = TimeUnit.Seconds,
		key = "Seconds"
	}
}

--[[
	Checks whether two DateTime values are the same, given a granularity and
	timezone value.

	Granularity defaults to seconds and time zone defaults to the current local
	time zone.

	Remove when clean up GetFFlagUseDateTimeType()
]]
function LuaDateTime:IsSame(other, granularity, timezone)
	granularity = granularity or TimeUnit.Seconds
	timezone = timezone or TimeZone.Current

	local selfUnix = self:GetUnixTimestamp()
	local otherUnix = other:GetUnixTimestamp()

	if selfUnix == otherUnix then
		return true
	end

	local selfValues = self:GetValues(timezone)
	local otherValues = other:GetValues(timezone)

	-- Week logic is special
	if granularity == TimeUnit.Weeks then
		local diff = math.abs(selfUnix - otherUnix)
		local diffDays = diff / (60 * 60 * 24)

		-- Two dates separated by 7 or more whole days are never in the same week
		if diffDays >= 7 then
			return false
		end

		-- Two dates separated by less than 7 days will be sorted monotonically
		-- if they're in the same week
		-- TODO: Use start-of-week value to shift WeekDay for locale
		if selfUnix > otherUnix then
			return selfValues.WeekDay >= otherValues.WeekDay
		else
			return selfValues.WeekDay <= otherValues.WeekDay
		end
	end

	for _, unit in ipairs(descendingGranularityUnits) do
		local selfValue = selfValues[unit.key]
		local otherValue = otherValues[unit.key]

		if selfValue ~= otherValue then
			return false
		end

		if unit.unit == granularity then
			break
		end
	end

	return true
end

--[[
	Get a human-readable timestamp relative to the given epoch, which defaults
	to now. The format of the time is contextual to how far away the times are.
]]
function LuaDateTime:GetLongRelativeTime(epoch, timezone, localeId)
	if GetFFlagUseDateTimeType() then
		-- Not relative time format for now, will do that later in DateTime v2
		return self:Format("lll", timezone, localeId)
	end

	timezone = timezone or TimeZone.Current
	epoch = epoch or LuaDateTime.now()

	if self:IsSame(epoch, TimeUnit.Days, timezone) then
		return self:Format("h:mm A", timezone)
	elseif self:IsSame(epoch, TimeUnit.Weeks, timezone) then
		return self:Format("DDD | h:mm A", timezone)
	elseif self:IsSame(epoch, TimeUnit.Years, timezone) then
		return self:Format("MMM D | h:mm A", timezone)
	else
		return self:Format("MMM D, YYYY | h:mm A", timezone)
	end
end

--[[
	Get a human-readable timestamp relative to the given epoch, which defaults
	to now. The format of the time is contextual to how far away the times are.
]]
function LuaDateTime:GetShortRelativeTime(epoch, timezone, localeId)
	timezone = timezone or TimeZone.Current

	if GetFFlagUseDateTimeType() then
		-- Not relative time format for now, will do that later in DateTime v2
		return self:Format("ll", timezone, localeId)
	end

	epoch = epoch or LuaDateTime.now()

	if self:IsSame(epoch, TimeUnit.Days, timezone) then
		return self:Format("h:mm A", timezone)
	elseif self:IsSame(epoch, TimeUnit.Weeks, timezone) then
		return self:Format("DDD", timezone)
	elseif self:IsSame(epoch, TimeUnit.Years, timezone) then
		return self:Format("MMM D", timezone)
	else
		return self:Format("MMM D, YYYY", timezone)
	end
end

LuaDateTime.__index = LuaDateTime

return LuaDateTime