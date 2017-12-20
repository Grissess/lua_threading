local threading = {}

if bit32 == nil then
	bit32 = require("_bit32")
end

local singlet = require("singlet")

threading.current = nil
threading.RUNNABLE = {}

function threading.WAIT_INDEFINITELY() return false end

local Thread = {}
threading.Thread = Thread

function Thread.new(obj, ...)
	if type(obj) == "function" then
		obj = coroutine.create(obj)
	end

	assert(type(obj) == "thread")

	return setmetatable({
		co = obj,
		args = {...},
		state = "born",
		caps = {},  -- singlet -> table (object)
		rev_caps = {},
		notify = {
			death = {},  -- When the thread is killed
			run = {},  -- When the thread is scheduled
			activation = {},  -- When a thread is added to schedulability
			suspension = {},  -- When a thread is removed from schedulability
			error = {},  -- When a thread encounters a kernel error (not an internal error--those cause death)
		},
	}, Thread.mt)
end

function Thread:grant(obj)
	local sin = singlet.new()
	self.caps[sin] = obj
	self.rev_caps[obj] = sin
	return sin
end

function Thread:translate_to_caps(seq, strict)
	if strict == nil then strict = true end

	for i, obj in ipairs(seq) do
		if self.caps[obj] ~= nil then
			seq[i] = self.caps[obj]
		elseif strict and type(obj) == "table" then
			error("Attempt to pass unrecognized table across supervisor boundary")
		end
	end
end

function Thread:translate_from_caps(seq, strict)
	if strict == nil then strict = false end

	for i, obj in ipairs(seq) do
		if type(obj) == "table" then
			if self.rev_caps[obj] == nil then
				if strict then
					error("Attempt to pass ungranted table back to userspace")
				else
					self:grant(obj)
				end
			end
			seq[i] = self.rev_caps[obj]
		end
	end
end

function Thread:is_waiting()
	return self.wchan ~= nil
end

function Thread:notify_on(event, ac, value)
	if self.notify[event] == nil then return false, "no such event" end
	self.notify[event][{ac = ac, value = value}] = true
	return true
end

function Thread:raise_notify(event)
	local one_ran = false
	for n, _ in pairs(self.notify[event]) do
		n.ac:set(n.value)
		one_ran = true
	end
	return one_ran
end

local THREAD_OBJECT = {}
threading.THREAD_OBJECT = THREAD_OBJECT

Thread.mt = {
	__index = Thread,
	__metatable = THREAD_OBJECT,
}

local SyncChannel = {}
threading.SyncChannel = SyncChannel

function SyncChannel.new()
	return setmetatable({writers = {}, readers = {}}, SyncChannel.mt)
end

function SyncChannel:write(...)
	local cur = threading.current
	assert(not cur:is_waiting(), "call from sleeping thread")

	self.writers[cur] = true
	local data = {...}
	cur.wchan = function()
		local reader = next(self.readers)
		if reader ~= nil then
			reader.args = data
			reader.wchan = nil
			self.readers[reader] = nil
			self.writers[cur] = nil
			return true
		end
		return false
	end
end

function SyncChannel:read()
	local cur = threading.current
	assert(not cur:is_waiting(), "call from sleeping thread")

	self.readers[cur] = true
	cur.wchan = threading.WAIT_INDEFINITELY
end

local SYNC_CHANNEL_OBJECT = {}
threading.SYNC_CHANNEL_OBJECT = SYNC_CHANNEL_OBJECT

SyncChannel.mt = {
	__index = SyncChannel,
	__metatable = SYNC_CHANNEL_OBJECT,
}

local AsyncChannel = {}
threading.AsyncChannel = AsyncChannel

function AsyncChannel.new()
	return setmetatable({value = 0, waiters = {}}, AsyncChannel.mt)
end

function AsyncChannel:set(v)
	self.value = bit32.bor(self.value, v)
end

function AsyncChannel:unset(v)
	self.value = bit32.band(self.value, bit32.bnot(v))
end

function AsyncChannel:get()
	return self.value
end

function AsyncChannel:wait(msk)
	local cur = threading.current
	assert(not cur:is_waiting(), "call from sleeping thread")

	self.waiters[cur] = msk
	cur.wchan = function()
		if bit32.btest(self.value, msk) then
			self.waiters[cur] = nil
			cur.args = {self.value}
			return true
		end
		return false
	end
end

local ASYNC_CHANNEL_OBJECT = {}
threading.ASYNC_CHANNEL_OBJECT = ASYNC_CHANNEL_OBJECT

AsyncChannel.mt = {
	__index = AsyncChannel,
	__metatable = ASYNC_CHANNEL_OBJECT,
}

function threading.add_runnable(thr)
	if threading.RUNNABLE[thr] == nil then
		thr:raise_notify("activation")
	end
	threading.RUNNABLE[thr] = true
end

function threading.remove_runnable(thr)
	if threading.RUNNABLE[thr] then
		thr:raise_notify("suspension")
	end
	threading.RUNNABLE[thr] = nil
