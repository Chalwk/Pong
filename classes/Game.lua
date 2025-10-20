-- Pong - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove
local string_format = string.format

local Ball = require("classes/Ball")
local Paddle = require("classes/Paddle")

local sounds = {}

local Game = {}
Game.__index = Game

function Game.new()
    local instance = setmetatable({}, Game)

    instance.screenWidth = 1200
    instance.screenHeight = 800
    instance.ball = nil
    instance.leftPaddle = nil
    instance.rightPaddle = nil
    instance.gameMode = "single"   -- single, multi, ai
    instance.difficulty = "medium" -- easy, medium, hard
    instance.scoreToWin = 11
    instance.gameOver = false
    instance.winner = nil
    instance.paused = false
    instance.powerUps = {}
    instance.particles = {}
    instance.animations = {}
    instance.sounds = {}
    instance.countdown = 0
    instance.countdownActive = false
    instance.message = ""
    instance.messageTimer = 0
    instance.comboMultiplier = 1
    instance.keysPressed = {}

    -- AI difficulty settings
    instance.aiSettings = {
        easy = {
            reactionTime = 0.2,
            accuracy = 0.7,
            prediction = 0.6,
            maxSpeed = 600 -- Increased from 400
        },
        medium = {
            reactionTime = 0.1,
            accuracy = 0.85,
            prediction = 0.8,
            maxSpeed = 800 -- Increased from 550
        },
        hard = {
            reactionTime = 0.05,
            accuracy = 0.95,
            prediction = 0.95,
            maxSpeed = 1200 -- Increased from 700
        }
    }

    -- Power-up types
    instance.powerUpTypes = {
        { type = "speed",  duration = 5,  color = { 1, 0.4, 0.2 },   rarity = 2 },
        { type = "multi",  duration = 0,  color = { 0.8, 0.2, 1 },   rarity = 1 },
        { type = "expand", duration = 8,  color = { 0.2, 0.8, 0.4 }, rarity = 3 },
        { type = "shrink", duration = 6,  color = { 1, 0.2, 0.2 },   rarity = 3 },
        { type = "combo",  duration = 10, color = { 1, 0.8, 0.2 },   rarity = 2 }
    }

    -- Load sounds
    sounds.paddle_hit = love.audio.newSource("assets/sounds/paddle_hit.mp3", "static")
    sounds.wall_hit = love.audio.newSource("assets/sounds/wall_hit.mp3", "static")
    sounds.score = love.audio.newSource("assets/sounds/score.mp3", "static")
    sounds.power_up = love.audio.newSource("assets/sounds/power_up.mp3", "static")
    sounds.background = love.audio.newSource("assets/sounds/background.mp3", "stream")

    if sounds.background then
        sounds.background:setLooping(true)
        sounds.background:setVolume(0.3)
        love.audio.play(sounds.background)
    end

    return instance
end

function Game:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self:resetGame()
end

function Game:startNewGame(gameMode, difficulty)
    self.gameMode = gameMode or "single"
    self.difficulty = difficulty or "medium"
    self.gameOver = false
    self.winner = nil
    self.paused = false
    self.powerUps = {}
    self.particles = {}
    self.animations = {}
    self.countdown = 3
    self.countdownActive = true
    self.message = ""
    self.messageTimer = 0
    self.comboMultiplier = 1

    -- Create paddles
    local paddleWidth = 20
    local paddleHeight = 120
    local paddleMargin = 50

    self.leftPaddle = Paddle.new(
        paddleMargin,
        self.screenHeight / 2,
        paddleWidth,
        paddleHeight,
        true
    )

    self.rightPaddle = Paddle.new(
        self.screenWidth - paddleMargin,
        self.screenHeight / 2,
        paddleWidth,
        paddleHeight,
        false
    )

    -- Create ball
    self.ball = Ball.new(self.screenWidth / 2, self.screenHeight / 2, 12)
    self.ball:reset(self.screenWidth / 2, self.screenHeight / 2)

    -- Start countdown
    self:startCountdown()
