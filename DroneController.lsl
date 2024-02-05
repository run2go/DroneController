// DroneController.lsl 
// Author & Repository: https://github.com/run2go/DroneController
// License: MIT
// Version: 1.3.4

// Configuration Parameters
float   RATE     = 0.1;  // Tick rate for position updates
float   CHECK    = 5.0;  // Health check interval for arDrones
float   TIMER    = 2.5;  // Time in seconds until reset
float   RANGE    = 128;  // Detection range, 4096m max
float   HEIGHT   = 1.5;  // Hover height above the owner in meters
float   DISTANCE = 0.2;  // Distance between the drones for conducting
float   ROTATING = 3.0;  // Rotation increments in degrees per tick
integer CHANNEL  = 9871; // Channel for the gestures commands

// Helper Variables
float   fDist = DISTANCE;
float   fRot  = ROTATING;
integer dynChannel;

vector GetRestPos()        { return llGetPos() + <0, 0, HEIGHT>; }
vector GetAgentPos(key id) { return llList2Vector(llGetObjectDetails(id, ([OBJECT_POS])), 0); }
TrackPos(vector pos)       { llRegionSay(dynChannel, (string)pos); }

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
        if (llKey2Name(llList2Key(data, 0)) != "") HoverText(2, llKey2Name(kAgent));
        else HoverText(2, (string)vTarget);
        nTick = 0;
        bChase = TRUE;
    }
}

list arDrones;
DroneRegister(key droneKey) { // Add the new key to arDrones
    if (llListFindList(arDrones, [droneKey]) == -1) arDrones += [droneKey];
}
DroneCheck(integer bFull) {
    if (bFull) {
        llRegionSay(dynChannel, "dCheck");
        nTick = 0;
    } else llRegionSay(dynChannel, "dReg");
    arDrones = [];
}

integer nDrones = 0;
integer bPoly = FALSE;
float fRotation = 0;
DroneConduct() {
    vector vResting = GetRestPos();
    if (bPoly && nDrones > 1) { // Polygon mode if more than 1 active drones
        integer i;
        fRotation += fRot; // Increment rotation globally
        for (i = 0; i <= nDrones; i++) {
            vector vDrone = vResting;
            float fDistance = fDist * nDrones; // Dynamically adjust the distance
            float fAngle = TWO_PI * i / nDrones + fRotation * DEG_TO_RAD; // Calculate the angle
            
            vDrone.x += fDistance * llCos(fAngle); // Update drone position with the offset
            vDrone.y += fDistance * llSin(fAngle);
            
            llRegionSayTo(llList2Key(arDrones, i), dynChannel, (string)vDrone); // Send vector to drone
        } if (fRotation >= 360.0) fRotation -= 360.0; // Adjust rotation to keep it within [0, 360) degrees
    } else TrackPos(vResting); // Else move all drones to the same spot
    HoverText(1, "");
}
DronePolyToggle() {
    bPoly = !bPoly;
    fDist = DISTANCE;
    fRot  = ROTATING;
}

integer bChase = FALSE;
integer nTick = 100;
DroneRun() {
    nDrones = llGetListLength(arDrones);
    if (bActive) {
        bPausing = FALSE;
        if (bChase) { // Chasing
            if (kAgent != NULL_KEY) TrackPos(GetAgentPos(kAgent));
            else if (vTarget != ZERO_VECTOR) TrackPos(vTarget);
        } else DroneConduct(); // Idling
    } else if (!bPausing) DronePause();
    else HoverText(0, "");
    if (nTick > (integer)(CHECK / RATE) && !bChase && !bPausing) DroneCheck(TRUE);
    if (nTick > (integer)(TIMER / RATE)) bChase = FALSE;
    if (bShowCounter) HoverTextHelper();
    nTick++;
}

integer bActive = FALSE;
integer bPausing = FALSE;
DronePause() {
    llRegionSay(dynChannel, "dStop");
    bPausing = TRUE;
    bChase = FALSE;
    DroneCheck(FALSE);
    //HoverText(0, "");
    TargetClear();
}

