local threading = require 'threading'
local libthread = require 'libthread'

local function thread_echo(times, recv, send)
	print('ECHO', 'hi! my real arguments are', times, recv, send)
	recv = libthread.SyncChannel.from(recv)
	send = libthread.SyncChannel.from(send)
	repeat
		local values = {recv:read()}
		print('ECHO', times, table.unpack(values))
		send:write(table.unpack(values))
		times = times - 1
	until times <= 0
end

local function thread_send(send, val)
	send = libthread.SyncChannel.from(send)
	while true do
		print('SEND', 'sending', val)
		send:write(val)
		print('SEND', 'sent', val)
		val = val + 1
	end
end

local function thread_recv(recv)
	recv = libthread.SyncChannel.from(recv)
	while true do
		print('RECV', 'receiving')
		local val = recv:read()
		print('RECV', 'received', val)
	end
end

local ts

local function thread_mon(ac)
	ac = libthread.AsyncChannel.from(ac)
	while true do
		print('MON', 'waiting')
		local val = ac:wait(65535)
		print('MON', 'thread', val, 'appears to have died! Results were', table.unpack(ts[val].result))
		ac:unset(65535)
	end
end

local sc1 = threading.SyncChannel.new()
local sc2 = threading.SyncChannel.new()
local ac1 = threading.AsyncChannel.new()
local t1 = threading.Thread.new(thread_send, sc1, 7)
local t2 = threading.Thread.new(thread_echo, 5, sc1, sc2)
local t3 = threading.Thread.new(thread_recv, sc2)
local t4 = threading.Thread.new(thread_mon, ac1)

ts = {t1, t2, t3, t4}

local times = 0
function threading.on_idle()
	print('IDLE', times)
	--for i, t in ipairs(ts) do
	--	print('THREAD', i, 'IS', t, 'STATE', t.state, 'WCHAN', t.wchan)
	--end
	--print('CURRENT', threading.current)
	os.execute('sleep 0.05')
	times = times + 1
	if times >= 5 then threading.shutdown = true end
end


for i, t in ipairs(ts) do
	threading.add_runnable(t)
	t:notify_on("death", ac1, i)
end

threading.schedule_until_shutdown()