end

function Game:startCountdown()
    self.countdown = 3
    self.countdownActive = true
    self.paused = true

    -- Remove any existing countdown animations
    for i = #self.animations, 1, -1 do
        if self.animations[i].type == "countdown" then
            table_remove(self.animations, i)
        end
    end

    self.countdownTimer = 0
end

function Game:update(dt)
    -- Always update animations and message timer, even when paused
    self:updateAnimations(dt)

    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - dt
        if self.messageTimer <= 0 then
            self.message = ""
        end
    end

    -- Update countdown
    if self.countdownActive then
        self.countdownTimer = self.countdownTimer + dt
        if self.countdownTimer >= 1 then
            self.countdownTimer = 0
            self.countdown = self.countdown - 1
            if self.countdown <= 0 then
                self.countdownActive = false
                self.paused = false
                self.ball:reset(self.screenWidth / 2, self.screenHeight / 2)
            end
        end
    end

    if self.paused or self.gameOver then return end

    -- Handle continuous key movement
    self:handleContinuousMovement(dt)

    -- Update ball
    self.ball:update(dt)

    -- Update paddles
    self.leftPaddle:update(dt, self.ball, self.screenHeight)
    self.rightPaddle:update(dt, self.ball, self.screenHeight)

    -- Update AI if in single player mode
    if self.gameMode == "single" then
        if self:shouldAIReact() then
            self:updateAI(dt)
        else
            -- When not actively tracking, slowly return to center
            local centerY = self.screenHeight / 2
            if math.abs(self.rightPaddle.y - centerY) > 20 then
                local move = (centerY - self.rightPaddle.y) * 0.1
                self.rightPaddle:setTargetY(self.rightPaddle.y + move)
            end
        end
    end

    -- Update power-ups
    self:updatePowerUps(dt)

    -- Update particles
    self:updateParticles(dt)

    -- Check collisions
    self:checkCollisions()

    -- Check for score
    self:checkScore()

    -- Spawn power-ups randomly
    if math_random() < 0.002 then -- 0.2% chance per frame
        self:spawnPowerUp()
    end
end

function Game:shouldAIReact()
    -- AI should always react when ball is on its side
    if self.ball.x > self.screenWidth / 2 then
        return true
    end

    -- React when ball is moving toward AI side
    if self.ball.vx > 0 then
        return true
    end

    -- Occasionally prepare when ball is on opponent side but coming back
    if self.ball.x < self.screenWidth / 2 and self.ball.vx < -200 then
        return math_random() < 0.3
    end

    return false
end

function Game:updateAI(dt)
    local aiSettings = self.aiSettings[self.difficulty]
    if not aiSettings then return end

    -- Always track the ball, not just when it's coming toward AI
    local targetY = self.ball.y

    -- Predict ball position based on trajectory
    if self.ball.vx > 0 then -- Ball is moving toward AI
        local timeToReach = (self.screenWidth - self.rightPaddle.x - self.ball.radius) / math_abs(self.ball.vx)
        targetY = self.ball.y + (self.ball.vy * timeToReach)

        -- Account for wall bounces in prediction
        while targetY < 0 or targetY > self.screenHeight do
            if targetY < 0 then
                targetY = -targetY
            else
                targetY = 2 * self.screenHeight - targetY
            end
        end
    end

    -- Add difficulty-based imperfections
    local accuracy = aiSettings.accuracy
    local maxError = (1 - accuracy) * 100
    local randomError = (math_random() - 0.5) * maxError
    targetY = targetY + randomError

    -- Calculate how far to move
    local currentY = self.rightPaddle.y
    local distanceToTarget = targetY - currentY

    -- FIXED: Use direct movement based on difficulty settings
    local moveSpeed = aiSettings.maxSpeed

    -- Only move if we're not already close to the target
    if math_abs(distanceToTarget) > 10 then
        -- Calculate movement direction
        local moveDirection = distanceToTarget > 0 and 1 or -1

        -- Calculate movement amount based on difficulty
        local baseMoveAmount = moveSpeed * dt

        -- Adjust movement based on distance (move faster when farther away)
        local distanceFactor = math_min(math_abs(distanceToTarget) / 100, 2.0)
        local moveAmount = baseMoveAmount * distanceFactor

        -- Apply movement
        local newY = currentY + (moveDirection * moveAmount)

        -- Keep paddle within bounds
        newY = math_max(
            self.rightPaddle.height / 2 + 10,
            math_min(self.screenHeight - self.rightPaddle.height / 2 - 10, newY)
        )

        self.rightPaddle.y = newY
        self.rightPaddle.targetY = newY -- Keep target in sync
    end
