Scriptname CombatEyes_PlayerAlias_Script extends ReferenceAlias  

; PROPERTIES
Actor Property PlayerRef Auto
int Property PlayerSex Auto
Race Property PlayerRace Auto
bool Property IsPlayerVampire Auto

FormList Property CombatEyeColorFormList Auto
FormList Property CombatEyeVampireRaceList Auto

Message Property CombatEyes_MessageBox_OnVampirismStateChanged_ForcePrimaryEyeColor Auto
Message Property CombatEyes_Notification_OnMenuClose_StartRestartTask Auto
Message Property CombatEyes_Notification_OnPlayerLoadGame_StartRestartTask Auto
Message Property CombatEyes_Notification_OnVampirismStateChanged_StartRestartTask Auto
Message Property CombatEyes_Notification_OnVampirismStateChanged_VampirismDetected Auto

; PROPERTIES (READ-ONLY)
string Property AnimationEvent_WeaponDraw = "weaponDraw" AutoReadOnly
string Property AnimationEvent_WeaponSheathe = "weaponSheathe" AutoReadOnly
string Property Menu_RaceSexMenu = "RaceSex Menu" AutoReadOnly
int Property HeadPartTypeEyes = 0x02 AutoReadOnly

; VARIABLES
CombatEyes_MCM_Script ceMCM
HeadPart primaryEyeColor
HeadPart combatEyeColor

bool isEyeCheckTickEnabled = false

; CONFIGURATIONS
bool isWeaponDrawnConfigEnabled
bool isEnterCombatConfigEnabled
bool isPlayerDyingConfigEnabled

Event OnInit()
	Debug.Trace("Event 'OnInit' detected, from PlayerAlias_Script")
	Utility.Wait(3.0)

	OnInitialized()
EndEvent

Event OnInitialized()
	Debug.Trace("Event 'OnInitialized' detected, from PlayerAlias_Script")

	PlayerRef = GetReference() as Actor
	ceMCM = GetOwningQuest() as CombatEyes_MCM_Script
	
	GetPlayerInfo()

	primaryEyeColor = GetPrimaryEyeColor()
	combatEyeColor = GetCombatEyeColor(CombatEyeColorFormList)

	GetConfigs()
	Registration()
	CheckEyeColorConditions()

EndEvent

Event OnUpdate()
	Debug.Trace("Event 'OnUpdate' detected")
	
	GetPlayerInfo()

	combatEyeColor = GetCombatEyeColor(CombatEyeColorFormList)
	
	GetConfigs()
	Registration()
	CheckEyeColorConditions()

EndEvent

Event OnPlayerLoadGame()
	Debug.Trace("Event 'OnPlayerLoadGame' detected, from PlayerAlias_Script")

	GetPlayerInfo()

	Utility.Wait(3.0)

	; Account for use case where a player may have added/removed mods or eye color options between saves.  
	; If this is detected, automatically regenerate the menu selection in Combat Eyes MCM and inform the user, to avoid confusion.
	; However, ignore all of this if player is a vampire on game load.
	if(!IsPlayerVampire)
		HeadPart[] newPlayerCombatEyeColorList = ceMCM.GetAllPlayerEyeColorOptions(PlayerSex, PlayerRace)
		if (newPlayerCombatEyeColorList != ceMCM.CombatEyeColorList)
			string startTraceLog = "Eye color option changes detected.  Regenerating combat eye menu selection in 'Combat Eyes' MCM."
			ceMCM.RestartTasks(startTraceLog, CombatEyes_Notification_OnPlayerLoadGame_StartRestartTask)
		endIf
	endIf

	RegisterForSingleUpdate(0.01)
EndEvent

