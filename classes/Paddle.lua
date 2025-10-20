-- Pong - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local table_insert = table.insert
local table_remove = table.remove

local Paddle = {}
Paddle.__index = Paddle

function Paddle.new(x, y, width, height, isLeft)
    local instance = setmetatable({}, Paddle)

    instance.x = x
    instance.y = y
    instance.width = width
    instance.height = height
    instance.speed = 500
    instance.targetY = y
    instance.isLeft = isLeft
    instance.score = 0
    instance.combo = 0
    instance.maxCombo = 0
    instance.powerUps = {}
    instance.particles = {}
    instance.glowIntensity = 0
    instance.pulsePhase = 0
    instance.hitFlash = 0
    instance.lastHitTime = 0
    instance.energy = 100
    instance.maxEnergy = 100
    instance.energyRechargeRate = 10

    instance.colors = {
        normal = isLeft and {0.2, 0.6, 1} or {1, 0.3, 0.3},
        power = {0.8, 0.2, 1},
        energy = {0.2, 0.8, 0.2}
    }

    return instance
end

function Paddle:update(dt, ball, screenHeight)
    -- Update position with smooth movement
    local dy = self.targetY - self.y
    self.y = self.y + dy * 8 * dt

    -- Keep paddle within bounds
    self.y = math_max(self.height/2, math_min(screenHeight - self.height/2, self.y))

    -- Update energy
    self.energy = math_min(self.maxEnergy, self.energy + self.energyRechargeRate * dt)

    -- Update particles
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.dx * dt
        particle.y = particle.y + particle.dy * dt
        particle.alpha = particle.life / particle.maxLife

        if particle.life <= 0 then
            table_remove(self.particles, i)
        end
    end

    -- Update glow and pulse
    self.pulsePhase = self.pulsePhase + dt * 2
    self.glowIntensity = math_max(0, self.glowIntensity - dt * 3)
    self.hitFlash = math_max(0, self.hitFlash - dt * 5)
    self.lastHitTime = self.lastHitTime + dt

    -- Add energy particles when recharging
    if self.energy < self.maxEnergy and math.random() > 0.8 then
        self:createEnergyParticle()
    end
end

function Paddle:draw()
    local color = self:getCurrentColor()

    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    -- Outer glow
    local glow = (math_sin(self.pulsePhase) + 1) * 0.2 + self.glowIntensity + self.hitFlash
    love.graphics.setColor(color[1], color[2], color[3], 0.3 + glow * 0.2)
    love.graphics.rectangle("fill", -self.width/2 - 5, -self.height/2 - 5,
                          self.width + 10, self.height + 10, 5, 5)

    -- Main paddle
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.rectangle("fill", -self.width/2, -self.height/2, self.width, self.height, 3, 3)

    -- Inner highlight
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("fill", -self.width/2 + 2, -self.height/2 + 2,
                          self.width - 4, self.height - 4, 2, 2)

    -- Energy core
    if self.energy > 0 then
        local energyHeight = (self.height - 8) * (self.energy / self.maxEnergy)
        love.graphics.setColor(self.colors.energy[1], self.colors.energy[2],
                             self.colors.energy[3], 0.7)
        love.graphics.rectangle("fill", -self.width/2 + 3, -energyHeight/2,
                              self.width - 6, energyHeight, 1, 1)
    end

    love.graphics.pop()

    -- Draw particles
    for _, particle in ipairs(self.particles) do
        love.graphics.setColor(particle.color[1], particle.color[2],
                             particle.color[3], particle.alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end

    -- Draw combo indicator
    if self.combo > 1 then
        self:drawComboIndicator()
    end
end

function Paddle:getCurrentColor()
    if self.hitFlash > 0 then
        return {1, 1, 0.8}
    elseif #self.powerUps > 0 then
        return self.colors.power
    else
        return self.colors.normal
    end
end

function Paddle:drawComboIndicator()
    local x = self.isLeft and 100 or (love.graphics.getWidth() - 100)
    local y = 150

    love.graphics.setColor(1, 0.8, 0.2, 0.8)
    love.graphics.print("COMBO x" .. self.combo, x - 40, y)

    -- Combo meter
    local meterWidth = 80
    local meterHeight = 6
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("fill", x - meterWidth/2, y + 25, meterWidth, meterHeight)
    love.graphics.setColor(1, 0.8, 0.2, 0.8)
    local comboProgress = math_min(1, self.lastHitTime / 3)
    love.graphics.rectangle("fill", x - meterWidth/2, y + 25, meterWidth * (1 - comboProgress), meterHeight)
end

function Paddle:createEnergyParticle()
    local side = self.isLeft and 1 or -1
    local x = self.x + side * self.width/2
    local y = self.y + (math.random() - 0.5) * self.height * 0.8

    table_insert(self.particles, {
        x = x,
        y = y,
        dx = side * math.random(20, 50),
        dy = (math.random() - 0.5) * 20,
        life = math.random(0.5, 1.0),
        maxLife = 1.0,
        size = math.random(2, 4),
        color = {self.colors.energy[1], self.colors.energy[2], self.colors.energy[3]},
        alpha = 1
    })
end

function Paddle:createHitParticles()
    local side = self.isLeft and 1 or -1
    for _ = 1, 6 do
        local x = self.x + side * self.width/2
        local y = self.y + (math.random() - 0.5) * self.height * 0.9

        table_insert(self.particles, {
            x = x,
            y = y,
            dx = side * math.random(30, 80),
            dy = (math.random() - 0.5) * 40,
            life = math.random(0.3, 0.7),
            maxLife = 0.7,
            size = math.random(2, 5),
            color = {1, 1, 0.8},
            alpha = 1
        })
    end
end

function Paddle:moveUp(dt)
    self.targetY = self.targetY - self.speed * dt
end

function Paddle:moveDown(dt)
    self.targetY = self.targetY + self.speed * dt
end

function Paddle:setTargetY(y)
    self.targetY = y
end

function Paddle:onBallHit(ball, sounds)
    self.lastHitTime = 0
    self.hitFlash = 1
    self.glowIntensity = 1
    self.combo = self.combo + 1
    self.maxCombo = math_max(self.maxCombo, self.combo)

    -- Use energy on hit
    self.energy = math_max(0, self.energy - 5)

    self:createHitParticles()

    if sounds and sounds.paddle_hit then
        love.audio.play(sounds.paddle_hit)
    end
end

function Paddle:resetCombo()
    self.combo = 0
end

function Paddle:addPowerUp(powerUp)
    table_insert(self.powerUps, powerUp)
end

function Paddle:usePowerUp(powerType)
    for i, powerUp in ipairs(self.powerUps) do
        if powerUp.type == powerType then
            table_remove(self.powerUps, i)
            return true
        end
    end
    return false
end

function Paddle:hasPower(powerType)
    for _, powerUp in ipairs(self.powerUps) do
        if powerUp.type == powerType then
            return true
        end
    end
    return false
end

return Paddle
