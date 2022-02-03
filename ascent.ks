@lazyGlobal off.

parameter tgtAltitude is 100000.
parameter tgtInclination is 0.

if tgtAltitude:hassuffix("tonumber") {
    set tgtAltitude to tgtAltitude:tonumber(100000).
}

if tgtInclination:hassuffix("tonumber") {
    set tgtInclination to tgtInclination:tonumber(0).
}

runOncePath("kslib/lib_lazcalc").

runOncePath("lib/oms").

local turnStart is 3500.
local turnEnd is 45000.

function calculateThrottle {
    local throttleBackAlt is tgtAltitude * 0.9.
    if apoapsis < throttleBackAlt {
        return 1.
    }

    local progress is (apoapsis - throttleBackAlt) / (tgtAltitude - throttleBackAlt).
    local output is 1 - (max(min(1, progress), 0) ^ 16).
    // prevent tiny little outputs
    if output < 0.05 {
        if output > 0.01 {
            set output to 0.05.
        } else {
            set output to 0.
        }
    }
    return output.
}

function calculatePitch {
    if ship:altitude < turnStart {
        return 90.
    }

    if ship:altitude > turnEnd {
        return 0.
    }

    return 90 * (1 - (ship:altitude - turnStart) / (turnEnd - turnStart)).
}

function engineFlameout {
    local engines is list().
    list engines in engines.
    for engine in engines {
        if engine:ignition and engine:flameout {
            return true.
        }
    }
    return false.
}

print("launching to " + round(tgtAltitude / 1000, 1) + " km at " + tgtInclination + "° inclination").

sas off.
lock throttle to calculateThrottle().
lock pitch to calculatePitch().

local obtParams is LAZcalc_init(tgtAltitude, tgtInclination).
lock tgtHeading to LAZcalc(obtParams).

// set up auto-staging.
when stage:ready and (availableThrust = 0 or engineFlameout()) then {
    local stageNum is stage:number.

    wait 0.5.
    print "staging #" + stageNum.
    stage.

    // preserve trigger if there are more stages to go.
    return stage:nextDecoupler <> "None".
}

lock steering to heading(tgtHeading, pitch).

print("waiting for ap >= tgt...").
until apoapsis >= tgtAltitude {
    wait 0.     // for some reason, `wait until` here just hangs...
}

if ship:q > 0 {
    print("coasting out of atmo...").
    lock steering to prograde.
    wait until ship:q = 0.
}

print("throttling down.").
lock throttle to 0.

print("perform pre-circ operations now.").
print("press enter when ready.").
wait until terminal:input:getchar() = terminal:input:enter.

// check if we need to jettison this stage before circularising.
until ship:stagedeltav(ship:stagenum):current >= dvToCircularise(tgtAltitude) {
    print("stage " + ship:stagenum + " is not sufficient to circularise, jettisoning...").
    wait 3.
    stage.
    wait until stage:ready.
}
print("stage " + ship:stagenum + " is sufficient to circularise.").
wait 5.

runPath("circularise").