Event OnMenuClose(string menuName)
	if(menuName == Menu_RaceSexMenu)
		Debug.Trace("[OnMenuClose]: Player has exited the race sex menu.")

		primaryEyeColor = GetPrimaryEyeColor()
		int newPlayerSex = PlayerRef.GetActorBase().GetSex()
		Race newPlayerRace = PlayerRef.GetActorBase().GetRace()

		Debug.Trace("[OnMenuClose]: 'newPlayerSex' is: " + newPlayerSex)
		Debug.Trace("[OnMenuClose]: 'PlayerSex' is: " + PlayerSex)
		Debug.Trace("[OnMenuClose]: 'newPlayerRace' is: " + newPlayerRace)
		Debug.Trace("[OnMenuClose]: 'PlayerRace' is: " + PlayerRace)

		; Keep track of whether a player race or sex change has occurred from RaceSexMenu. 
		; If so, we'll want to generate a new combat eye selection menu that is compatible with the player's new race/sex combination
		if((newPlayerSex != PlayerSex) || (newPlayerRace != PlayerRace))
						
			; Generate a new set of forms to "CombatEyeColorList"
			string startTraceLog = "New player race and/or sex detected.  Generating new menu selection in 'Combat Eyes' MCM."
			ceMCM.RestartTasks(startTraceLog, CombatEyes_Notification_OnMenuClose_StartRestartTask)

		endIf
	    RegisterForSingleUpdate(1)
	endif
EndEvent

;/ 
	Event to handle if player changes to a vampire.  
	Interacts further with OnVampirismStateChanged() event.
/;
Event OnRaceSwitchComplete()
	Debug.Trace("Event 'OnRaceSwitchComplete' detected, from PlayerAlias_Script")

	Race newPlayerRace = PlayerRef.GetActorBase().GetRace()
	bool isNewPlayerRaceVampireRace = IsPlayerVampireRace(newPlayerRace)

	; Check to see if player has changed into vampirism OR reverted out of vampirism
	Debug.Trace("[OnRaceSwitchComplete]: 'newPlayerRace' is: " + newPlayerRace)
	Debug.Trace("[OnRaceSwitchComplete]: 'PlayerRace' is: " + PlayerRace)
	Debug.Trace("[OnRaceSwitchComplete]: 'isNewPlayerRaceVampireRace' is: " + isNewPlayerRaceVampireRace)
	Debug.Trace("[OnRaceSwitchComplete]: 'IsPlayerVampire' is: " + IsPlayerVampire)
	if(newPlayerRace != PlayerRace && isNewPlayerRaceVampireRace != isPlayerVampire)

		; We only want to trigger this when a player goes in or out of vampirism.  
		; We do NOT want to trigger this when player goes into different stages of vampirism (i.e. Stage 1 - 4, etc)
		PlayerRef.SendVampirismStateChanged(isNewPlayerRaceVampireRace)
	endIf

EndEvent

;/
	Handles mod behavior based on player's vampire status.
	
	If player transitions to vampirism, unfortunately we have to disable
	mod functionality and its MCM, (due to issues with 
	vampire headpart overlays interfering with general mod behavior, and 
	with no direct way to control it while player is in vampirism). 

	If player transitions out of vampirism, restore mod functionality
	and its MCM.
/;
Event OnVampirismStateChanged(bool abIsVampire)
	Debug.Trace("Function 'OnVampirismStateChanged' detected. State of vampirism is: " + abIsVampire)
	
	Utility.Wait(1.0)
	
	GetPlayerInfo()	
	if(abIsVampire)
		
		Debug.Trace("[OnVampirismStateChanged]: Vampirism detected on player.  Disabling combat eye menu selection in 'Combat Eyes' MCM")
		CombatEyes_Notification_OnVampirismStateChanged_VampirismDetected.Show()

		isEyeCheckTickEnabled = false
		RegisterForSingleUpdate(0.1)
	else

		; Check to make sure we have a record of the player's eye color.  Otherwise force select 
		; a valid eye color for player, based on their sex and race.
		; 
		; This check is done to account for any chance of the "empty eye socket" bug, or 
		; other potentially incorrect eyes when transitioning from vampire back to non-vampire race
		if(primaryEyeColor == None || !IsEyeColorValidForPlayerRace(primaryEyeColor, PlayerRace))
			
			; Log this event and inform user of this issue as well, prior to actually force selecting the eye color for player
			string traceLog = "[OnVampirismStateChanged]: Unable to detect player's original eye color.  Attempting to force a valid eye color for player"
			Debug.Trace(traceLog, 1)
			CombatEyes_MessageBox_OnVampirismStateChanged_ForcePrimaryEyeColor.Show()	

			; Force select a valid eye color for player, based on player's sex and race.
			primaryEyeColor = ceMCM.GetAllPlayerEyeColorOptions(PlayerSex, PlayerRace)[0]
			ChangePlayerEyeColor(primaryEyeColor)			
		endIf
		
		RegisterForSingleUpdate(0.1)
		
		; Generate a new set of forms to "CombatEyeColorList"
		string startTraceLog = "Vampirism no longer detected on player.  Regenerating combat eye menu selection in 'Combat Eyes' MCM"
		ceMCM.RestartTasks(startTraceLog, CombatEyes_Notification_OnVampirismStateChanged_StartRestartTask)
	endIf
