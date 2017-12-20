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

function libthread.ac_wait(async, msk)
	return coroutine.yield("ac_wait", async, msk)
end

local Thread = {}
libthread.Thread = Thread

function Thread.new(f, ...)
	return setmetatable({thr = libthread.new_thr(f, ...)}, Thread.mt)
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
	return libthread.thr_set_args(self.thr, ...)
end

function Thread:get_args()
	return libthread.thr_get_args(self.thr)
end

function Thread:get_result()
	return libthread.thr_get_result(self.thr)
end

function Thread:notify_on(ev, ac, v)
	return libthread.thr_notify_on(self.thr, ev, ac, v)
end

function Thread:kill()
	return libthread.thr_kill(self.thr)
end

Thread.mt = {
	__index = Thread,
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
	return libthread.sc_write(self.sc, ...)
end

function SyncChannel:read()
	return libthread.sc_read(self.sc)
end

SyncChannel.mt = {
	__index = SyncChannel,
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

function AsyncChannel:wait(msk)
	return libthread.ac_wait(self.ac, msk)
end

AsyncChannel.mt = {
	__index = AsyncChannel,
}

return libthread
