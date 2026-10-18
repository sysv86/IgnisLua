local lgi = require("lgi")
local GLib = lgi.GLib

local Spring = {}
Spring.__index = Spring

local EPSILON_POS = 0.0005
local EPSILON_VEL = 0.005

Spring.Tokens = {
    EXPRESSIVE_FAST_SPATIAL    = { damping_ratio = 0.6, stiffness = 800.0,  damping = 33.94, mass = 1.0 },
    EXPRESSIVE_DEFAULT_SPATIAL = { damping_ratio = 0.8, stiffness = 380.0,  damping = 31.18, mass = 1.0 },
    EXPRESSIVE_SLOW_SPATIAL    = { damping_ratio = 0.8, stiffness = 200.0,  damping = 22.63, mass = 1.0 },
    EXPRESSIVE_FAST_EFFECTS    = { damping_ratio = 1.0, stiffness = 3800.0, damping = 123.29, mass = 1.0 },
    EXPRESSIVE_DEFAULT_EFFECTS = { damping_ratio = 1.0, stiffness = 1600.0, damping = 80.00, mass = 1.0 },
    EXPRESSIVE_SLOW_EFFECTS    = { damping_ratio = 1.0, stiffness = 800.0,  damping = 56.57, mass = 1.0 },
    NEIGHBOR_SQUISH            = { damping_ratio = 0.9, stiffness = 1400.0, damping = 67.35, mass = 1.0 },
}

Spring.Presets = {
    EXPRESSIVE_FAST            = Spring.Tokens.EXPRESSIVE_FAST_SPATIAL,
    EXPRESSIVE_DEFAULT         = Spring.Tokens.EXPRESSIVE_DEFAULT_SPATIAL,
    EXPRESSIVE_SLOW            = Spring.Tokens.EXPRESSIVE_SLOW_SPATIAL,
    EXPRESSIVE_FAST_SPATIAL    = Spring.Tokens.EXPRESSIVE_FAST_SPATIAL,
    EXPRESSIVE_DEFAULT_SPATIAL = Spring.Tokens.EXPRESSIVE_DEFAULT_SPATIAL,
    EXPRESSIVE_SLOW_SPATIAL    = Spring.Tokens.EXPRESSIVE_SLOW_SPATIAL,
    EXPRESSIVE_FAST_EFFECTS    = Spring.Tokens.EXPRESSIVE_FAST_EFFECTS,
    EXPRESSIVE_DEFAULT_EFFECTS = Spring.Tokens.EXPRESSIVE_DEFAULT_EFFECTS,
    EXPRESSIVE_SLOW_EFFECTS    = Spring.Tokens.EXPRESSIVE_SLOW_EFFECTS,
    NEIGHBOR_SQUISH            = Spring.Tokens.NEIGHBOR_SQUISH,
    EXPRESSIVE_BOUNCY          = { damping_ratio = 0.45, stiffness = 680.0, damping = 22.0, mass = 0.9 },
    SNAPPY_NO_BOUNCE           = Spring.Tokens.EXPRESSIVE_DEFAULT_EFFECTS,
}

--- Linear interpolation helper
---@param a number
---@param b number
---@param t number
---@return number
function Spring.lerp(a, b, t)
    return a + (b - a) * t
end

--- Exact closed-form analytical solution for a 2nd-order damped harmonic oscillator over `dt`.
--- Unconditionally stable at any frame delta `dt` and any stiffness (even k = 3800).
---@param x0 number
---@param v0 number
---@param target number
---@param damping_ratio number
---@param stiffness number
---@param dt number
---@return number pos, number vel, boolean settled
function Spring.solve(x0, v0, target, damping_ratio, stiffness, dt)
    if dt <= 0.0 then
        return x0, v0, false
    end
    if dt > 0.05 then
        dt = 0.05
    end

    local disp = x0 - target
    if math.abs(disp) < EPSILON_POS and math.abs(v0) < EPSILON_VEL then
        return target, 0.0, true
    end

    local omega_n = math.sqrt(math.max(stiffness, 1.0))
    local zeta = math.max(0.05, math.min(damping_ratio, 2.0))

    local pos, vel
    if zeta < 0.9999 then
        local omega_d = omega_n * math.sqrt(1.0 - zeta * zeta)
        local decay = math.exp(-zeta * omega_n * dt)
        local c1 = disp
        local c2 = (v0 + zeta * omega_n * c1) / omega_d
        local wt = omega_d * dt
        local cos_wt = math.cos(wt)
        local sin_wt = math.sin(wt)
        pos = target + decay * (c1 * cos_wt + c2 * sin_wt)
        vel = decay * (
            (c2 * omega_d - c1 * zeta * omega_n) * cos_wt
            - (c1 * omega_d + c2 * zeta * omega_n) * sin_wt
        )
    else
        local decay = math.exp(-omega_n * dt)
        local c1 = disp
        local c2 = v0 + omega_n * c1
        pos = target + decay * (c1 + c2 * dt)
        vel = decay * (c2 - omega_n * (c1 + c2 * dt))
    end

    if math.abs(pos - target) < EPSILON_POS and math.abs(vel) < EPSILON_VEL then
        return target, 0.0, true
    end
    return pos, vel, false
