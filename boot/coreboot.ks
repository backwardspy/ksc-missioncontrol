@lazyGlobal off.

// on startup, checks for a connection back to KSC archive.
// if there is one, downloads the latest set of maneuver programs.

// set to true for coreFiles to be compiled for space.
local compiled is false.

function coreFile {
    parameter item.
    parameter dest is "".

    local destName is dest.
    if destName = "" {
        set destName to item:name.
    }

    if not homeConnection:isconnected {
        print("ERROR(coreFile): no connection to archive.").
        return.
    }

    local hd is core:volume.
    switch to hd.

    print(item:name + " -> " + destName).
    if compiled {
        compile "0:/" + item:name to dest.
    } else {
        copyPath("0:/" + item:name, dest).
    }
}

if core:tag = "interactive" {
    core:doaction("Open Terminal", true).
}

print("waiting for vessel readiness...").
wait until ship:unpacked.

if homeConnection:isconnected {
    print("home connection established.").
    print("downloading latest maneuver programs...").
    local arc is volume(0).
    for item in arc:files:values {
        if item:name[0] <> "." {
            coreFile(item).
        }
    }
} else {
    print("no home connection.").
}

print("ready for commands. reboot to check for updates.").
