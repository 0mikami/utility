local Signal = {}
Signal.__index = Signal

export type Signal = typeof(Signal)

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(Connection)

local freeThread = nil

local function runOnFreeThread(callback: () -> (), ...: any)
	local thread = freeThread
	freeThread = nil

	callback(...)

	freeThread = thread
end

local function createFreeThread()
	while true do
		runOnFreeThread(coroutine.yield())
	end
end

function Signal.new(): Signal
	return setmetatable({
		_ListHead = nil,
		_ListTail = nil,
	}, Signal) :: any
end

function Signal:Connect(callback: (...any) -> ...any)
	local connection = Connection.new(self, callback)

	if self._ListTail == nil then
		self._ListTail = connection
	else
		if self._ListHead ~= nil then
			self._ListHead._Next = connection
		end
	end

	self._ListHead = connection

	return connection
end

function Signal:DisconnectAll()
	self._ListHead = nil
	self._ListTail = nil
end

function Signal:Fire(...: any)
	local connection = self._ListTail

	while connection do
		if connection._Connected then
			if not freeThread then
				freeThread = coroutine.create(createFreeThread)

				coroutine.resume(freeThread)
			end

			task.spawn(freeThread, connection._CallBack, ...)
		end

		connection = connection._Next
	end
end

function Signal:Wait()
	local waitingCoroutine = coroutine.running()

	local connection = nil
	connection = self:Connect(function(...: any)
		connection:Disconnect()

		task.spawn(waitingCoroutine, ...)
	end)

	return coroutine.yield()
end

function Signal:Once(callback)
	local connection = nil
	connection = self:Connect(function(...)
		if connection._Connected then
			connection:Disconnect()
		end

		callback(...)
	end)

	return connection
end

function Connection.new(signal: Signal, callback: (...any) -> ...any)
	return setmetatable({
		_Signal = signal,
		_CallBack = callback,
		_Connected = true,
		_Next = nil,
	}, Connection)
end

function Connection:Disconnect()
	if self == self._Signal._ListTail then
		self._Signal._ListTail = self._Next
	else
		local connection = self._Signal._ListTail

		while connection do
			if connection._Next == self then
				connection._Next = self._Next

				if self._Next == nil then
					self._Signal._ListHead = connection
				end

				break
			end

			connection = connection._Next
		end
	end
end

return Signal
