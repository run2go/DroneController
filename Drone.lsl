// Drone.lsl
// Author & Repository: https://github.com/run2go/DroneController
// License: MIT

// Configuration Parameters
float   TAU = 0.3; // Dampening in seconds
float   TIMER = 1.0; // Time in seconds until auto-off
float   HEIGHT = 1.5; // Return hover height above the owner in meters
float   LIMIT = 10.0; // Max range in meters until auto return

// Helper Variables
integer dynChannel;

vector GetAgentPos(key id) { return llList2Vector(llGetObjectDetails(id, ([OBJECT_POS])), 0); }
DroneChase(vector targetPos) {
    llMoveToTarget(targetPos, TAU);
    llSetTimerEvent(TIMER);
}
DroneStop() {
    llSetTimerEvent(0);
    llStopMoveToTarget();
}
DroneCheck() {
    llRegionSay(dynChannel, (string)llGetKey());
    vector vDrone = llGetPos();
    vector vOwner = GetAgentPos(llGetOwner());
    if (llVecDist(vDrone, vOwner) > LIMIT || vDrone.z < vOwner.z - 0.5 || vDrone.z > vOwner.z + HEIGHT + 0.5) {
        llSetStatus(STATUS_PHYSICS, FALSE);
        llSetRegionPos(vOwner + <0, 0, HEIGHT>);
        llSetStatus(STATUS_PHYSICS, TRUE);
    }
}
DroneRegister() {
    llRegionSay(dynChannel, (string)llGetKey());
}

default {
    on_rez(integer n) { llResetScript(); }
    timer()           { DroneStop(); }
    state_entry() {
        dynChannel = (integer)("0x" + llGetSubString(llGetOwner(), 0, 7));
        llListen(dynChannel, "", "", "");
        llRegionSay(dynChannel, (string)llGetKey());
        llSetStatus(STATUS_PHYSICS | STATUS_DIE_AT_EDGE | STATUS_DIE_AT_NO_ENTRY, TRUE);
        llCollisionSound(NULL_KEY, 0.0);
    }
    listen(integer c, string n, key id, string m) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if ((vector)m != ZERO_VECTOR) DroneChase((vector)m);
            else if (m == "dStop")  DroneStop();
            else if (m == "dCheck") DroneCheck();
            else if (m == "dReg")   DroneRegister();
            else if (m == "dDie")   llDie();
        }
    }
}