end

local function compute_damping_ratio(preset)
    if preset.damping_ratio then
        return preset.damping_ratio
    end
    local k = preset.stiffness or 380.0
    local c = preset.damping or 28.0
    local m = preset.mass or 1.0
    return c / (2.0 * math.sqrt(math.max(1.0, k * m)))
end

--- Creates a new frame-synchronized Spring solver bound to a GTK4 widget.
---@param widget table Gtk.Widget (or Ignis widget wrapper)
---@param preset? table { stiffness: number, damping?: number, damping_ratio?: number, mass?: number, initial_value?: number }
---@param on_update? fun(value: number, done: boolean, velocity: number)
---@return table Spring
function Spring.new(widget, preset, on_update)
    preset = preset or Spring.Presets.EXPRESSIVE_DEFAULT
    local self = setmetatable({}, Spring)

    self.widget = (type(widget) == "table" and rawget(widget, "_widget")) or widget
    self.stiffness = (preset.stiffness or 380.0) / (preset.mass or 1.0)
    self.damping = preset.damping or 28.0
    self.mass = preset.mass or 1.0
    self.damping_ratio = compute_damping_ratio(preset)
    self.on_update = on_update or function() end

    self.value = preset.initial_value or 0.0
    self.target = self.value
    self.velocity = 0.0
    self.tick_id = nil
    self.fallback_timer_id = nil
    self.last_time = nil

    return self
end

--- Stops any active tick callback or fallback timer without firing on_update.
function Spring:stop()
    if self.tick_id and self.widget and self.widget.remove_tick_callback then
        pcall(function()
            self.widget:remove_tick_callback(self.tick_id)
        end)
    end
    self.tick_id = nil

    if self.fallback_timer_id then
        pcall(GLib.source_remove, self.fallback_timer_id)
        self.fallback_timer_id = nil
    end
    self.last_time = nil
end

--- Immediately sets the spring value and stops motion.
---@param value number
---@param notify? boolean
function Spring:set_value(value, notify)
    self:stop()
    self.value = value
    self.target = value
    self.velocity = 0.0
    if notify ~= false and self.on_update then
        self.on_update(self.value, true, 0.0)
    end
end

--- Analytical closed-form step
---@param dt number delta time in seconds
---@return boolean finished
function Spring:_step(dt)
    if dt <= 0 or dt > 0.05 then
        dt = 0.008
    end

    local dr = self.damping_ratio or compute_damping_ratio(self)
    local pos, vel, settled = Spring.solve(self.value, self.velocity, self.target, dr, self.stiffness, dt)
    self.value = pos
    self.velocity = vel
    return settled
end

--- Animates the spring toward `target` with optional `initial_velocity`.
---@param target number
---@param initial_velocity? number
function Spring:animate_to(target, initial_velocity)
    self.target = target
    if initial_velocity then
        self.velocity = initial_velocity
    end

    if math.abs(self.value - self.target) < EPSILON_POS and math.abs(self.velocity) < EPSILON_VEL then
        self.value = self.target
        self.velocity = 0.0
        if self.on_update then
            self.on_update(self.value, true, 0.0)
        end
        return
    end

    if self.tick_id or self.fallback_timer_id then
        return
    end

    self.last_time = GLib.get_monotonic_time()

    if self.widget and self.widget.add_tick_callback then
        local ok, id = pcall(function()
            return self.widget:add_tick_callback(function(_, frame_clock)
                local now = (frame_clock and frame_clock.get_frame_time and frame_clock:get_frame_time())
                    or GLib.get_monotonic_time()
                local dt = (now - (self.last_time or now)) / 1000000.0
                self.last_time = now

                local done = self:_step(dt)
                if done then
                    self.tick_id = nil
                    self.on_update(self.value, true, 0.0)
                    return false
                end

                self.on_update(self.value, false, self.velocity)
                return true
            end)
        end)
        if ok and id then
            self.tick_id = id
            return
        end
    end

    self.fallback_timer_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 8, function()
        local now = GLib.get_monotonic_time()
        local dt = (now - (self.last_time or now)) / 1000000.0
        self.last_time = now

        local done = self:_step(dt)
        if done then
            self.fallback_timer_id = nil
            self.on_update(self.value, true, 0.0)
            return false
        end

        self.on_update(self.value, false, self.velocity)
        return true
    end)
end

--- Convenience helper to animate a widget property or callback from `from_val` to `to_val`.
---@param widget table
---@param from_val number
---@param to_val number
---@param preset? table
---@param apply_fn fun(val: number, done: boolean)
---@return table Spring
function Spring.animate(widget, from_val, to_val, preset, apply_fn)
    local s = Spring.new(widget, preset or Spring.Presets.EXPRESSIVE_FAST, function(val, done)
        if apply_fn then
            apply_fn(val, done)
        end
    end)
    s.value = from_val
    s:animate_to(to_val)
    return s
end

return Spring