end

function threading.kill(thr)
	threading.remove_runnable(thr)
	thr.state = "dead"
	thr:raise_notify("death")
	if threading.current == thr then
		threading.current = nil
	end
end

threading.syscall_table = {
	yield = function() return true end,
	new_thr = function(f, ...)
		return threading.Thread.new(f, ...)
	end,
	thr_activate = function(thr)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		threading.add_runnable(thr)
		return true
	end,
	thr_suspend = function(thr)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		threading.remove_runnable(thr)
		return true
	end,
	thr_set_args = function(thr, ...)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		thr.args = {...}
		return true
	end,
	thr_get_args = function(thr)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		return true, thr.args
	end,
	thr_get_result = function(thr)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		return true, thr.result
	end,
	thr_notify_on = function(thr, ev, ac, v)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		if getmetatable(ac) ~= ASYNC_CHANNEL_OBJECT then
			return false, "not an async channel"
		end
		return thr:notify_on(ev, ac, v)
	end,
	thr_kill = function(thr)
		if getmetatable(thr) ~= THREAD_OBJECT then
			return false, "not a thread"
		end
		threading.kill(thr)
	end,
	thr_current = function()
		return threading.current
	end,
	new_sc = function() return threading.SyncChannel.new() end,
	sc_write = function(sync, ...)
		if getmetatable(sync) ~= SYNC_CHANNEL_OBJECT then
			return false, "not a sync channel"
		end
		sync:write(...)
		return true
	end,
	sc_read = function(sync)
		if getmetatable(sync) ~= SYNC_CHANNEL_OBJECT then
			return false, "not a sync channel"
		end
		sync:read()
		return  -- Return overridden by wchan on SyncChannel object
	end,
	new_ac = function() return threading.AsyncChannel.new() end,
	ac_set = function(async, v)
		if getmetatable(async) ~= ASYNC_CHANNEL_OBJECT then
			return false, "not an async channel"
		end
		async:set(v)
		return true
	end,
	ac_unset = function(async, v)
		if getmetatable(async) ~= ASYNC_CHANNEL_OBJECT then
			return false, "not an async channel"
		end
		async:unset(v)
		return true
	end,
	ac_get = function(async)
		if getmetatable(async) ~= ASYNC_CHANNEL_OBJECT then
			return false, "not an async channel"
		end
		return async.value
	end,
	ac_wait = function(async, msk)
		if getmetatable(async) ~= ASYNC_CHANNEL_OBJECT then
			return false, "not an async channel"
		end
		async:wait(msk)
		return  -- Return overridden
	end,
}

function threading.syscall(name, ...)
	local result = {pcall(threading.syscall_table[name], ...)}
	local success = table.remove(result, 1)
	local cur = threading.current

	if not success then
		cur.state = "error"
		if not cur:raise_notify("error") then
			threading.kill(cur)
		end
		return false
	end

	cur.args = result
	cur.state = "runnable"
	return true
end

function threading.on_context_switch(from, to) end

function threading.context_switch(thr)
	if thr.wchan ~= nil then
		if not thr.wchan() then return false end
		thr.wchan = nil
	end

	threading.on_context_switch(threading.current, thr)
	threading.current = thr
	thr.state = "running"
	thr:raise_notify("run")
	thr:translate_from_caps(thr.args)
	local result = {coroutine.resume(thr.co, table.unpack(thr.args))}
	local success = table.remove(result, 1)
	thr:translate_to_caps(result)
	if coroutine.status(thr.co) == "dead" or not success then
		print('Killing current, coroutine is', coroutine.status(thr.co), 'results were', success, table.unpack(result))
		thr.result = {success, table.unpack(result)}
		threading.kill(thr)
		threading.on_context_switch(threading.current, nil)
		threading.current = nil
		return nil
	end

	thr.result = result
	thr.state = "syscall"

	thr.args = {threading.syscall(table.unpack(result))}

	thr.state = "runnable"
	if thr.wchan ~= nil then
		thr.state = "waiting"
	end
	threading.on_context_switch(threading.current, nil)
	threading.current = nil
	return true
end

function threading.scheduler_round()
	local to_remove = {}
	local one_ran = false

	for thr, _ in pairs(threading.RUNNABLE) do
		local result = threading.context_switch(thr)
		if result == nil then
			to_remove[thr] = true
		else
			one_ran = one_ran or result
		end
	end

	for thr, _ in pairs(to_remove) do
		threading.remove_runnable(thr)
	end

	return one_ran
end

function threading.schedule_until_idle()
	local one_ran
	repeat
		one_ran = threading.scheduler_round()
	until not one_ran
end

function threading.on_idle() end

threading.shutdown = false

function threading.schedule_until_shutdown()
	repeat
		threading.schedule_until_idle()
		threading.on_idle()
	until threading.shutdown
end

function threading.schedule_forever()
	while true do
		threading.schedule_until_idle()
		threading.on_idle()
	end
end

return threading