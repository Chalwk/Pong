-- Pong - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local math_sin = math.sin

local helpText = {
    "PONG",
    "",
    "Game Modes:",
    "• Single Player - Play against AI",
    "• Multiplayer - Two players on one keyboard",
    "",
    "Controls:",
    "• Player 1: W/S keys",
    "• Player 2: Up/Down arrows",
    "• Pause: SPACE",
    "• Restart: R",
    "• Menu: ESC",
    "",
    "Power-ups:",
    "• Speed - Ball moves faster",
    "• Multi - Creates multiple balls",
    "• Expand - Makes your paddle larger",
    "• Shrink - Makes opponent paddle smaller",
    "• Combo - Bonus points for consecutive hits",
    "",
    "Features:",
    "• Combo system - Chain hits for bonuses",
    "• Energy system - Paddles have limited energy",
    "• Modern visuals - Particles, glow effects, animations",
    "• Multiple difficulties - Easy, Medium, Hard AI",
    "",
    "Click anywhere to close"
}

local Menu = {}
Menu.__index = Menu

function Menu.new()
    local instance = setmetatable({}, Menu)

    instance.screenWidth = 1200
    instance.screenHeight = 800
    instance.gameMode = "single"
    instance.difficulty = "medium"
    instance.title = {
        text = "PONG",
        scale = 1,
        scaleDirection = 1,
        scaleSpeed = 0.3,
        minScale = 0.95,
        maxScale = 1.05,
        rotation = 0,
        rotationSpeed = 0.2
    }
    instance.showHelp = false

    instance:createMenuButtons()
    instance:createOptionsButtons()

    return instance
end

function Menu:setFonts(fonts)
    self.smallFont = fonts.small
    self.mediumFont = fonts.medium
    self.largeFont = fonts.large
    self.titleFont = fonts.title
end

function Menu:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self:updateButtonPositions()
    self:updateOptionsButtonPositions()
end

function Menu:createMenuButtons()
    self.menuButtons = {
        {
            text = "Start Game",
            action = "start",
            width = 250,
            height = 60,
            x = 0,
            y = 0
        },
        {
            text = "Options",
            action = "options",
            width = 250,
            height = 60,
            x = 0,
            y = 0
        },
        {
            text = "How to Play",
            action = "help",
            width = 250,
            height = 60,
            x = 0,
            y = 0
        },
        {
            text = "Quit",
            action = "quit",
            width = 250,
            height = 60,
            x = 0,
            y = 0
        }
    }

    self:updateButtonPositions()
end

function Menu:createOptionsButtons()
    self.optionsButtons = {
        -- Game Mode Section
        {
            text = "Single Player",
            action = "mode single",
            width = 200,
            height = 45,
            x = 0,
            y = 0,
            section = "mode"
        },
        {
            text = "Multiplayer",
            action = "mode multi",
            width = 200,
            height = 45,
            x = 0,
            y = 0,
            section = "mode"
        },

        -- Difficulty Section
        {
            text = "Easy AI",
            action = "diff easy",
            width = 180,
            height = 40,
            x = 0,
            y = 0,
            section = "difficulty"
        },
        {
            text = "Medium AI",
            action = "diff medium",
            width = 180,
            height = 40,
            x = 0,
            y = 0,
            section = "difficulty"
        },
        {
            text = "Hard AI",
            action = "diff hard",
            width = 180,
            height = 40,
            x = 0,
            y = 0,
            section = "difficulty"
        },

        -- Navigation
        {
            text = "Back to Menu",
            action = "back",
            width = 200,
            height = 50,
            x = 0,
            y = 0,
            section = "navigation"
        }
    }
    self:updateOptionsButtonPositions()
end

function Menu:updateButtonPositions()
    local startY = self.screenHeight / 2
    for i, button in ipairs(self.menuButtons) do
        button.x = (self.screenWidth - button.width) / 2
        button.y = startY + (i - 1) * 80
    end
end

function Menu:updateOptionsButtonPositions()
    local centerX = self.screenWidth / 2
    local startY = self.screenHeight / 2 - 100

    -- Mode buttons
    local modeButtonW, modeButtonH, modeSpacing = 200, 45, 20
    local modeTotalW = 2 * modeButtonW + modeSpacing
    local modeStartX = centerX - modeTotalW / 2
    local modeY = startY + 40

    -- Difficulty buttons
    local diffButtonW, diffButtonH, diffSpacing = 180, 40, 15
    local diffTotalW = 3 * diffButtonW + 2 * diffSpacing
    local diffStartX = centerX - diffTotalW / 2
    local diffY = startY + 120

    -- Navigation
    local navY = startY + 200

    local modeIndex = 0
    local diffIndex = 0

    for _, button in ipairs(self.optionsButtons) do
        if button.section == "mode" then
            button.x = modeStartX + modeIndex * (modeButtonW + modeSpacing)
            button.y = modeY
            modeIndex = modeIndex + 1
        elseif button.section == "difficulty" then
            button.x = diffStartX + diffIndex * (diffButtonW + diffSpacing)
            button.y = diffY
            diffIndex = diffIndex + 1
        elseif button.section == "navigation" then
            button.x = centerX - button.width / 2
            button.y = navY
        end
    end
end

