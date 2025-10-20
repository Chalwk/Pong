-- Pong - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_pi = math.pi
local math_sin = math.sin
local math_cos = math.cos
local math_random = math.random
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local Ball = {}
Ball.__index = Ball

function Ball.new(x, y, radius)
    local instance = setmetatable({}, Ball)

    instance.x = x
    instance.y = y
    instance.radius = radius
    instance.speed = 400
    instance.maxSpeed = 800
    instance.minSpeed = 300
    instance.vx = 0
    instance.vy = 0
    instance.baseSpeed = 400
    instance.speedIncrement = 20
    instance.rotation = 0
    instance.rotationSpeed = 0
    instance.trail = {}
    instance.maxTrail = 15
    instance.particles = {}
    instance.glowIntensity = 0
    instance.pulsePhase = math_random() * math_pi * 2
    instance.lastHitTime = 0
    instance.hitFlash = 0
    instance.comboHits = 0
    instance.currentPower = nil
    instance.powerTimer = 0
    instance.multiBalls = {}
    instance.isMainBall = true

    instance.colors = {
        normal = { 1, 1, 1 },
        power = { 0.2, 0.8, 1 },
        speed = { 1, 0.4, 0.2 },
        combo = { 1, 0.8, 0.2 }
    }

    return instance
end

function Ball:reset(x, y)
    self.x = x
    self.y = y
    self.radius = 12
    self.speed = self.baseSpeed
    self.vx = math_random() > 0.5 and self.speed or -self.speed
    self.vy = (math_random() - 0.5) * self.speed * 0.5
    self.rotation = 0
    self.rotationSpeed = 0
    self.trail = {}
    self.particles = {}
    self.comboHits = 0
    self.currentPower = nil
    self.powerTimer = 0
    self.multiBalls = {}
end

function Ball:update(dt)
    self.lastHitTime = self.lastHitTime + dt
    self.hitFlash = math_max(0, self.hitFlash - dt * 10)
    self.pulsePhase = self.pulsePhase + dt * 3

    -- Update position
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Update rotation
    self.rotation = self.rotation + self.rotationSpeed * dt

    -- Update trail
    table_insert(self.trail, {
        x = self.x,
        y = self.y,
        radius = self.radius,
        alpha = 1,
        life = 0.3
    })

    while #self.trail > self.maxTrail do
        table_remove(self.trail, 1)
    end

    -- Update trail particles
    for i = #self.trail, 1, -1 do
        local trail = self.trail[i]
        trail.life = trail.life - dt
        trail.alpha = trail.life / 0.3
        trail.radius = trail.radius * 0.95

        if trail.life <= 0 then
            table_remove(self.trail, i)
        end
    end

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

    -- Add movement particles
    if #self.particles < 5 and math_random() > 0.7 then
        self:createMovementParticle()
    end

    -- Update power-up timer
    if self.currentPower then
        self.powerTimer = self.powerTimer - dt
        if self.powerTimer <= 0 then
            self:clearPower()
        end
    end

    -- Update multi-balls
    for i = #self.multiBalls, 1, -1 do
        local ball = self.multiBalls[i]
        ball:update(dt)
        if ball:isOutOfBounds() then
            table_remove(self.multiBalls, i)
        end
    end
end

function Ball:draw()
    -- Draw trail
    for _, trail in ipairs(self.trail) do
        local color = self:getCurrentColor()
        love.graphics.setColor(color[1], color[2], color[3], trail.alpha * 0.3)
        love.graphics.circle("fill", trail.x, trail.y, trail.radius)
    end

    -- Draw particles
    for _, particle in ipairs(self.particles) do
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end

    -- Draw ball with effects
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)

    local color = self:getCurrentColor()

    -- Outer glow
    local glow = (math_sin(self.pulsePhase) + 1) * 0.3 + self.hitFlash
    love.graphics.setColor(color[1], color[2], color[3], 0.4 + glow * 0.3)
    love.graphics.circle("fill", 0, 0, self.radius * 1.5)

    -- Main ball
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.circle("fill", 0, 0, self.radius)

    -- Inner core
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, self.radius * 0.6)

    -- Highlights
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", -self.radius * 0.3, -self.radius * 0.3, self.radius * 0.2)

    love.graphics.pop()

    -- Draw multi-balls
    for _, ball in ipairs(self.multiBalls) do
        ball:draw()
    end
