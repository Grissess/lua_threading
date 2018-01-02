local libthread = {}

function libthread.yield()
	return coroutine.yield("yield")
end

function libthread.new_thr(f, ...)
	return coroutine.yield("new_thr", f, ...)
end

function libthread.thr_activate(thr)
	return coroutine.yield("thr_activate", thr)
end

function libthread.thr_suspend(thr)
	return coroutine.yield("thr_suspend", thr)
end

function libthread.thr_set_args(thr, ...)
	return coroutine.yield("thr_set_args", thr, ...)
end

function libthread.thr_get_args(thr)
	return coroutine.yield("thr_get_args", thr)
end

function libthread.thr_get_result(thr)
	return coroutine.yield("thr_get_result", thr)
end

function libthread.thr_notify_on(thr, ev, ac, v)
	return coroutine.yield("thr_notify_on", thr, ev, ac, v)
end

function libthread.thr_set_cancel(thr, ac, v)
	return coroutine.yield("thr_set_cancel", thr, ac, v)
end

function libthread.thr_kill(thr)
	return coroutine.yield("thr_kill", thr)
end

function libthread.thr_current()
	return coroutine.yield("thr_current")
end

function libthread.new_sc()
	return coroutine.yield("new_sc")
end

function libthread.sc_write(sync, ...)
	return coroutine.yield("sc_write", sync, ...)
end

function libthread.sc_read(sync)
	return coroutine.yield("sc_read", sync)
end

function libthread.sc_badged(sync, ...)
	return coroutine.yield("sc_badged", sync, ...)
end

function libthread.sc_poll_read(sync)
	return coroutine.yield("sc_poll_read", sync)
end

function libthread.sc_poll_write(sync)
	return coroutine.yield("sc_poll_write", sync)
end

function libthread.new_ac()
	return coroutine.yield("new_ac")
end

function libthread.ac_set(async, v)
	return coroutine.yield("ac_set", async, v)
end

function libthread.ac_unset(async, v)
	return coroutine.yield("ac_unset", async, v)
end

function libthread.ac_get(async)
	return coroutine.yield("ac_get", async)
end

function libthread.ac_poll(async, msk)
	return coroutine.yield("ac_poll", async, msk)
end

function libthread.ac_wait(async, msk)
	return coroutine.yield("ac_wait", async, msk)
end

function libthread.convert_value(v)
	local mt = getmetatable(v)
	if mt ~= "nil" and type(mt) == "table" and mt.sys_convert ~= nil then
		return mt.sys_convert(v)
	end
	return v
end

function libthread.convert_all_args(args)
	for i, v in ipairs(args) do
		args[i] = libthread.convert_value(v)
	end
end

local Thread = {}
libthread.Thread = Thread

function Thread.new(f, ...)
	local args = {...}
	libthread.convert_all_args(args)
	return setmetatable({thr = libthread.new_thr(f, table.unpack(args))}, Thread.mt)
end

function Thread.current()
	return setmetatable({thr = libthread.thr_current()}, Thread.mt)
end

function Thread.from(thr)
	return setmetatable({thr = thr}, Thread.mt)
end

function Thread:activate()
	return libthread.thr_activate(self.thr)
end

function Thread:suspend()
	return libthread.thr_suspend(self.thr)
end

function Thread:set_args(...)
	local args = {...}
	libthread.convert_all_args(args)
	return libthread.thr_set_args(self.thr, table.unpack(args))
end

function Thread:get_args()
	return libthread.thr_get_args(self.thr)
end

function Thread:get_result()
	return libthread.thr_get_result(self.thr)
end

function Thread:notify_on(ev, ac, v)
	return libthread.thr_notify_on(self.thr, ev, libthread.convert_value(ac), v)
end

function Thread:set_cancel(ac, v)
	return libthread.thr_set_cancel(self.thr, libthread.convert_value(ac), v)
end

function Thread:kill()
	return libthread.thr_kill(self.thr)
end

Thread.mt = {
	__index = Thread,
	sys_convert = function(self) return self.thr end,
}

local SyncChannel = {}
libthread.SyncChannel = SyncChannel

function SyncChannel.new()
	return setmetatable({sc = libthread.new_sc()}, SyncChannel.mt)
end

function SyncChannel.from(sc)
	return setmetatable({sc = sc}, SyncChannel.mt)
end

function SyncChannel:write(...)
	local args = {...}
	libthread.convert_all_args(args)
	return libthread.sc_write(self.sc, table.unpack(args))
end

function SyncChannel:read()
	return libthread.sc_read(self.sc)
end

function SyncChannel:badged(...)
	local args = {...}
	libthread.convert_all_args(args)
	return SyncChannel.from(libthread.sc_badged(self.sc, table.unpack(args)))
end

function SyncChannel:poll_read()
	return libthread.sc_poll_read(self.sc)
end

function SyncChannel:poll_write()
	return libthread.sc_poll_write(self.sc)
end

function SyncChannel:call(...)
	local ret = SyncChannel.new()
	self:write(ret, ...)
	return ret:read()
end

SyncChannel.mt = {
	__index = SyncChannel,
	__call = SyncChannel.call,
	sys_convert = function(self) return self.sc end,
}

local AsyncChannel = {}
libthread.AsyncChannel = AsyncChannel

function AsyncChannel.new()
	return setmetatable({ac = libthread.new_ac()}, AsyncChannel.mt)
end

function AsyncChannel.from(ac)
	return setmetatable({ac = ac}, AsyncChannel.mt)
end

function AsyncChannel:set(v)
	return libthread.ac_set(self.ac, v)
end

function AsyncChannel:unset(v)
	return libthread.ac_unset(self.ac, v)
end

function AsyncChannel:get()
	return libthread.ac_get(self.ac)
end

function AsyncChannel:poll(msk)
	return libthread.ac_poll(self.ac, msk)
end

function AsyncChannel:wait(msk)
	return libthread.ac_wait(self.ac, msk)
end

AsyncChannel.mt = {
	__index = AsyncChannel,
	sys_convert = function(self) return self.ac end,
}

function libthread.run_server(sv, handlers, ac, msk)
	local hdl
	if type(handlers) == "function" then
		hdl = handlers
	elseif type(handlers) == "table" then
		hdl = function(req, ...)
			local f = handlers[req]
			if f == nil or type(f) ~= "function" then
				return
			end
			return f(...)
		end
	else
		error("Inappropriate handler type: " .. type(handlers))
	end

	while (ac == nil) or (not ac:poll(msk)) do
		local values = {sv:read()}
		if #values > 0 then
			local ret = table.remove(values, 1)
			if type(ret) == "table" then
				ret = SyncChannel.from(ret)
				ret:write(hdl(table.unpack(values)))
			end
		end
	end
end

return libthread