end

function Game:improveAIPlayability()
    -- Add occasional hesitation on easy mode
    if self.difficulty == "easy" and math_random() < 0.05 then
        return true -- Skip AI update occasionally
    end

    -- Don't react to very slow balls that are moving away
    if self.ball.vx < -200 and math_abs(self.ball.vx) < 100 then
        return true
    end

    return false
end

function Game:updatePowerUps(dt)
    for i = #self.powerUps, 1, -1 do
        local powerUp = self.powerUps[i]
        powerUp.timer = powerUp.timer - dt

        if powerUp.timer <= 0 then
            table_remove(self.powerUps, i)
        else
            -- Float animation
            powerUp.y = powerUp.y + math_sin(powerUp.pulsePhase) * 2 * dt
            powerUp.pulsePhase = powerUp.pulsePhase + dt * 3
        end
    end
end

function Game:updateParticles(dt)
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
end

function Game:updateAnimations(dt)
    for i = #self.animations, 1, -1 do
        local anim = self.animations[i]
        anim.progress = anim.progress + dt / anim.duration

        if anim.progress >= 1 then
            if anim.callback then
                anim.callback()
            end
            table_remove(self.animations, i)
        end
    end
end

function Game:checkCollisions()
    -- Ball with walls
    if self.ball.y - self.ball.radius <= 0 then
        self.ball.y = self.ball.radius
        self.ball:handleWallHit(sounds)
    elseif self.ball.y + self.ball.radius >= self.screenHeight then
        self.ball.y = self.screenHeight - self.ball.radius
        self.ball:handleWallHit(sounds)
    end

    -- Ball with paddles
    if self:checkPaddleCollision(self.leftPaddle) then
        self.leftPaddle:onBallHit(self.ball, sounds)
        self.ball:handlePaddleHit(self.leftPaddle, sounds)
        self:applyComboEffects(self.leftPaddle)
    elseif self:checkPaddleCollision(self.rightPaddle) then
        self.rightPaddle:onBallHit(self.ball, sounds)
        self.ball:handlePaddleHit(self.rightPaddle, sounds)
        self:applyComboEffects(self.rightPaddle)
    end

    -- Ball with power-ups
    for i, powerUp in ipairs(self.powerUps) do
        local dx = self.ball.x - powerUp.x
        local dy = self.ball.y - powerUp.y
        local distance = math_sqrt(dx * dx + dy * dy)

        if distance < self.ball.radius + powerUp.radius then
            self:applyPowerUp(powerUp)
            table_remove(self.powerUps, i)
            break
        end
    end
end

function Game:checkPaddleCollision(paddle)
    local closestX = math_max(paddle.x - paddle.width / 2, math_min(self.ball.x, paddle.x + paddle.width / 2))
    local closestY = math_max(paddle.y - paddle.height / 2, math_min(self.ball.y, paddle.y + paddle.height / 2))

    local distanceX = self.ball.x - closestX
    local distanceY = self.ball.y - closestY
    local distance = math_sqrt(distanceX * distanceX + distanceY * distanceY)

    return distance < self.ball.radius
