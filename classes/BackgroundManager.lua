-- Pong - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_pi = math.pi
local math_sin = math.sin
local math_cos = math.cos
local math_random = math.random
local table_insert = table.insert

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)
    instance.particles = {}
    instance.neonGrid = {}
    instance.time = 0
    instance:initParticles()
    instance:initNeonGrid()
    return instance
end

function BackgroundManager:initParticles()
    self.particles = {}
    for _ = 1, 80 do
        table_insert(self.particles, {
            x = math_random() * 1200,
            y = math_random() * 800,
            size = math_random(2, 6),
            speed = math_random(20, 60),
            angle = math_random() * math_pi * 2,
            pulseSpeed = math_random(0.5, 2),
            pulsePhase = math_random() * math_pi * 2,
            type = math_random(1, 3),
            life = math_random(5, 15),
            maxLife = math_random(5, 15),
            color = {
                math_random(0.7, 1.0),
                math_random(0.7, 1.0),
                math_random(0.8, 1.0)
            }
        })
    end
end

function BackgroundManager:initNeonGrid()
    self.neonGrid = {}
    local gridSize = 40
    for x = 0, 1200, gridSize do
        for y = 0, 800, gridSize do
            if math_random() > 0.7 then
                table_insert(self.neonGrid, {
                    x = x,
                    y = y,
                    pulsePhase = math_random() * math_pi * 2,
                    pulseSpeed = math_random(0.1, 0.5),
                    active = math_random() > 0.3
                })
            end
        end
    end
end

function BackgroundManager:update(dt)
    self.time = self.time + dt

    -- Update particles
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.life = particle.life - dt

        if particle.life <= 0 then
            table.remove(self.particles, i)
        else
            particle.x = particle.x + math_cos(particle.angle) * particle.speed * dt
            particle.y = particle.y + math_sin(particle.angle) * particle.speed * dt

            if particle.x < -100 then particle.x = 1300 end
            if particle.x > 1300 then particle.x = -100 end
            if particle.y < -100 then particle.y = 900 end
            if particle.y > 900 then particle.y = -100 end
        end
    end

    -- Add new particles
    while #self.particles < 80 do
        table_insert(self.particles, {
            x = math_random() * 1200,
            y = -50,
            size = math_random(2, 6),
            speed = math_random(20, 60),
            angle = math_random(0.2, 0.8) * math_pi,
            pulseSpeed = math_random(0.5, 2),
            pulsePhase = math_random() * math_pi * 2,
            type = math_random(1, 3),
            life = math_random(5, 15),
            maxLife = math_random(5, 15),
            color = {
                math_random(0.7, 1.0),
                math_random(0.7, 1.0),
                math_random(0.8, 1.0)
            }
        })
    end

    -- Update neon grid
    for _, node in ipairs(self.neonGrid) do
        node.pulsePhase = node.pulsePhase + node.pulseSpeed * dt
        if node.pulsePhase > math_pi * 2 then
            node.pulsePhase = 0
            node.active = math_random() > 0.4
        end
    end
end

function BackgroundManager:draw(screenWidth, screenHeight, gameState)
    local time = love.timer.getTime()

    -- Cyber gradient background
    for y = 0, screenHeight, 2 do
        local progress = y / screenHeight
        local pulse = (math_sin(time * 0.5 + progress * 3) + 1) * 0.03

        local r = 0.05 + progress * 0.05 + pulse
        local g = 0.02 + progress * 0.08 + pulse * 0.3
        local b = 0.1 + progress * 0.15 + pulse

        love.graphics.setColor(r, g, b, 0.9)
        love.graphics.line(0, y, screenWidth, y)
    end

    -- Neon grid
    love.graphics.setLineWidth(1)
    for _, node in ipairs(self.neonGrid) do
        if node.active then
            local alpha = (math_sin(node.pulsePhase) + 1) * 0.2
            love.graphics.setColor(0.1, 0.6, 1, alpha)
            love.graphics.points(node.x, node.y)
        end
    end

    -- Particles
    for _, particle in ipairs(self.particles) do
        local lifeProgress = particle.life / particle.maxLife
        local pulse = (math_sin(particle.pulsePhase + time * particle.pulseSpeed) + 1) * 0.5
        local currentSize = particle.size * (0.7 + pulse * 0.3)
        local alpha = lifeProgress * (0.4 + pulse * 0.3)

        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)

        if particle.type == 1 then
            love.graphics.circle("fill", particle.x, particle.y, currentSize)
        elseif particle.type == 2 then
            love.graphics.rectangle("fill", particle.x - currentSize, particle.y - currentSize,
                                  currentSize * 2, currentSize * 2)
        else
            self:drawTriangle(particle.x, particle.y, currentSize)
        end
    end

    -- Central arena glow
    love.graphics.setColor(0.1, 0.3, 0.6, 0.1)
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    local arenaWidth = screenWidth * 0.8
    local arenaHeight = screenHeight * 0.7

    self:drawArenaGlow(centerX, centerY, arenaWidth, arenaHeight, time)
end

function BackgroundManager:drawTriangle(x, y, size)
    love.graphics.polygon("fill",
        x, y - size,
        x - size, y + size,
        x + size, y + size
    )
end

function BackgroundManager:drawArenaGlow(centerX, centerY, width, height, time)
    local pulse = math_sin(time * 0.8) * 0.1 + 0.9

    love.graphics.push()
    love.graphics.translate(centerX, centerY)

    -- Outer glow
    love.graphics.setColor(0.1, 0.4, 0.8, 0.05)
    for i = 1, 3 do
        local scale = pulse + i * 0.1
        love.graphics.rectangle("line", -width/2 * scale, -height/2 * scale, width * scale, height * scale)
    end

    -- Inner grid
    love.graphics.setColor(0.2, 0.5, 0.9, 0.1)
    love.graphics.setLineWidth(1)
    for i = -2, 2 do
        local offset = i * 50
        love.graphics.line(-width/2, offset, width/2, offset)
        love.graphics.line(offset, -height/2, offset, height/2)
    end

    love.graphics.pop()
end

return BackgroundManager