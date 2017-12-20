local bit32 = {}

local function reduce(seq, f)
	local v = seq[1]
	local i = 2
	while seq[i] ~= nil do
		v = f(v, seq[i])
		i = i + 1
	end
	return v
end

local function and_op(a, b)
	return a & b
end

local function or_op(a, b)
	return a | b
end

local function xor_op(a, b)
	return a ~ b
end

function bit32.band(...)
	return reduce({...}, and_op)
end

function bit32.btest(...)
	return bit32.band(...) ~= 0
end

function bit32.bor(...)
	return reduce({...}, or_op)
end

function bit32.bxor(...)
	return reduce({...}, xor_op)
end

function bit32.bnot(x)
	return ~x
end

function bit32.lshift(a, b)
	return a << b
end

function bit32.rshift(a, b)
	return a >> b
end

function bit32.arshift(a, b)
	local fill = 0
	if a & (1 << 31) ~= 0 then
		fill = ~0
	end
	return (a >> b) | (fill << (32 - b))
end

function bit32.rrotate(a, b)
	return (a >> b) | (a << (32 - b))
end

function bit32.extract(n, field, width)
	if width == nil then width = 1 end
	local msk = (1 << width) - 1
	return (n >> field) & msk
end

function bit32.replace(n, v, field, width)
	if width == nil then width = 1 end
	local msk = ((1 << width) - 1) << field
	return (n & (~msk)) | ((v << field) & msk)
end

return bit32
