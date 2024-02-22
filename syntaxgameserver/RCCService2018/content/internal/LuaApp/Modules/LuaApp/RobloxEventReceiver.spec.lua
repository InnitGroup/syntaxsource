local HttpService = game:GetService("HttpService")

local mockNotificationService = {}
mockNotificationService.__index = mockNotificationService

function mockNotificationService.new()
	local self = {}
	setmetatable(self, mockNotificationService)
	self.RobloxEventReceived = {}

	function self.RobloxEventReceived:Connect(callback)
		self.connection = callback
	end

	function self.RobloxEventReceived:send(event)
		self.connection(event)
	end
	return self
end

return function()
	local RobloxEventReceiver = require(game:GetService("CoreGui").RobloxGui.Modules.LuaApp.RobloxEventReceiver)
	it("should be able to be created", function()
		RobloxEventReceiver.new(mockNotificationService.new())
	end)

	describe("should have the correct api", function()
		it("should require a notificationService", function()
			expect(function()
				RobloxEventReceiver.new(nil)
			end).to.throw()
			expect(function()
				RobloxEventReceiver.new({})
			end).to.throw()
			RobloxEventReceiver.new(mockNotificationService.new())
		end)

		it("should throw on bad arguments for observeEvent", function()
			local eventReceiver = RobloxEventReceiver.new(mockNotificationService.new())
			expect(function()
				eventReceiver:observeEvent()
			end).to.throw()
			expect(function()
				eventReceiver:observeEvent({}, function()end)
			end).to.throw()
			expect(function()
				eventReceiver:observeEvent("namespace", {})
			end).to.throw()
			-- normal call
			local connection = eventReceiver:observeEvent("namespace", function()end)
			connection:Disconnect()
		end)
	end)

	describe("handle observer", function()
		it("takes a observer", function()
			local eventReceiver = RobloxEventReceiver.new(mockNotificationService.new())
			local connection = eventReceiver:observeEvent("namespace", function()
				error("Should not call this callback")
			end)
			connection.Disconnect()
		end)

		it("notifies and disconnects observer", function()
			local mns = mockNotificationService.new()
			local eventReceiver = RobloxEventReceiver.new(mns)
			local count = 0
			local test_message = "TEST"
			local test_detail = HttpService:JSONEncode({message = test_message})
			local namespace = "namespaceSingular"

			local connection = eventReceiver:observeEvent(namespace, function(event)
				count = count + 1
				expect(event.message).to.equal("TEST")
			end)
			mns.RobloxEventReceived:send({
				namespace = namespace,
				detail = test_detail,
			})

			expect(count).to.equal(1)
			connection.Disconnect()

			mns.RobloxEventReceived:send({
				namespace = namespace,
				detail = test_detail,
			})
			expect(count).to.equal(1)
		end)
	end)

	describe("handle multiple observers", function()
		it("notifies and disconnects observers", function()
			local mns = mockNotificationService.new()
			local eventReceiver = RobloxEventReceiver.new(mns)
			local count = 0
			local test_message = "TEST"
			local test_detail = HttpService:JSONEncode({message = test_message})
			local namespace = "namespaceSingular"

			local connection = eventReceiver:observeEvent(namespace, function(detail)
				count = count + 1
				expect(detail.message).to.equal(test_message)
			end)
			local connection2 = eventReceiver:observeEvent(namespace, function(detail)
				count = count + 1
				expect(detail.message).to.equal(test_message)
			end)

			mns.RobloxEventReceived:send({
				namespace = namespace,
				detail = test_detail,
			})

			expect(count).to.equal(2)
			connection.Disconnect()
			connection2.Disconnect()

			mns.RobloxEventReceived:send({
				namespace = namespace,
				detail = test_detail,
			})
			expect(count).to.equal(2)
		end)
	end)

	describe("should not call when", function()
		it("deals with different namespace", function()
			local mns = mockNotificationService.new()
			local eventReceiver = RobloxEventReceiver.new(mns)
			local test_message = "TEST"
			local test_detail = HttpService:JSONEncode({message = test_message})
			local namespace = "namespace"

			local connection = eventReceiver:observeEvent("differentNameSpace", function(message)
				error("Should not call this callback")
			end)
			mns.RobloxEventReceived:send({
				namespace = namespace,
				detail = test_detail,
			})

			connection.Disconnect()
		end)

		it("deals with different types", function()
			local mns = mockNotificationService.new()
			local eventReceiver = RobloxEventReceiver.new(mns)
			local test_message = "TEST"
			local test_detail = HttpService:JSONEncode({message = test_message})
			local namespace = "namespace"

			local connection = eventReceiver:observeEvent(namespace, function(message)
				error("Should not call this callback")
			end)
			mns.RobloxEventReceived:send({
				namespace = "otherNameSpace",
				detail = test_detail,
			})

			connection.Disconnect()
		end)

		it("expects a singlular event", function()
			local mns = mockNotificationService.new()
			local eventReceiver = RobloxEventReceiver.new(mns)
			local test_message = "TEST"
			local test_detail = HttpService:JSONEncode({message = test_message})
			local namespace = "namespace"

			local connection = eventReceiver:observeEvent(namespace, function(message)
				error("Should not call this callback")
			end)
			mns.RobloxEventReceived:send({
				namespace = "otherNameSpace",
				detail = test_detail,
			})

			connection.Disconnect()
		end)
	end)
end