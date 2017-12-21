local threading = require 'threading'
local libthread = require 'libthread'

local function thread_add(sv)
	print('ADD', 'start')
	sv = libthread.SyncChannel.from(sv)
	while true do
		local ret, a, b = sv:read()
		ret = libthread.SyncChannel.from(ret)
		print('ADD', a, b)
		ret:write(a+b)
	end
end

local function thread_mul(sv)
	print('MUL', 'start')
	sv = libthread.SyncChannel.from(sv)
	while true do
		local ret, a, b = sv:read()
		ret = libthread.SyncChannel.from(ret)
		print('MUL', a, b)
		ret:write(a*b)
	end
end

local function thread_gen_data(cl)
	print('GEN_DATA', 'start')
	cl = libthread.SyncChannel.from(cl)
	for i = 1, 10 do
		local a = math.random(10)
		local b = math.random(10)
		print('GEN_DATA', i, a, b, cl(a, b))
	end
end

local function thread_main()
	print('MAIN', 'starting servers')
	local sc_add = libthread.SyncChannel.new()
	local sc_mul = libthread.SyncChannel.new()
	local thr_add = libthread.Thread.new(thread_add, sc_add)
	local thr_mul = libthread.Thread.new(thread_mul, sc_mul)
	print('MAIN', 'thread singlets are', thr_add.thr, thr_mul.thr)
	thr_add:activate()
	thr_mul:activate()
	print('MAIN', 'starting data generator 1')
	local thr_gen = libthread.Thread.new(thread_gen_data, sc_add)
	local gen_dead = libthread.AsyncChannel.new()
	print('MAIN', 'channel singlet is', gen_dead.ac)
	thr_gen:notify_on("death", gen_dead, 1)
	thr_gen:activate()
	print('MAIN', 'waiting on data generator 1')
	gen_dead:wait(1)
	print('MAIN', 'generator seems dead, results', thr_gen:get_result())
	gen_dead:unset(1)
	print('MAIN', 'starting data generator 2')
	local thr_gen  = libthread.Thread.new(thread_gen_data, sc_mul)
	thr_gen:notify_on("death", gen_dead, 1)
	thr_gen:activate()
	print('MAIN', 'waiting on data generator 2')
	gen_dead:wait(1)
	print('MAIN', 'generator seems dead, results', thr_gen:get_result())
	print('MAIN', 'goodbye!')
end

local main_dead = threading.AsyncChannel.new()
local thr_main
local times = 0
function threading.on_idle()
	print('IDLE', times)
	if main_dead:poll(1) then
		print("Main appears dead, shutting down; results were", table.unpack(thr_main.result))
		threading.shutdown = true
		return
	end
	os.execute('sleep 0.05')
	times = times + 1
	if times >= 5 then threading.shutdown = true end
end

thr_main = threading.Thread.new(thread_main)
thr_main:notify_on("death", main_dead, 1)
threading.add_runnable(thr_main)
threading.schedule_until_shutdown()
