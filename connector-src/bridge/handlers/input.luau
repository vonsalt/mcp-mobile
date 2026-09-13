return function(context, Bridge)
local VirtualInputManager = context.VirtualInputManager

    Bridge:BindToType("type-text-box", function(data)
        local path = data.path
        local text = data.string or data.text
        local enter = data.enter
        local useKeyPress = data.useKeyPress

        local textBox
        if typeof(path) == "string" then
            textBox = loadstring("return " .. path)()
        else
            textBox = path
        end
        
        assert(typeof(textBox) == "Instance", "Path did not resolve to a valid Instance.")
        assert(textBox:IsA("TextBox"), "Resolved Instance is not a TextBox.")

        textBox:CaptureFocus()
        task.wait(0.05)
        
        if useKeyPress then
            local success = pcall(function()
                for i = 1, #text do
                    VirtualInputManager:SendTextInput(text:sub(i, i), nil, game)
                    task.wait(0.01)
                end
            end)
            
            if not success and type(keypress) == "function" then
                for i = 1, #text do
                    local char = text:sub(i, i):upper()
                    local byte = char:byte()
                    if byte then
                        keypress(byte)
                        task.wait(0.01)
                        if type(keyrelease) == "function" then
                            keyrelease(byte)
                        end
                    end
                end
            end
        else
            textBox.Text = text
        end

        if enter then
            if useKeyPress then
                if type(keypress) == "function" then
                    keypress(0x0D)
                    task.wait(0.01)
                    if type(keyrelease) == "function" then
                        keyrelease(0x0D)
                    end
                else
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                        task.wait(0.01)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                    end)
                end
            end
            textBox:ReleaseFocus(true)
        else
            textBox:ReleaseFocus(false)
        end

        return {
            status = "success",
            message = "Successfully typed into TextBox."
        }
    end)

    Bridge:BindToType("click-button", function(data)
        local path = data.path
        local action = data.Action or data.action

        local button
        if typeof(path) == "string" then
            button = loadstring("return " .. path)()
        else
            button = path
        end

        assert(typeof(button) == "Instance", "Path did not resolve to a valid Instance.")
        assert(button:IsA("GuiButton"), "Resolved Instance is not a GuiButton (e.g., TextButton or ImageButton).")

        local Signals = {"Activated", "MouseButton1Down", "MouseButton2Down", "MouseButton1Click", "MouseButton2Click"}
        local method = "unknown"

        if action then
            assert(table.find(Signals, action), "Invalid action provided. Valid actions are: " .. table.concat(Signals, ", "))
        end

        if type(firesignal) == "function" then
            method = "firesignal"
            if action then
                firesignal(button[action])
            else
                for _, signalName in pairs(Signals) do
                    pcall(function() firesignal(button[signalName]) end)
                end
            end
        elseif button.Activate and type(button.Activate) == "function" then
            method = "Activate"
            pcall(function() button:Activate() end)
        else
            method = "VirtualInputManager"
            local success, err = pcall(function()
                local absPos = button.AbsolutePosition
                local absSize = button.AbsoluteSize
                if absPos and absSize then
                    local centerX = absPos.X + absSize.X / 2
                    local centerY = absPos.Y + absSize.Y / 2
                    pcall(function()
                        VirtualInputManager:SendMouseButton(true, Enum.UserInputType.MouseButton1, Vector2.new(centerX, centerY), 0, game)
                        task.wait(0.05)
                        VirtualInputManager:SendMouseButton(false, Enum.UserInputType.MouseButton1, Vector2.new(centerX, centerY), 0, game)
                    end)
                    pcall(function()
                        VirtualInputManager:SendTouchEvent(true, Vector2.new(centerX, centerY), 0, game)
                        task.wait(0.05)
                        VirtualInputManager:SendTouchEvent(false, Vector2.new(centerX, centerY), 0, game)
                    end)
                end
            end)
            if not success then
                error("Failed to click button: " .. tostring(err))
            end
        end

        return {
            status = "success",
            message = "Successfully clicked Button using method: " .. method,
            method = method
        }
    end)
end
