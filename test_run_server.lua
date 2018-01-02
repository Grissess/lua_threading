local threading = require 'threading'
local libthread = require 'libthread'

local stored_cap = nil
local times = 0
local idle_tick = threading.AsyncChannel.new()

local function thread_server(sv, rev)
	print('SV: Starting')
	sv = libthread.SyncChannel.from(sv)
	rev = libthread.Thread.from(rev)
	local kill = libthread.AsyncChannel.new()
	libthread.run_server(sv, {
		req_one = function(a, b)
			print('SV: req_one:', a, b)
			return a+b, a-b
		end,
		req_two = function(c)
			print('SV: req_two:', c)
		end,
		wait = {async = function(ret, d)
			print('SV: wait:', d)
			local _, cap = rev:grant(ret)
			print('SV: wait: cap is', cap)
			stored_cap = {cap = cap, when = times + 3, next = stored_cap}
		end},
		kill = function()
			print('SV: killing')
			kill:set(1)
		end,
	}, kill, 1)
	print('SV: Exiting')
end

local function thread_revive(tick)
	print('REVIVE: Starting...')
	tick = libthread.AsyncChannel.from(tick)
	while true do
		tick:wait(1)
		print('REVIVE: Running an idle round...')
		tick:unset(1)
		local last = nil
		local cur = stored_cap
		while cur ~= nil do
			if times >= cur.when then
				print('REVIVE: Reviving a thread at t', times, 'with cap sing', cur.cap)
				libthread.SyncChannel.from(cur.cap):write(true)
				if last ~= nil then
					last.next = cur.next
				end
			else
				if last == nil then
					stored_cap = cur
				end
				last = cur
			end
			cur = cur.next
		end
	end
end

local function thread_mon(ac, msk, cond)
	ac = libthread.AsyncChannel.from(ac)
	ac:wait(msk)
	print('MON: detected', cond)
end

local function thread_main(tick)
	print('MAIN: Starting')
	local sc_sv = libthread.SyncChannel.new()
	local sv_dead = libthread.AsyncChannel.new()
	local thr_rev = libthread.Thread.new(thread_revive, tick)
	local thr_sv = libthread.Thread.new(thread_server, sc_sv, thr_rev)
	local thr_mon = libthread.Thread.new(thread_mon, sv_dead, 1, 'server death')
	thr_sv:notify_on("death", sv_dead, 1)
	thr_sv:activate()
	thr_mon:activate()
	thr_rev:activate()
	print('MAIN: Sending requests...')
	print('MAIN: req_one 7 11:', sc_sv("req_one", 7, 11))
	print('MAIN: req_two "foobar":', sc_sv("req_two", "foobar"))
	print('MAIN: wait "ergerg":', sc_sv("wait", "ergerg"))
	print('MAIN: kill:', sc_sv("kill"))
	print('MAIN: Exiting')
end

function threading.on_idle()
	print('IDLE', times)
	idle_tick:set(1)
	times = times + 1
	if times >= 5 then threading.shutdown = true end
end

local thr_main = threading.Thread.new(thread_main, idle_tick)
threading.add_runnable(thr_main)
threading.debug = true
threading.schedule_until_shutdown()