end

function Game:applyComboEffects(paddle)
    if paddle.combo >= 3 then
        self.comboMultiplier = 1 + (paddle.combo - 2) * 0.1
        self:showMessage("COMBO x" .. paddle.combo .. "!", 1.5)

        -- Visual effects for high combos
        if paddle.combo >= 5 then
            self:createComboParticles(paddle.x, paddle.y)
        end
    end
end

function Game:checkScore()
    -- Ball out on left side
    if self.ball.x - self.ball.radius <= 0 then
        self.rightPaddle.score = self.rightPaddle.score + 1
        self.rightPaddle:resetCombo()
        self:onScore("right")

        -- Ball out on right side
    elseif self.ball.x + self.ball.radius >= self.screenWidth then
        self.leftPaddle.score = self.leftPaddle.score + 1
        self.leftPaddle:resetCombo()
        self:onScore("left")
    end

    -- Check win condition
    if self.leftPaddle.score >= self.scoreToWin then
        self:endGame("left")
    elseif self.rightPaddle.score >= self.scoreToWin then
        self:endGame("right")
    end
end

function Game:onScore(scoringSide)
    if sounds.score then
        love.audio.play(sounds.score)
    end

    self:createScoreParticles(scoringSide)
    self:resetBall()

    -- Show score message
    local leftScore = self.leftPaddle.score
    local rightScore = self.rightPaddle.score
    self:showMessage(string_format("%d - %d", leftScore, rightScore), 1.5)
end

function Game:resetBall()
    self.ball:reset(self.screenWidth / 2, self.screenHeight / 2)
    self.paused = true
    self.countdown = 1
    self:startCountdown()
end

