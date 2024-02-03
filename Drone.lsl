// Drone.lsl
// Author & Repository: https://github.com/run2go/DroneController
// License: MIT

// Configuration Parameters
float   TAU = 0.3; // Dampening in seconds
float   TIMER = 1.0; // Time in seconds until auto-off
float   HEIGHT = 1.5; // Return hover height above the owner in meters
float   RESETRANGE = 10.0; // Range in meters after which auto return
integer CHANNEL = 9871; // Comms channel for the controller

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
    vector dronePos = llGetPos();
    vector ownerPos = GetAgentPos(llGetOwner());
    if (llVecDist(dronePos, ownerPos) > RESETRANGE || dronePos.z < ownerPos.z - 0.1 || dronePos.z > ownerPos.z + HEIGHT + 0.1) {
        llSetStatus(STATUS_PHYSICS, FALSE);
        llSetRegionPos(ownerPos + <0, 0, HEIGHT>);
        llSetStatus(STATUS_PHYSICS, TRUE);
    }
    llRegionSay(CHANNEL, (string)llGetKey());
}

default {
    on_rez(integer n) { llResetScript(); }
    timer()           { DroneStop(); }
    state_entry()     {
        llListen(CHANNEL, "", "", "");
        llRegionSay(CHANNEL, (string)llGetKey());
        llSetStatus(STATUS_PHYSICS | STATUS_DIE_AT_EDGE | STATUS_DIE_AT_NO_ENTRY, TRUE);
        llCollisionSound(NULL_KEY, 0.0);
    }
    listen(integer c, string n, key id, string m) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if ((vector)m != ZERO_VECTOR) DroneChase((vector)m);
            else if (m == "dStop") DroneStop();
            else if (m == "dCheck") { DroneCheck(); }
            else if (m == "dDie") { llDie(); }
        }
    }
}