end

function Ball:getCurrentColor()
    if self.hitFlash > 0 then
        return {1, 0.8, 0.2}
    elseif self.currentPower == "speed" then
        return self.colors.speed
    elseif self.currentPower == "combo" then
        return self.colors.combo
    elseif self.currentPower then
        return self.colors.power
    else
        return self.colors.normal
    end
end

function Ball:createMovementParticle()
    local angle = math_random() * math_pi * 2
    local speed = math_random(10, 30)
    local color = self:getCurrentColor()

    table_insert(self.particles, {
        x = self.x,
        y = self.y,
        dx = math_cos(angle) * speed,
        dy = math_sin(angle) * speed,
        life = math_random(0.3, 0.8),
        maxLife = 0.8,
        size = math_random(1, 3),
        color = { color[1], color[2], color[3] },
        alpha = 1
    })
end

function Ball:createHitParticles(count)
    for _ = 1, count do
        local angle = math_random() * math_pi * 2
        local speed = math_random(50, 150)
        local color = self:getCurrentColor()

        table_insert(self.particles, {
            x = self.x,
            y = self.y,
            dx = math_cos(angle) * speed,
            dy = math_sin(angle) * speed,
            life = math_random(0.5, 1.2),
            maxLife = 1.2,
            size = math_random(2, 5),
            color = { color[1], color[2], color[3] },
            alpha = 1
        })
    end
end

function Ball:handlePaddleHit(paddle, sounds)
    self.lastHitTime = 0
    self.hitFlash = 1
    self.comboHits = self.comboHits + 1

    -- Calculate bounce angle based on hit position
    local hitY = (self.y - paddle.y) / paddle.height
    local maxAngle = math_pi / 3 -- 60 degrees max
    local angle = hitY * maxAngle

    -- Determine direction based on which paddle was hit
    local direction = paddle.isLeft and 1 or -1

    -- Increase speed with each hit
    self.speed = math_min(self.maxSpeed, self.speed + self.speedIncrement)

    -- Set new velocity
    self.vx = direction * self.speed * math_cos(angle)
    self.vy = self.speed * math_sin(angle)

    -- Add spin effect
    self.rotationSpeed = hitY * 10 * direction

    -- Create hit particles
    self:createHitParticles(8)

    -- Play sound
    if sounds and sounds.paddle_hit then
        love.audio.play(sounds.paddle_hit)
    end

    return self.comboHits
end

function Ball:handleWallHit(sounds)
    self.vy = -self.vy
    self.rotationSpeed = -self.rotationSpeed * 0.8
    self:createHitParticles(5)

    if sounds and sounds.wall_hit then
        love.audio.play(sounds.wall_hit)
    end
end

function Ball:applyPower(powerType, duration)
    self.currentPower = powerType
    self.powerTimer = duration

    if powerType == "speed" then
        self.speed = self.speed * 1.5
        self.vx = self.vx * 1.5
        self.vy = self.vy * 1.5
    elseif powerType == "multi" then
        self:createMultiBalls(2)
    end
end

function Ball:clearPower()
    if self.currentPower == "speed" then
        self.speed = self.speed / 1.5
        self.vx = self.vx / 1.5
        self.vy = self.vy / 1.5
    end
    self.currentPower = nil
    self.powerTimer = 0
end

function Ball:createMultiBalls(count)
    for i = 1, count do
        local angle = (i / count) * math_pi * 2
        local multiBall = Ball.new(self.x, self.y, self.radius * 0.7)
        multiBall.isMainBall = false
        multiBall.vx = math_cos(angle) * self.speed * 0.8
        multiBall.vy = math_sin(angle) * self.speed * 0.8
        multiBall.speed = self.speed * 0.8
        table_insert(self.multiBalls, multiBall)
    end
end

function Ball:isOutOfBounds()
    return self.x < -100 or self.x > 1300 or self.y < -100 or self.y > 900
end

function Ball:resetCombo()
    self.comboHits = 0
end

return Ball