EndEvent

Event OnAnimationEvent(ObjectReference akSource, String asEventName)
	
	Debug.Trace("Event 'OnAnimationEvent' detected")
	Debug.Trace("[OnAnimationEvent]: isPlayerVampire is " + isPlayerVampire)
	Debug.Trace("[OnAnimationEvent]: isWeaponDrawnConfigEnabled is " + isWeaponDrawnConfigEnabled)

	if (!isPlayerVampire)
		; Change player eyes if toggle setting for draw/sheathe is enabled.
		if (isWeaponDrawnConfigEnabled)
			if (asEventName == AnimationEvent_WeaponDraw || asEventName == AnimationEvent_WeaponSheathe)
				CheckEyeColorConditions()
			endIf
		endif
	endIf
EndEvent

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
	
	Debug.Trace("Event 'OnHit' detected")
	Debug.Trace("[OnHit]: isPlayerVampire is: " + isPlayerVampire)
	Debug.Trace("[OnHit]: isEnterCombatConfigEnabled is: " + isEnterCombatConfigEnabled)

	if (!isPlayerVampire)
		; Change player eyes if toggle setting for combat is enabled.
		if (isEnterCombatConfigEnabled)
			RegisterForSingleUpdate(0.01)
		endIf
	endIf
EndEvent

Function GetPlayerInfo()
	PlayerSex = PlayerRef.GetActorBase().GetSex()
	PlayerRace = PlayerRef.GetActorBase().GetRace()
	IsPlayerVampire = IsPlayerVampireRace(PlayerRace)

	Debug.Trace("[GetPlayerInfo]: PlayerSex is: " + PlayerSex)
	Debug.Trace("[GetPlayerInfo]: PlayerRace is: " + PlayerRace)
	Debug.Trace("[GetPlayerInfo]: IsPlayerVampire is: " + IsPlayerVampire)
EndFunction

Function GetConfigs()
	isWeaponDrawnConfigEnabled = ceMCM.isWeaponDrawnConfigEnabled
	isEnterCombatConfigEnabled = ceMCM.isEnterCombatConfigEnabled
	isPlayerDyingConfigEnabled = ceMCM.isPlayerDyingConfigEnabled
EndFunction

Function Registration()
    RegisterForAnimationEvent(PlayerRef, AnimationEvent_WeaponDraw)
    RegisterForAnimationEvent(PlayerRef, AnimationEvent_WeaponSheathe)
	RegisterForMenu(Menu_RaceSexMenu)
EndFunction

; Retrieve the primary eye color that is currently set 
; on the player
HeadPart Function GetPrimaryEyeColor()
	Debug.Trace("Function 'GetPrimaryEyeColor' detected")

	int i = 0
    int numHeadParts = PlayerRef.GetActorBase().GetNumHeadParts()
	
	HeadPart eyeColor
    while (i < numHeadParts)
        
        int headPartType = PlayerRef.GetActorBase().GetNthHeadPart(i).GetType()

        if(headPartType == HeadPartTypeEyes)
            eyeColor = PlayerRef.GetActorBase().GetNthHeadPart(i)
        endIf

        i += 1

    endWhile

    Debug.Trace("[GetPrimaryEyeColor]: Player eye color: " + eyeColor.GetName())
    return eyeColor

