// DroneController.lsl 
// Author & Repository: https://github.com/run2go/DroneController
// License: MIT

// Configuration Parameters
float   RATE = 0.1;     // Tick rate for position updates
float   CHECK = 5.0;    // Health check interval for arDrones
float   TIMER = 2.5;    // Time in seconds until reset
float   RANGE = 128.0;  // Detection range, 4096m max
float   HEIGHT = 1.5;   // Hover height above the owner in meters
float   DISTANCE = 0.2; // Distance between the drones for conducting
float   ROTATING = 3.0; // Rotation increments in degrees per tick
integer CHANNEL = 9871; // Gesture & comms channel for the drones

vector GetRestPos()        { return llGetPos() + <0, 0, HEIGHT>; }
vector GetAgentPos(key id) { return llList2Vector(llGetObjectDetails(id, ([OBJECT_POS])), 0); }
TrackPos(vector pos)       { llRegionSay(CHANNEL, (string)pos); }

key kAgent;
vector vTarget;
TargetClear() {
    kAgent = NULL_KEY;
    vTarget = ZERO_VECTOR;
}
DroneTarget() {
    TargetClear();
    llRequestPermissions(llGetOwner(), 0x400); // Track Camera permissions
    vector vStart = llGetCameraPos();
    vector vEnd = vStart + <RANGE, 0.0, 0.0> * llGetCameraRot();
    list data = llCastRay(vStart, vEnd, []);
    
    if (llGetListLength(data) > 1) { // Check if an object was hit
        kAgent = llList2Key(data, 0);
        vTarget = llList2Vector(data, 1);  // Else use target position
        if (llKey2Name(llList2Key(data, 0)) != "") llSetText("[Track]\n " + llKey2Name(kAgent), <0.3,1,0.5>, 1.0);
        else llSetText("[Track]\n " + (string)vTarget, <0.8,1,0.3>, 1.0);
        nTick = 0;
        bChase = TRUE;
    }
}

list arDrones;
DroneRegister(key droneKey) { // Add the new key to arDrones
    if (llListFindList(arDrones, [droneKey]) == -1) arDrones += [droneKey];
}

integer nDrones = 0;
integer bPolygon = FALSE;
float fRotation = 0;
DroneConduct() {
    vector vResting = GetRestPos();
    if (bPolygon && nDrones > 1) { // Polygon mode if more than 1 active drones
        integer i;
        fRotation += ROTATING; // Increment rotation globally
        for (i = 0; i <= nDrones; i++) {
            vector vDrone = vResting;
            float fDistance = DISTANCE * nDrones; // Dynamically adjust the distance
            float fAngle = TWO_PI * i / nDrones + fRotation * DEG_TO_RAD; // Calculate the angle
            vDrone.x += fDistance * llCos(fAngle); // Update drone position with the offset
            vDrone.y += fDistance * llSin(fAngle);
            
            llRegionSayTo(llList2Key(arDrones, i), CHANNEL, (string)vDrone); // Send newvector to the drone
        } if (fRotation >= 360.0) fRotation -= 360.0; // Adjust rotation to keep it within [0, 360) degrees
    } else TrackPos(vResting); // Else move all drones to the same spot
    if (bPolygon) llSetText("[Poly]\nDrones: " + (string)nDrones, <1.0,0.8,1.0>, 0.7);
    else llSetText("[Rest]\nDrones: " + (string)nDrones, <1.0,1.0,0.8>, 0.7);
}

integer bChase = FALSE;
integer nTick = 100;
DroneMode() {
    nDrones = llGetListLength(arDrones);
    if (bChase) { // Chasing
        if (kAgent != NULL_KEY) TrackPos(GetAgentPos(kAgent));
        else if (vTarget != ZERO_VECTOR) TrackPos(vTarget);
    } else DroneConduct(); // Idling
    if (nTick > (integer)(TIMER / RATE)) bChase = FALSE;
    if (nTick > (integer)(CHECK / RATE) && !bChase) DroneCheck();
    nTick++;
}

integer bActive = FALSE;
DroneToggle(integer bSwitch) {
    if (bSwitch) { // Turn on
        DroneCheck();
        bChase = FALSE;
        llSetTimerEvent(RATE);
    } else { // Turn off
        llSetTimerEvent(0);
        llSetText("[~]", <1,1,1>, 0.5);
        llRegionSay(CHANNEL, "dStop");
        arDrones = [];
        TargetClear();
    }
}

DroneCheck() {
    llRegionSay(CHANNEL, "dCheck");
    arDrones = [];
    nTick = 0;
}

DroneCreate() {
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0), GetRestPos(), ZERO_VECTOR, ZERO_ROTATION, 0);
}

DroneDie() {
    llRegionSay(CHANNEL, "dDie");
    DroneCheck();
}

integer nColumns = 4;
integer nRows    = 1;
NavButton(integer n) {
    integer nLink   = llDetectedLinkNumber(0);
    vector  vTouch  = llDetectedTouchST(0);
    integer nColumn = (integer)(vTouch.x * nColumns);
    integer nRow    = (integer)(vTouch.y * nRows);
    integer nCell   = (nRow * nColumns) + nColumn;
    
    if (nLink == 0) { // HUD Face 0
        if      (nCell == 0) DroneToggle(bActive = !bActive);
        else if (nCell == 1) bPolygon = !bPolygon;
        else if (nCell == 2) DroneCreate();
        else if (nCell == 3) DroneDie();
    }
}
default {
    touch_start(integer n) { if (llDetectedKey(0) == llGetOwner()) NavButton(n); }
    attach(key id)         { llResetScript(); }
    timer()                { DroneMode(); }
    state_entry() {
        llListen(CHANNEL, "", "", "");
        llSetText("[~]", <1,1,1>, 0.5);
    }
    listen(integer c, string n, key id, string m) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if      (m == "toggle") DroneToggle(bActive = !bActive);
            else if (m == "trigger" && bActive) DroneTarget();
            else if (m == "dDie") DroneDie();
            else if ((key)m != NULL_KEY) DroneRegister((key)m);
        }
    }
}