function Game:spawnPowerUp()
    local powerUpType = self.powerUpTypes[math_random(1, #self.powerUpTypes)]
    local powerUp = {
        type = powerUpType.type,
        x = math_random(200, self.screenWidth - 200),
        y = math_random(100, self.screenHeight - 100),
        radius = 15,
        color = powerUpType.color,
        duration = powerUpType.duration,
        timer = 10, -- Time until disappearance
        pulsePhase = 0
    }

    table_insert(self.powerUps, powerUp)
end

function Game:applyPowerUp(powerUp)
    if sounds.power_up then
        love.audio.play(sounds.power_up)
    end

    self:showMessage(powerUp.type:upper() .. "!", 2)
    self:createPowerUpParticles(powerUp.x, powerUp.y, powerUp.color)

    if powerUp.type == "speed" then
        self.ball:applyPower("speed", powerUp.duration)
    elseif powerUp.type == "multi" then
        self.ball:applyPower("multi", powerUp.duration)
    elseif powerUp.type == "expand" then
        -- Apply to the paddle that didn't score last
        local paddle = self.ball.vx > 0 and self.leftPaddle or self.rightPaddle
        paddle.height = paddle.height * 1.5
        table_insert(self.animations, {
            type = "power_up",
            progress = 0,
            duration = powerUp.duration,
            callback = function()
                paddle.height = paddle.height / 1.5
            end
        })
    elseif powerUp.type == "shrink" then
        -- Apply to the opponent
        local paddle = self.ball.vx > 0 and self.rightPaddle or self.leftPaddle
        local originalHeight = paddle.height
        paddle.height = paddle.height * 0.7
        table_insert(self.animations, {
            type = "power_up",
            progress = 0,
            duration = powerUp.duration,
            callback = function()
                paddle.height = originalHeight
            end
        })
    elseif powerUp.type == "combo" then
        self.ball:applyPower("combo", powerUp.duration)
    end
end

function Game:createScoreParticles(side)
    local x = side == "left" and self.screenWidth * 0.25 or self.screenWidth * 0.75
    local y = self.screenHeight / 2

    for _ = 1, 20 do
        table_insert(self.particles, {
            x = x,
            y = y,
            dx = (math_random() - 0.5) * 200,
            dy = (math_random() - 0.5) * 200,
            life = math_random(1.0, 2.0),
            maxLife = 2.0,
            size = math_random(3, 8),
            color = side == "left" and { 0.2, 0.6, 1 } or { 1, 0.3, 0.3 },
            alpha = 1
        })
    end
end

function Game:createComboParticles(x, y)
    for _ = 1, 15 do
        table_insert(self.particles, {
            x = x,
            y = y,
            dx = (math_random() - 0.5) * 150,
            dy = (math_random() - 0.5) * 150,
            life = math_random(1.0, 1.5),
            maxLife = 1.5,
            size = math_random(2, 6),
            color = { 1, 0.8, 0.2 },
            alpha = 1
        })
    end
end

function Game:createPowerUpParticles(x, y, color)
    for _ = 1, 25 do
        table_insert(self.particles, {
            x = x,
            y = y,
            dx = (math_random() - 0.5) * 120,
            dy = (math_random() - 0.5) * 120,
            life = math_random(1.0, 1.8),
            maxLife = 1.8,
            size = math_random(2, 5),
            color = { color[1], color[2], color[3] },
            alpha = 1
        })
    end
end

function Game:showMessage(text, duration)
    self.message = text
    self.messageTimer = duration or 2
end

function Game:endGame(winner)
    self.gameOver = true
    self.winner = winner
    self:showMessage(winner:upper() .. " PLAYER WINS!", 5)

    if sounds.score then
        love.audio.play(sounds.score)
    end
end

function Game:draw()
    -- Draw arena
    self:drawArena()

    -- Draw power-ups
    self:drawPowerUps()

    -- Draw particles
    self:drawParticles()

    -- Draw paddles
    self.leftPaddle:draw()
    self.rightPaddle:draw()

    -- Draw ball
    self.ball:draw()

    -- Draw UI
    self:drawUI()

    -- Draw countdown or pause
    if self.countdownActive then
        self:drawCountdown()
    elseif self.paused then
        self:drawPauseScreen()
    end

    if self.gameOver then
        self:drawGameOver()
    end
end

function Game:drawArena()
    -- Center line
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.setLineWidth(2)
    for y = 0, self.screenHeight, 40 do
        love.graphics.rectangle("fill", self.screenWidth / 2 - 1, y, 2, 20)
    end

    -- Court boundaries
    love.graphics.setColor(0.3, 0.5, 0.8, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 10, 10, self.screenWidth - 20, self.screenHeight - 20)

    love.graphics.setLineWidth(1)
end

function Game:drawPowerUps()
    for _, powerUp in ipairs(self.powerUps) do
        local pulse = (math_sin(powerUp.pulsePhase) + 1) * 0.3
        local alpha = 0.7 + pulse * 0.3

        love.graphics.setColor(powerUp.color[1], powerUp.color[2], powerUp.color[3], alpha)

        -- Outer glow
        love.graphics.circle("fill", powerUp.x, powerUp.y, powerUp.radius * 1.3)

        -- Main circle
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", powerUp.x, powerUp.y, powerUp.radius)

        local prevFont = love.graphics.getFont()
        love.graphics.setFont(self.fonts.small_noto_sans)

        -- Symbol based on type
        love.graphics.setColor(powerUp.color[1], powerUp.color[2], powerUp.color[3], 1)
        if powerUp.type == "speed" then
            love.graphics.print("⚡", powerUp.x - 8, powerUp.y - 8)
        elseif powerUp.type == "multi" then
            love.graphics.print("✶", powerUp.x - 8, powerUp.y - 8)
        elseif powerUp.type == "expand" then
            love.graphics.print("⬚", powerUp.x - 8, powerUp.y - 8)
        elseif powerUp.type == "shrink" then
            love.graphics.print("▣", powerUp.x - 8, powerUp.y - 8)
        elseif powerUp.type == "combo" then
            love.graphics.print("★", powerUp.x - 8, powerUp.y - 8)
        end

        love.graphics.setFont(prevFont)
    end
end

function Game:drawParticles()
    for _, particle in ipairs(self.particles) do
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
end

function Game:drawUI()
    -- Scores
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.print(self.leftPaddle.score, self.screenWidth / 2 - 100, 50)
    love.graphics.print(self.rightPaddle.score, self.screenWidth / 2 + 70, 50)

    -- Message
    if self.message ~= "" then
        love.graphics.setFont(self.fonts.medium)
        love.graphics.printf(self.message, 0, 120, self.screenWidth, "center")
    end

    -- Combo multiplier
    if self.comboMultiplier > 1 then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("x" .. string_format("%.1f", self.comboMultiplier), self.screenWidth / 2 - 20, 20)
    end

    -- Mode indicator
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setFont(self.fonts.small)
    local modeText = "Mode: " .. self.gameMode:upper() .. " | Difficulty: " .. self.difficulty:upper()
    love.graphics.printf(modeText, 0, self.screenHeight - 30, self.screenWidth, "center")
end

function Game:drawCountdown()
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(self.fonts.title)
    love.graphics.printf(tostring(self.countdown), 0, self.screenHeight / 2 - 130, self.screenWidth, "center")
end

function Game:drawPauseScreen()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.printf("PAUSED", 0, self.screenHeight / 2 - 50, self.screenWidth, "center")

    love.graphics.setFont(self.fonts.medium)
    love.graphics.printf("Press SPACE to resume", 0, self.screenHeight / 2 + 20, self.screenWidth, "center")
end

function Game:drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.fonts.title)
    love.graphics.printf(self.winner:upper() .. " WINS!", 0, self.screenHeight / 2 - 100, self.screenWidth, "center")

    love.graphics.setFont(self.fonts.medium)
    love.graphics.printf("Final Score: " .. self.leftPaddle.score .. " - " .. self.rightPaddle.score,
        0, self.screenHeight / 2, self.screenWidth, "center")

    love.graphics.printf("Click to return to menu", 0, self.screenHeight / 2 + 60, self.screenWidth, "center")
end

function Game:handleKeyPress(key)
    -- Store key state for continuous movement
    if key == "w" or key == "s" or key == "up" or key == "down" then
        self.keysPressed = self.keysPressed or {}
        self.keysPressed[key] = true
    end
end

function Game:handleKeyRelease(key)
    -- Clear key state when key is released
    if key == "w" or key == "s" or key == "up" or key == "down" then
        if self.keysPressed then
            self.keysPressed[key] = false
        end
    end
end

function Game:handleContinuousMovement(dt)
    if not self.keysPressed or self.paused or self.gameOver then return end

    -- Left paddle controls (W/S)
    if self.keysPressed["w"] then
        self.leftPaddle:moveUp(dt)
    end
    if self.keysPressed["s"] then
        self.leftPaddle:moveDown(dt)
    end

    -- Right paddle controls (Up/Down arrows)
    if self.gameMode == "multi" then
        -- In multiplayer mode, player 2 uses arrow keys
        if self.keysPressed["up"] then
            self.rightPaddle:moveUp(dt)
        end
        if self.keysPressed["down"] then
            self.rightPaddle:moveDown(dt)
        end
    end
    -- In single player mode, the right paddle is controlled by AI
    -- so we don't handle arrow keys for it
end

function Game:togglePause()
    if not self.gameOver and not self.countdownActive then
        self.paused = not self.paused
    end
end

function Game:resetGame()
    self:startNewGame(self.gameMode, self.difficulty)
end

function Game:isGameOver()
    return self.gameOver
end

function Game:setFonts(fonts)
    self.fonts = fonts
end

return Game
