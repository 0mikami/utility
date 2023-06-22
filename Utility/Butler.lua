local Butler = { ClassName = "Butler" }
Butler.__index = Butler

export type Butler = typeof(Butler)

function Butler.new(): Butler
	return setmetatable({
		_IndexPointers = {},
		_Tasks = {},
		IsCleaning = false,
	}, Butler) :: any
end

function Butler:Add(object: any, methodName: (string | boolean)?, key: string?)
	if key then
		self:Remove(key)
		self._IndexPointers[key] = object
	end

	if typeof(object) == "function" or typeof(object) == "thread" then
		methodName = true
	else
		methodName = methodName or "Destroy"

		if typeof(object) == "RBXScriptConnection" then
			methodName = "Disconnect"
		end

		if not object[methodName] then
			return warn(
				string.format(
					"No clean up method ['%s'] was found for [%s]. %s",
					tostring(methodName),
					tostring(object),
					debug.traceback(nil, 2)
				)
			)
		end
	end

	self._Tasks[object] = methodName

	return object
end

function Butler:Get(key: string): any?
	return self._IndexPointers[key]
end

function Butler:Remove(key: string)
	if self._IndexPointers[key] then
		local object = self._IndexPointers[key]
		local methodName = self._Tasks[object]

		if methodName == true then
			if typeof(object) == "function" then
				object()
			else
				pcall(task.cancel, object)
			end
		else
			if object[methodName] then
				object[methodName](object)
			end

			self._Tasks[object] = nil
		end

		self._IndexPointers[key] = nil
	end
end

function Butler:CleanUp()
	if not self.IsCleaning then
		self.IsCleaning = true

		local object, methodName = next(self._Tasks)

		while object and methodName do
			if methodName == true then
				if typeof(object) == "function" then
					object()
				else
					pcall(task.cancel, object)
				end
			else
				if object[methodName] then
					object[methodName](object)
				end
			end
		end

		self._IndexPointers = {}
		self._Tasks = {}

		self.IsCleaning = false
	end
end

return Butler