DroneCreate() {
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0), GetRestPos(), ZERO_VECTOR, ZERO_ROTATION, 0);
}

DroneDelete() {
    llRegionSayTo(llList2Key(arDrones, nDrones-1), dynChannel, "dDie");
    DroneCheck(FALSE);
}

DronePurge() {
    llRegionSay(dynChannel, "dDie");
    DroneCheck(TRUE);
}

integer bShowCounter = 0;
HoverTextHelper() {
    if (bShowCounter > (TIMER / RATE)) {
        stRowStatus = " ";
        bShowCounter = 0;
    } else bShowCounter++;
}
vector vColor;
string stRowStatus = " ";
HoverText(integer nMode, string stText) {
    string stRow1 = " ";
    string stRow2 = "[Drones] " + (string)nDrones;
    string br = "\n";
    float  fAlpha = 1.0;
    
    if (nMode == 0) {
        stRow1 = "💤";
        fAlpha = 0.75;
    } else if (nMode == 1) {
        if (bPoly) stRow1 = "[State] Polygon";
        else       stRow1 = "[State] Default";
    } else if (nMode == 2) {
        stRow1 = "[Target] " + stText;
    }
    string stHover = stRow1 +br+ stRow2 +br+ stRowStatus;
    llSetText(stHover, vColor, fAlpha);
}

string StatusHUD(integer bool) { if (bool) return "On"; else return "Off"; }
integer NavHelper(integer nCols, integer nRows, vector vTouch) {
    integer nCol = (integer)(vTouch.x * nCols);
    integer nRow = (integer)(vTouch.y * nRows);
    return (nRow * nCols) + nCol;
}
NavButton(integer n) {
    integer nLink   = llDetectedLinkNumber(0);
    vector  vTouch  = llDetectedTouchST(0);
    integer bButton = (vTouch.y <= 0.75); // Is touch on button
    if (nLink == 0 && bButton) {
        integer nCell = NavHelper(5, 1, vTouch);
        if      (nCell == 0) { stRowStatus = "> Controller " + (string)StatusHUD(bActive = !bActive) + " <"; }
        else if (nCell == 1) { stRowStatus = "> Mode Changed <"; DronePolyToggle(); }
        else if (nCell == 2) { stRowStatus = "> Drone Created <"; DroneCreate(); }
        else if (nCell == 3) { stRowStatus = "> Drone Deleted <"; DroneDelete(); }
        else if (nCell == 4) { stRowStatus = "> Drones Purged <"; DronePurge(); }
    } else if (nLink == 0) {
        integer nCell = NavHelper(2, 1, vTouch);
        if      (nCell == 0) { fRot  = (vTouch.x - 0.0) / 0.5 * 25.0; stRowStatus = "> Rotation "+llGetSubString((string)(fRot/25*100), 0, 3)+"% <"; }
        else if (nCell == 1) { fDist = (vTouch.x - 0.5) / 0.5 * 1.0;  stRowStatus = "> Distance "+llGetSubString((string)(fDist*100), 0, 3)+"% <"; }
    } bShowCounter = 1; // Start counter
}
default { 
    touch_start(integer n) { if (llDetectedKey(0) == llGetOwner()) NavButton(n); }
    attach(key id)         { llResetScript(); }
    changed(integer c)     { if (c == CHANGED_COLOR) llResetScript(); }
    timer()                { DroneRun(); }
    state_entry() {
        dynChannel = (integer)("0x" + llGetSubString(llGetOwner(), 0, 7));
        llListen(dynChannel, "", "", "");
        llListen(CHANNEL, "", "", "");
        llSetTimerEvent(RATE);
        vColor = llGetColor(0);
    }
    listen(integer c, string n, key id, string m) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if      (c == dynChannel && (key)m != NULL_KEY) DroneRegister((key)m);
            else if (c == CHANNEL && m == "trigger" && bActive) DroneTarget();
            else if (c == CHANNEL && m == "toggle") {
                stRowStatus = "> Controller " + (string)StatusHUD(bActive = !bActive) + " <";
                bShowCounter = 1;
            }
        }
    }
}
