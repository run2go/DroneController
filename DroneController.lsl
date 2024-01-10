// DroneController.lsl 
// Author & Repository: https://github.com/run2go/DroneController
// License: MIT

// Configuration Parameters
float   RATE = 0.1; // Tick rate for position updates
float   TIMER = 2.5; // Time in seconds until reset
float   RANGE = 128.0; // Detection range, 4096m max
float   HEIGHT = 1.5; // Hover height above the owner in meters
float   DISTANCE = 0.5; // Distance between the drones for conducting
float   ROTATING = 2.0; // Rotation increments in degrees per tick
integer CHANNEL = 9871; // Gesture & comms channel for the drones

vector GetRestPos()        { return llGetPos() + <0, 0, HEIGHT>; }
vector GetAgentPos(key id) { return llList2Vector(llGetObjectDetails(id, ([OBJECT_POS])), 0); }
TrackPos(vector pos)       { llRegionSay(CHANNEL, (string)pos); }

key kAgent;
vector vTarget;
RayCast() {
    llRequestPermissions(llGetOwner(), 0x400); // Track Camera permissions
    vector start = llGetCameraPos();
    vector end = start + <RANGE, 0.0, 0.0> * llGetCameraRot();
    list data = llCastRay(start, end, []);
    
    if (llGetListLength(data) > 1) { // Check if an object was hit
        kAgent = llList2Key(data, 0);
        vTarget = llList2Vector(data, 1);  // Else use target position
        if (llKey2Name(llList2Key(data, 0)) != "") llSetText("[Track]\n " + llKey2Name(kAgent), <0.3,1,0.5>, 1.0);
        else llSetText("[Track]\n " + (string)vTarget, <0.8,1,0.3>, 1.0);
        nTicks = 0;
        llSetTimerEvent(RATE);
    }
}

list arDrones;
DroneRegister(key droneKey) { // Add the new key to arDrones
    if (llListFindList(arDrones, [droneKey]) == -1) arDrones += [droneKey];
}

integer nActiveDrones = 0;
integer bPolygon = FALSE;
float rotIncrement = 0;
DroneConduct() {
    vector restTarget = GetRestPos();
    if (bPolygon && nActiveDrones != 1) { // Polygon mode if more than 1 active drones
        integer i;
        rotIncrement += ROTATING; // Increment rotation globally
        for (i = 0; i <= nActiveDrones; i++) {
            vector droneTarget = restTarget;
            float dynamicDistance = DISTANCE * llSqrt(nActiveDrones); // Dynamically adjust the distance
            
            // Calculate the angle
            float angle = TWO_PI * i / nActiveDrones + rotIncrement * DEG_TO_RAD;

            // Calculate the offset
            float xOffset = dynamicDistance * llCos(angle);
            float yOffset = dynamicDistance * llSin(angle);
            
            // Update drone position
            droneTarget.x += xOffset;
            droneTarget.y += yOffset;
            
            // Send the updated position to the corresponding drone
            if (llList2Key(arDrones, i) != NULL_KEY) llRegionSayTo(llList2Key(arDrones, i), CHANNEL, (string)droneTarget);
        } if (rotIncrement >= 360.0) rotIncrement -= 360.0; // Adjust rotation to keep it within [0, 360) degrees
    } else TrackPos(restTarget); // Else move all drones to the same spot
    llSetText("[Holding]\nDrones: " + (string)nActiveDrones, <1,1,1>, 0.7);
}

DronePolyToggle(integer bSwitch) {
    DroneCheck();
    bPolygon = bSwitch;
}

integer nTicksTotal;
integer nTicks;
integer nCheckTick = 0;
DroneMode() {
    nActiveDrones = llGetListLength(arDrones);
    integer bChasing = nTicks < nTicksTotal;
    if (bChasing) { // Chasing
        nTicks++;
        if (kAgent != NULL_KEY) TrackPos(GetAgentPos(kAgent));
        else if (vTarget != ZERO_VECTOR) TrackPos(vTarget);
        nCheckTick = 0;
    } else { // Idling
        DroneConduct();
        nCheckTick++;
    } if (!bChasing && nCheckTick > 50) DroneCheck();
}

integer bActive = FALSE;
DroneToggle(integer bSwitch) {
    if (bSwitch) { // Turn on
        DroneCheck();
        llSetTimerEvent(RATE);
    } else { // Turn off
        llSetTimerEvent(0);
        llSetText("[~]", <1,1,1>, 0.5);
        llRegionSay(CHANNEL, "dStop");
        arDrones = [];
    }
}

DroneCheck() {
    arDrones = [];
    nCheckTick = 0;
    llRegionSay(CHANNEL, "dCheck");
}

DroneCreate() {
    DroneCheck();
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0), GetRestPos(), ZERO_VECTOR, ZERO_ROTATION, 0);
}

DroneDie() {
    DroneToggle(bActive = FALSE);
    llRegionSay(CHANNEL, "dDie");
}

integer numberOfRows    = 1;
integer numberOfColumns = 4;
NavButton(integer n) {
    integer linkNum     = llDetectedLinkNumber(0);
    vector  touchST     = llDetectedTouchST(0);

    integer columnIndex = (integer)(touchST.x * numberOfColumns);
    integer rowIndex    = (integer)(touchST.y * numberOfRows);
    integer cellIndex   = (rowIndex * numberOfColumns) + columnIndex;
    
    if (linkNum == 0) { // HUD Button
        if      (cellIndex == 0) DroneToggle(bActive = !bActive);
        else if (cellIndex == 1) DronePolyToggle(bPolygon = !bPolygon);
        else if (cellIndex == 2) DroneCreate();
        else if (cellIndex == 3) DroneDie();
    } //else llOwnerSay((string)linkNum); // Placeholder
}
default {
    touch_start(integer n)  { if (llDetectedKey(0) == llGetOwner()) NavButton(n); }
    attach(key id)          { llResetScript(); }
    timer()                 { DroneMode(); }
    state_entry() {
        llListen(CHANNEL, "", "", "");
        llSetText("[~]", <1,1,1>, 0.5);
        nTicksTotal = nTicks = (integer)(TIMER / RATE);
    }
    listen(integer c, string n, key id, string m) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if      (m == "toggle") DroneToggle(bActive = !bActive);
            else if (m == "trigger" && bActive) RayCast();
            else if (m == "dDie") DroneDie();
            else if (m != NULL_KEY) DroneRegister((key)m);
        }
    }
}