REDEEM = findByName("RedeemClick")
KEYINPUT = findByName("KeyInput")
STATUS = findByName("Status")

print("\n== a second attempt starts from a clean slate ==")

KEYINPUT.Text = "FIRST-KEY"
REDEEM.Activated:Fire()
flushPending(3)
check("first attempt ran the loader", #RUNS == 1, #RUNS)
check("first attempt saw no handoff", RUNS[1].bsdata == nil)
check("loader dirtied the globals", GENV._bsdata0 ~= nil)

KEYINPUT.Text = "SECOND-KEY"
REDEEM.Activated:Fire()
flushPending(3)
check("second attempt ran the loader", #RUNS == 2, #RUNS)
check("stale handoff was cleared first", RUNS[2].bsdata == nil, RUNS[2].bsdata)
check("loader leftovers were cleared first", RUNS[2].leftover == nil, RUNS[2].leftover)
check("second attempt used the new key", RUNS[2].key == "SECOND-KEY", RUNS[2].key)
check("key also passed as the loader argument", CREDENTIALS[2] == "SECOND-KEY", CREDENTIALS[2])
check("still usable after two rejections", findByName("RedeemLabel").Text == "Redeem Key")
check("no handler errors", #ERRORS == 0, ERRORS[1])

print("\n== unrelated globals are left alone ==")
GENV.SomeOtherScript = "do not touch"
KEYINPUT.Text = "THIRD-KEY"
REDEEM.Activated:Fire()
flushPending(3)
check("third attempt ran", #RUNS == 3, #RUNS)
check("other script's global survived", GENV.SomeOtherScript == "do not touch", GENV.SomeOtherScript)

report()
