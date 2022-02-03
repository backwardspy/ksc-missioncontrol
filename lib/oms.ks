@lazyGlobal off.

function waitWarp {
    parameter ut.

    if ut < time:seconds + 5 {
        print("WARNING(waitWarp): requested warp is less than 5 seconds, this is unsafe.").
        return.
    }

    print("warping to " + round(ut, 1) + " (" + round(ut - time:seconds, 1) + "s)").

    warpTo(ut).
    wait until time:seconds >= ut and ship:unpacked and kuniverse:timewarp:issettled.

    print("warp completed.").
}

function visViva {
    // calculate the instantaneous orbital speed of the vessel around the current body.
    parameter r.
    parameter sma.
    return sqrt(ship:body:mu * ((2 / r) - (1 / sma))).
}

function periodToSMA {
    // calculate the semi-major axis of the orbit from the period of an orbit
    // around the current body.
    parameter period.

    // T = 2pi * sqrt(a^3 / mu)
    // sqrt(a^3 / mu) = T / 2pi
    // a^3 / mu = (T / 2pi)^2
    // a^3 = ((T / 2pi)^2) * mu
    // a = (((T / 2pi)^2) * mu)^(1/3)
    return (((period / (2 * constant:pi))^2) * ship:body:mu)^(1/3).
}

function apsidesToSMA {
    // calculate the semi-major axis of the orbit from the apoapsis and periapsis
    // of an orbit around the current body.
    parameter ap.
    parameter pe.
    return ship:body:radius + (ap + pe) / 2.
}

function calculateResonantSMA {
    // return the semi-major axis of a resonant orbit around the current body
    // based on the current orbit and the given resonance.
    parameter resonance.

    local newPeriod is ship:orbit:period * (1 + (1 / resonance)).
    return periodToSMA(newPeriod).
}

function combinedIsp {
    // calculates the combined Isp of all active engines on the vessel.
    // returns 0 if no engines are active.
    local totalThrust is 0.
    local totalMassFlow is 0.
    local allEngines is list().
    list engines in allEngines.
    for eng in allEngines {
        if eng:ignition {
            local thrustNewtons is eng:availableThrust / 1000.
            local massFlowKgs is thrustNewtons / eng:isp.
            set totalThrust to totalThrust + thrustNewtons.
            set totalMassFlow to totalMassFlow + massFlowKgs.
        }
    }

    if totalMassFlow = 0 {
        return 0.
    }

    return constant:g0 * totalThrust / totalMassFlow.
}

function burnTime {
    // calculates burn time for a given delta-v with the given Isp.
    parameter dv.
    parameter isp.

    // ensure the vessel can perform this burn.
    // we're not smart enough to perform multi-stage burns yet...
    local stageDv is ship:stagedeltav(ship:stagenum):current.
    if stageDv < dv {
        print("WARNING(burnTime): current stage doesn't have enough delta-v (" + stageDv + " < " + dv + ") to perform this burn.").
        return -1.
    }

    // calculate dry mass via tsiolkovsky rocket equation.
    // 1. dv = isp * ln(m0 / mf)
    // 2. dv / isp = ln(m0 / mf)
    // 3. exp(dv / isp) = m0 / mf
    // 4. m0 / exp(dv / isp) = mf
    local m0 is ship:mass * 1000.
    local mf is m0 / (constant:e ^ (dv / isp)).

    // calculate total flow rate and combine to get burn time.
    local massFlow is ship:availablethrust * 1000 / isp.

    return (m0 - mf) / massFlow.
}

function dvToChangeApsis {
    parameter curApsis.
    parameter tgtApsis.
    local newSMA is apsidesToSMA(tgtApsis, curApsis).
    set tgtApsis to tgtApsis + ship:body:radius.
    set curApsis to curApsis + ship:body:radius.
    local curApsisSpeed is visViva(curApsis, ship:orbit:semimajoraxis).
    local tgtApsisSpeed is visViva(tgtApsis, newSMA).
    return tgtApsisSpeed - curApsisSpeed.
}

function dvToCircularise {
    // return delta-v required to circularise the current orbit at the given altitude.
    parameter circAltitude.
    local radius is ship:body:radius + circAltitude.
    local curApSpeed is visViva(radius, orbit:semimajoraxis).
    local tgtApSpeed is visViva(radius, radius).
    return tgtApSpeed - curApSpeed.
}

function dvForResonantOrbit {
    // return delta-v required to achieve an orbit with the given resonance.
    parameter resonance.
    local sma is calculateResonantSMA(resonance).
    local pe is ship:body:radius + periapsis.
    local curPeSpeed is visViva(pe, orbit:semimajoraxis).
    local tgtPeSpeed is visViva(pe, sma).
    return tgtPeSpeed - curPeSpeed.
}

function apsisChangeNode {
    // return a maneuver node that changes one apsis of the current orbit.
    parameter curApsis.
    parameter tgtApsis.
    parameter ut.
    return node(ut, 0, 0, dvToChangeApsis(curApsis, tgtApsis)).
}

function circulariseNode {
    parameter ut.
    parameter circAltitude.
    // return a maneuver node that circularises the current orbit.
    return node(ut, 0, 0, dvToCircularise(circAltitude)).
}

function resonantOrbitNode {
    // return a maneuver node that achieves an orbit with the given resonance.
    parameter resonance.
    return node(time:seconds + eta:periapsis, 0, 0, dvForResonantOrbit(resonance)).
}

function executeNextNode {
    local node is nextNode.
    lock burnVec to node:burnvector.

    local isp is combinedIsp().
    if isp = 0 {
        print("WARNING(executeNextNode): combinedIsp returned 0. Perhaps no engines are active?").
        return false.
    }

    local t is burnTime(burnVec:mag, isp).
    local halfT is burnTime(burnVec:mag / 2, isp).
    if t < 0 or halfT < 0 {
        print("WARNING(executeNextNode): burnTime returned < 0.").
        return false.
    }

    local burnStart is node:time - halfT.

    if burnStart <= time:seconds {
        print("WARNING(executeNextNode): burn was scheduled too soon and burn start has passed.").
        return false.
    }

    // aim at the burn vector and wait until it's within an acceptable threshold.
    lock steering to burnVec.
    wait until vang(ship:facing:vector, burnVec) < 0.1 and ship:angularvel:mag < 0.1.

    if burnStart > time:seconds + 15 {
        waitWarp(burnStart - 10).
    }

    print("burning for " + round(t, 1) + "s to complete " + round(burnVec:mag, 1) + "m/s maneuver.").

    // wait for burn start.
    wait until time:seconds >= burnStart.

    // execute burn.
    lock throttle to 1.
    wait until time:seconds >= burnStart + t.
    lock throttle to 0.

    unlock steering.
    print("maneuver executed to within " + round(burnVec:mag, 1) + " m/s.").
    remove node.

    return true.
}
