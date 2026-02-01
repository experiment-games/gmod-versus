---@class VersusUnit
---@field directoryName string The directory name the unit is in
---@field fullPath string The full path to the directory the unit is in
---@field path string The relative path to the unit
---@field hook table<string,function> All hooks to bind
local unitMeta = {}
unitMeta.__index = unitMeta

function unitMeta:init(unitGlobal)
  self.unitGlobal = unitGlobal
  self.hook = {}

  return self
end

function unitMeta:reset()
  -- ! Only functions and hooks can safely be reset, tables may be added at
  -- ! runtime and removing them may have undesired effects
  for member, value in pairs(self) do
    if (isfunction(value)) then
      self[member] = nil
    end
  end

  for eventName, callback in pairs(self.hook) do
    hook.Remove(eventName, self)
    self.hook[eventName] = nil
  end
end

function unitMeta:IsValid()
  return true
end

function unitMeta:registerHooks()
  for eventName, callback in pairs(self.hook) do
    -- Call hook callbacks in a protected manner so one unit doesn't break all others
    hook.Add(eventName, self, function(...)
      --[[
				The code below (a, b, c ... x, y, z) may look insane, but it
				works a lot faster and imo cleaner than the alternative (I
				haven't benchmarked this, but looking at the code I'm 99% sure
				it's faster):
						local getReturnValues = function(...)
							local countValues = select("#", ...)
							local tbl = { ... }
							return countValues, tbl
						end
						local count, returnValues = getReturnValues(2, pcall(callback, ...))
						if(returnValues[1])then -- success
							return unpack(returnValues, 2) -- Return all axcept the success value from pcall
						end
			--]]
      local success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z = xpcall(
        callback,
        function(errorMessage)
          ErrorNoHaltWithStack(
            string.format(
              "[%s %q] %s Hook Failed! Error: %q\n",
              self.unitGlobal,
              self.path,
              eventName,
              errorMessage
            )
          )
        end,
        ...
      )

      if (not success) then
        return
      end

      -- Because it's susceptible to bugs we do a sanity check to help
      -- us recognize hooks which return more than 23 varargs (seems
      -- like bad design, just return a table if you must)
      if (x ~= nil or y ~= nil or z ~= nil) then
        ErrorNoHaltWithStack(
          string.format(
            "[%s %q] %s Warning! Hook has unreasonable varargs count! Expect bugs.\n",
            self.unitGlobal,
            self.path,
            eventName
          )
        )
        print(success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z)
      end

      return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w
    end)
  end
end

debug.getregistry()["VersusUnit"] = unitMeta