EndFunction

; Retrieve the player's combat eye color from
; the 'CombatEyeColorFormList', based on what was chosen from
; the mod configuration menu.
HeadPart Function GetCombatEyeColor(FormList fList)
	Debug.Trace("Function 'GetCombatEyeColor' detected")
	
	; Retrieve combatEyeColor from selection within MCM
	HeadPart eyeColor = fList.GetAt(ceMCM.CombatEyeColorOptionIndex) as HeadPart
    return eyeColor

EndFunction

; The primary function that's responsible for switching player's 
; eyes between chosen primary eye color & combat eye color, 
; based on several conditions.
Function CheckEyeColorConditions()

	Debug.Trace("Function 'CheckEyeColorConditions' detected")
	Debug.Trace("[CheckEyeColorConditions]: isPlayerVampire is: " + isPlayerVampire)

	if (!isPlayerVampire)
		bool isEligibleForCombatEyes = IsPlayerEligibleForCombatEyes()

		Debug.Trace("[CheckEyeColorConditions]: 'isEligibleForCombatEyes' is: " + isEligibleForCombatEyes)
		Debug.Trace("[CheckEyeColorConditions]: 'isEyeCheckTickEnabled' is: " + isEyeCheckTickEnabled)

		if (isEligibleForCombatEyes)
			; Update eye color to player
			Debug.Trace("[CheckEyeColorConditions]: Setting to combat eyes: " + combatEyeColor.GetName())
			ChangePlayerEyeColor(combatEyeColor)

		else
			; Update eye color to player
			Debug.Trace("[CheckEyeColorConditions]: Setting to primary eyes: " + primaryEyeColor.GetName())
			ChangePlayerEyeColor(primaryEyeColor)
		endIf
	else
		Debug.Trace("[CheckEyeColorConditions]: Skipping 'CheckEyeColorCondition' check, due to player vampirism", 1)
	endIf

	; This condition triggers a check for combat eye eligibility periodically.  
	; This way the script only has to check for this under certain conditions
	if (isEyeCheckTickEnabled)
		Debug.Trace("[CheckEyeColorConditions]: 'isEyeCheckTickEnabled' set to '" + isEyeCheckTickEnabled + "'. Triggering a new update to check eye color conditions")
		RegisterForSingleUpdate(5)
	endIf
EndFunction

; Checks several conditions to determine if player should
; display combat eye color or not.
bool Function IsPlayerEligibleForCombatEyes()

	Debug.Trace("Function 'IsEligibleForCombatEyes' detected")
	
	bool isEligibleForCombatEyes = false

	; If player is a vampire, they would be ineligible to use mod
	; functionality.  Please stop here and don't allow script
	; to proceed through remainder of this function. 
	if(IsPlayerVampire)
		isEyeCheckTickEnabled = false
		return isEligibleForCombatEyes
	endIf

	; Combat or weapon drawn
	if ((isEnterCombatConfigEnabled && PlayerRef.IsInCombat()) || (isWeaponDrawnConfigEnabled && PlayerRef.IsWeaponDrawn()))
		
		isEligibleForCombatEyes = true

		; Enable additional 'isEyeCheckTickEnabled', which tells the script to continue checking for combat eye eligibility on a periodic basis
		isEyeCheckTickEnabled = true
	endIf

	; Player health less than or equal to 20% health
	bool isPlayerBelowHealthThreshold = (PlayerRef.GetAVPercentage("health") <= 0.2)

	if(isPlayerBelowHealthThreshold)
		Debug.Trace("Player is dying")
		if(isPlayerDyingConfigEnabled)
			isEligibleForCombatEyes = true
		else
			isEligibleForCombatEyes = false
		endIf
	endIf

	; If 'isEyeCheckTickEnabled' is still true, then under additional 
	; appropriate conditions, disable this check to inform script to stop 
	if(isEyeCheckTickEnabled && !PlayerRef.IsInCombat() && !PlayerRef.IsWeaponDrawn() && !isPlayerBelowHealthThreshold)
		isEyeCheckTickEnabled = false
	endIf

	return isEligibleForCombatEyes
