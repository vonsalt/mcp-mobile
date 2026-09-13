WINDOW = findByName("Window")
TOPBAR = findByName("TopBar")
WINDOW.AbsoluteSize = Vector2.new(380, 500)
WINDOW.Position = UDim2.new(0.5, 0, 0.5, 0)

print("\n== dragging ==")
check("top bar is an input target", TOPBAR.Active == true)

DOWN = fakeInput("MouseButton1", 900, 500)
TOPBAR.InputBegan:Fire(DOWN)
flushPending(1)

-- Mouse moves 120px right / 80px down, and the pointer has left the title bar,
-- which is exactly the case the old build dropped.
SERVICES.UserInputService.InputChanged:Fire(fakeInput("MouseMovement", 1020, 580))
flushPending(1)
check("window followed the pointer on X", math.abs(WINDOW.Position.X.Offset - (960 + 120)) < 0.01, WINDOW.Position.X.Offset)
check("window followed the pointer on Y", math.abs(WINDOW.Position.Y.Offset - (540 + 80)) < 0.01, WINDOW.Position.Y.Offset)

-- Way off screen: the window must stay reachable.
SERVICES.UserInputService.InputChanged:Fire(fakeInput("MouseMovement", 99999, 99999))
flushPending(1)
check("clamped to the right edge", WINDOW.Position.X.Offset <= 1920 - 190 + 0.01, WINDOW.Position.X.Offset)
check("clamped to the bottom edge", WINDOW.Position.Y.Offset <= 1080 - 250 + 0.01, WINDOW.Position.Y.Offset)

-- Release outside the window, then move again: nothing should move.
SERVICES.UserInputService.InputEnded:Fire(fakeInput("MouseButton1", 5, 5))
flushPending(1)
BEFORE = WINDOW.Position.X.Offset
SERVICES.UserInputService.InputChanged:Fire(fakeInput("MouseMovement", 200, 200))
flushPending(1)
check("drag stops on mouse release", WINDOW.Position.X.Offset == BEFORE, WINDOW.Position.X.Offset)
check("no handler errors", #ERRORS == 0, ERRORS[1])
report()
