REDEEM = findByName("RedeemClick")
KEYINPUT = findByName("KeyInput")
STATUS = findByName("Status")
WINDOW = findByName("Window")
BACKDROP = findByName("Backdrop")

print("\n== the window waits instead of guessing ==")
KEYINPUT.Text = "FLOW-SLOW-KEY"
REDEEM.Activated:Fire()
flushPending(2)
check("window still up while the loader works", WINDOW.Visible ~= false)
check("status says it is still working", STATUS.Text:find("Validating") ~= nil, STATUS.Text)

advanceClock(7)
flushPending(2)
check("tells the player it is downloading", STATUS.Text:find("Downloading") ~= nil, STATUS.Text)
check("window still up at 7s", WINDOW.Visible ~= false)

print("\n== after the optimistic window it steps aside ==")
advanceClock(6)
flushPending(3)
check("window hidden", WINDOW.Visible == false)
check("key saved once it looked accepted", FAKE_FS[SAVE_PATH] == "FLOW-SLOW-KEY", FAKE_FS[SAVE_PATH])
check("status reports acceptance", STATUS.Text:find("accepted") ~= nil, STATUS.Text)

print("\n== no second loader run while one is in flight ==")
RUNS_BEFORE = #CREDENTIALS
REDEEM.Activated:Fire()
KEYINPUT.FocusLost:Fire(true)
flushPending(2)
check("loader was not started again", #CREDENTIALS == RUNS_BEFORE, #CREDENTIALS)

print("\n== a late rejection brings the window back ==")
LOADER_ERROR = "script_key is invalid"
LOADER_RELEASE = true
flushPending(4)
check("window visible again", WINDOW.Visible == true)
check("backdrop visible again", BACKDROP.Visible == true)
check("bad key removed from disk", FAKE_FS[SAVE_PATH] == nil, FAKE_FS[SAVE_PATH])
check("status explains the rejection", STATUS.Text:find("not valid") ~= nil, STATUS.Text)
check("button usable again", findByName("RedeemLabel").Text == "Redeem Key", findByName("RedeemLabel").Text)
check("not torn down", GENV.VoidHubKeySystem.Destroyed ~= true)
check("no handler errors", #ERRORS == 0, ERRORS[1])

report()
