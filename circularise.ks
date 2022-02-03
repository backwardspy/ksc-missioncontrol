@lazyGlobal off.

parameter at is "ap".

runOncePath("lib/oms").

print("planning circularisation burn.").

local t is eta:apoapsis.
local r is apoapsis.
if at = "pe" {
    set t to eta:periapsis.
    set r to periapsis.
}

local circNode is circulariseNode(time:seconds + t, r).
add circNode.

local circDv is round(circNode:burnvector:mag).
until ship:stagedeltav(ship:stagenum):current >= circDv {
    if ship:stagenum > 0 {
        print(
            "stage " + ship:stagenum +
            " lacks the delta-v to circularise. " +
            "(" + round(ship:stagedeltav(ship:stagenum):current) + " < " + circDv + ")").
        wait 1.
        print("staging...").
        stage.
    } else {
        print("vessel lacks the required delta-v to circularise.").
        remove circNode.
    }
}

executeNextNode().
