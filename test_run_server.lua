local threading = require 'threading'
local libthread = require 'libthread'

local function thread_server(sv)
	print('SV: Starting')
	sv = libthread.SyncChannel.from(sv)
	local kill = libthread.AsyncChannel.new()
	libthread.run_server(sv, {
		req_one = function(a, b)
			print('SV: req_one:', a, b)
			return a+b, a-b
		end,
		req_two = function(c)
			print('SV: req_two:', c)
		end,
		kill = function()
			print('SV: killing')
			kill:set(1)
		end,
	}, kill, 1)
	print('SV: Exiting')
end

local function thread_mon(ac, msk, cond)
	ac = libthread.AsyncChannel.from(ac)
	ac:wait(msk)
	print('MON: detected', cond)
end

local function thread_main()
	print('MAIN: Starting')
	local sc_sv = libthread.SyncChannel.new()
	local sv_dead = libthread.AsyncChannel.new()
	local thr_sv = libthread.Thread.new(thread_server, sc_sv)
	local thr_mon = libthread.Thread.new(thread_mon, sv_dead, 1, 'server death')
	thr_sv:notify_on("death", sv_dead, 1)
	thr_sv:activate()
	thr_mon:activate()
	print('MAIN: Sending requests...')
	print('MAIN: req_one 7 11:', sc_sv("req_one", 7, 11))
	print('MAIN: req_two "foobar":', sc_sv("req_two", "foobar"))
	print('MAIN: kill:', sc_sv("kill"))
	print('MAIN: Exiting')
end

local times = 0
function threading.on_idle()
	print('IDLE', times)
	times = times + 1
	if times >= 5 then threading.shutdown = true end
end

local thr_main = threading.Thread.new(thread_main)
threading.add_runnable(thr_main)
--threading.debug = true
threading.schedule_until_shutdown()
