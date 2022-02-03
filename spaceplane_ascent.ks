@lazyGlobal off.

runOncePath("lib/oms").

local rotateSpeed is 100.
local gearUpAlt is 100.
local cruiseClimbPitch is 30.
local cruiseAlt is 10000.
local cruisePitch is 10.
local rocketPitch is 30.
local orbitAlt is 80000.

function lerp {
    parameter a.
    parameter b.
    parameter t.
    return a + (b - a) * t.
}

function clamp {
    parameter a.
    parameter lo.
    parameter hi.
    return max(min(a, hi), lo).
}

function smoothstep {
    parameter from.
    parameter to.
    parameter x.
    parameter range.
    return lerp(from, to, clamp(x / range, 0, 1)).
}

function splitEngines {
    local jets is list().
    local rockets is list().
    local allEngines is list().
    list engines in allEngines.
    for engine in allEngines {
        if engine:consumedresources:haskey("Intake Air") {
            jets:add(engine).
        } else {
            rockets:add(engine).
        }
    }
    return list(jets, rockets).
}

core:doaction("Open Terminal", true).

print("learning craft configuration.").
local engines is splitEngines().
print("craft has " + engines[0]:length() + " jets and " + engines[1]:length() + " rockets").

print("configuring steering.").
set steeringManager:pitchpid:kp to 5.
set steeringManager:pitchpid:ki to 0.
set steeringManager:pitchpid:kd to 0.5.

print("preparing for takeoff.").
brakes on.
wait 5.
sas off.
stage.
wait until stage:ready.
brakes off.

print("taking off.").
lock steering to heading(90, 0).
lock throttle to 1.

wait until ship:groundspeed >= rotateSpeed.

print("rotating.").
lock steering to heading(90, 10).

wait until ship:altitude > gearUpAlt.

print("retracting gear.").
gear off.

print("climbing to cruising altitude").
local t is time:seconds.
lock steering to heading(90, smoothstep(10, cruiseClimbPitch, time:seconds - t, 5)).

wait until ship:altitude >= cruiseAlt.

print("leveling out for supersonic acceleration.").
set t to time:seconds.
lock steering to heading(90, smoothstep(cruiseClimbPitch, cruisePitch, time:seconds - t, 5)).

wait until engines[0][0]:fuelflow <= 0.5.

print("fuel flow dropoff detected.").
print("activating vacuum engines.").
stage.
rcs on.
set t to time:seconds.
lock steering to heading(90, smoothstep(cruisePitch, rocketPitch, time:seconds - t, 5)).

wait until engines[0][0]:flameout.

print("jets flamed out, closing intakes.").
intakes off.
for engine in engines[0] {
    engine:shutdown().
}

lock steering to heading(90, smoothstep(rocketPitch, prograde:pitch, ship:apoapsis - (orbitAlt - 30000), 30000)).

// we add a little extra ap to account for drag bringing it back down.
wait until ship:apoapsis >= orbitAlt * 1.02.
lock throttle to 0.
wait until ship:q <= 0.

wait 1.

runPath("circularise").