EndFunction

Function ChangePlayerEyeColor(HeadPart eyeColor)
	PlayerRef.ChangeHeadPart(eyeColor)
EndFunction

; Check if player is currently a vampire race
bool Function IsPlayerVampireRace(Race playerRaceParam)
	Debug.Trace("Function 'IsPlayerVampireRace' detected")

	bool IsPlayerVampireRace = false

	int i = 0

	FormList listOfVampireRaces = CombatEyeVampireRaceList
	int listOfVampireRacesCount = listOfVampireRaces.GetSize()

	while (i < listOfVampireRacesCount)

		if(playerRaceParam == listOfVampireRaces.GetAt(i) as Race)
		
			; Found a match, meaning player is a vampire
			IsPlayerVampireRace = true

			; Already found a match, so no need to iterate through remaining entries
			; Break out of while-loop early to help script performance
			i = listOfVampireRacesCount - 1
		endIf

		i += 1
	endWhile

	return IsPlayerVampireRace

EndFunction

; Checks if the current eye color on the player is valid for the player's race.
; Currently used to check after player has transitioned from a vampire to non-vampire race
bool Function IsEyeColorValidForPlayerRace(HeadPart hPart, Race playerRaceParam)
	
	Debug.Trace("Function 'IsEyeColorValidForPlayerRace' detected")
	bool isValid = false
	
	int headPartType = hPart.GetType()
	
	if(headPartType == HeadPartTypeEyes)
		
		FormList list = hPart.GetValidRaces()

		int i = 0
		int listCount = list.GetSize()

		while (i < listCount)
		
			if(playerRaceParam == list.GetAt(i) as Race)

				; We found a match
				isValid = true

				; Already found a match, so no need to iterate through remaining entries
				; Break out of while-loop early to help script performance
				i = listCount - 1

			endIf
			
			i += 1

		endWhile
	else
		Debug.Trace("[IsEyeColorValidForPlayerRace]: Provided head part param is type: '" + headPartType + "''. Head part for this function must be type '" + HeadPartTypeEyes + "'.", 2)
	endIf

	return isValid

EndFunction

; MAKE USE OF THIS FOR POTENTIAL VAMPIRE RACE COMPATIBILITY
HeadPart Function GetEyeColorOverlay()
	Debug.Trace("Function 'GetEyeColorOverlay' detected")

	ActorBase playerActorBase = PlayerRef.GetActorBase()

	int i = 0
	int numOfEyeHeadPartsOnVampire = 0
    int numOverlayHeadParts = playerActorBase.GetNumOverlayHeadParts()
	
	HeadPart eyeHeadPartOverlay
    while (i < numOverlayHeadParts)
        
		HeadPart h = playerActorBase.GetNthOverlayHeadPart(i)
		int headPartType = playerActorBase.GetNthOverlayHeadPart(i).GetType()

        if(headPartType == HeadPartTypeEyes)
            eyeHeadPartOverlay = playerActorBase.GetNthOverlayHeadPart(i)
			Debug.Trace("[GetEyeColorOverlay]: Detected 'eyePart' on vampire (" + isPlayerVampire + "): " + eyeHeadPartOverlay.GetPartName())
			numOfEyeHeadPartsOnVampire += 1
        endIf

        i += 1

    endWhile

	Debug.Trace("[GetEyeColorOverlay]: numOfEyeHeadPartsOnVampire found on vampire (" + isPlayerVampire + ") is: " + numOfEyeHeadPartsOnVampire)

	if(numOfEyeHeadPartsOnVampire > 1)
		Debug.Trace("[GetEyeColorOverlay]: Detected multiple eye overlays", 2)
	endIf

	return eyeHeadPartOverlay

EndFunction