function Menu:update(dt, screenWidth, screenHeight)
    if screenWidth ~= self.screenWidth or screenHeight ~= self.screenHeight then
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self:updateButtonPositions()
        self:updateOptionsButtonPositions()
    end

    -- Update title animation
    self.title.scale = self.title.scale + self.title.scaleDirection * self.title.scaleSpeed * dt

    if self.title.scale > self.title.maxScale then
        self.title.scale = self.title.maxScale
        self.title.scaleDirection = -1
    elseif self.title.scale < self.title.minScale then
        self.title.scale = self.title.minScale
        self.title.scaleDirection = 1
    end

    self.title.rotation = self.title.rotation + self.title.rotationSpeed * dt
end

function Menu:draw(screenWidth, screenHeight, state)
    -- Draw animated title
    love.graphics.setColor(0.2, 0.6, 1.0)
    love.graphics.setFont(self.titleFont)

    love.graphics.push()
    love.graphics.translate(screenWidth / 2, screenHeight / 4)
    love.graphics.rotate(math_sin(self.title.rotation) * 0.05)
    love.graphics.scale(self.title.scale, self.title.scale)
    love.graphics.printf(self.title.text, -screenWidth / 2, -self.titleFont:getHeight() / 2, screenWidth, "center")
    love.graphics.pop()

    if state == "menu" then
        if self.showHelp then
            self:drawHelpOverlay(screenWidth, screenHeight)
        else
            self:drawMenuButtons()
            -- Draw tagline
            love.graphics.setColor(0.8, 0.9, 1.0)
            love.graphics.setFont(self.mediumFont)
            love.graphics.printf("The Ultimate Pong Experience",
                0, screenHeight / 3 + 50, screenWidth, "center")
        end
    elseif state == "options" then
        self:drawOptionsInterface()
    end

    -- Draw copyright
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setFont(self.smallFont)
    love.graphics.printf("© 2025 Jericho Crosby – Pong", 10, screenHeight - 25, screenWidth - 20, "right")
end

function Menu:drawHelpOverlay(screenWidth, screenHeight)
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Help box
    local boxWidth = 700
    local boxHeight = 550
    local boxX = (screenWidth - boxWidth) / 2
    local boxY = (screenHeight - boxHeight) / 2

    -- Box background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, 10)

    -- Box border
    love.graphics.setColor(0.2, 0.6, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, 10)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.largeFont)
    love.graphics.printf("How to Play", boxX, boxY + 20, boxWidth, "center")

    -- Help text
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(self.smallFont)

    local lineHeight = 22
    for i, line in ipairs(helpText) do
        local y = boxY + 80 + (i - 1) * lineHeight
        love.graphics.printf(line, boxX + 30, y, boxWidth - 60, "left")
    end

    love.graphics.setLineWidth(1)
end

function Menu:drawOptionsInterface()
    local centerX = self.screenWidth / 2
    local startY = self.screenHeight / 2 - 100

    -- Draw section headers
    love.graphics.setFont(self.mediumFont)
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.printf("Game Mode", 0, startY + 10, self.screenWidth, "center")
    love.graphics.printf("Difficulty", 0, startY + 90, self.screenWidth, "center")

    self:updateOptionsButtonPositions()
    self:drawOptionSection("mode")
    self:drawOptionSection("difficulty")
    self:drawOptionSection("navigation")
end

function Menu:drawOptionSection(section)
    for _, button in ipairs(self.optionsButtons) do
        if button.section == section then
            self:drawButton(button)

            -- Draw selection highlight
            if button.action:sub(1, 4) == "mode" then
                local mode = button.action:sub(6)
                if mode == self.gameMode then
                    love.graphics.setColor(0.2, 0.8, 0.2, 0.4)
                    love.graphics.rectangle("fill", button.x - 3, button.y - 3, button.width + 6, button.height + 6, 5)
                end
            elseif button.action:sub(1, 4) == "diff" then
                local difficulty = button.action:sub(6)
                if difficulty == self.difficulty then
                    love.graphics.setColor(0.2, 0.8, 0.2, 0.4)
                    love.graphics.rectangle("fill", button.x - 3, button.y - 3, button.width + 6, button.height + 6, 5)
                end
            end
        end
    end
end

function Menu:drawMenuButtons()
    for _, button in ipairs(self.menuButtons) do
        self:drawButton(button)
    end
end

function Menu:drawButton(button)
    love.graphics.setColor(0.25, 0.25, 0.4, 0.9)
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 8, 8)

    love.graphics.setColor(0.6, 0.6, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 8, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.mediumFont)
    local textWidth = self.mediumFont:getWidth(button.text)
    local textHeight = self.mediumFont:getHeight()
    love.graphics.print(button.text, button.x + (button.width - textWidth) / 2,
        button.y + (button.height - textHeight) / 2)

    love.graphics.setLineWidth(1)
end

function Menu:handleClick(x, y, state)
    local buttons = state == "menu" and self.menuButtons or self.optionsButtons

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end

    -- If help is showing, any click closes it
    if state == "menu" and self.showHelp then
        self.showHelp = false
        return "help_close"
    end

    return nil
end

function Menu:setGameMode(mode)
    self.gameMode = mode
end

function Menu:getGameMode()
    return self.gameMode
end

function Menu:setDifficulty(difficulty)
    self.difficulty = difficulty
end

function Menu:getDifficulty()
    return self.difficulty
end

return Menu
