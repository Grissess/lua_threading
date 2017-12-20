local singlet = {}

local function nop() end

singlet.SINGLET_OBJECT = setmetatable({}, {__newindex = nop, __metatable = true})

local _singlet_ids = setmetatable({}, {__mode = "k"})

singlet.mt = {
	__newindex = nop,
	__metatable = singlet.SINGLET_OBJECT,
	__tostring = function(self)
		return '<singlet ' .. _singlet_ids[self] .. '>'
	end
}

function singlet.new()
	local res = {}
	_singlet_ids[res] = tostring(res)
	return setmetatable(res, singlet.mt)
end

return singlet
