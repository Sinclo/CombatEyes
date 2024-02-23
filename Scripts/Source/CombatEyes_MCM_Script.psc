Scriptname CombatEyes_MCM_Script extends SKI_ConfigBase  

; PROPERTIES
Actor Property PlayerRef Auto

HeadPart[] Property CombatEyeColorList Auto
FormList Property CombatEyeColorFormList Auto
int Property CombatEyeColorOptionIndex Auto

Message Property CombatEyes_MessageBox_GenerateFinalCombatEyeColorList_MultipleProcessesDetected Auto
Message Property CombatEyes_Notification_FinishRestartTask Auto
Message Property CombatEyes_Notification_OnConfigClose_StartRestartTask Auto

; PROPERTIES (READ-ONLY)
int Property ExpectedHeadPartType = 0x02 AutoReadOnly

; VARIABLES
CombatEyes_PlayerAlias_Script ceAlias
string[] combatEyeColorMCMOptions

bool isLocked = false ; Default to false

; PROPERTIES / MCM CONFIGURATIONS
bool Property isWeaponDrawnConfigEnabled Auto
bool Property isEnterCombatConfigEnabled Auto
bool Property isPlayerDyingConfigEnabled Auto
bool isResetMCMOptionsEnabled

; MCM CONFIGURATION FLAGS
int isPlayerDyingConfigOptionFlag
int isResetMCMOptionsOptionFlag

; MCM PAGE NAMES
string page1 = "Combat Eyes"

Event OnConfigInit()
    Debug.Trace("Event 'OnConfigInit' detected, from MCM_Script")
    
    Pages = new string[1]
    Pages[0] = page1

    ceAlias = (GetAlias(0) as CombatEyes_PlayerAlias_Script)
    
    LoadDefaultMCMSettings()
    StartTasks()
EndEvent

Event OnGameReload()
    Debug.Trace("Event 'OnGameReload' detected, from MCM_Script")
    parent.OnGameReload()

    Utility.Wait(5.0)
    OnConfigInit()
EndEvent

Event OnConfigClose()
    Debug.Trace("Event 'OnConfigClose' detected")

    if(isResetMCMOptionsEnabled)
                
        isResetMCMOptionsEnabled = false

        string log = "Regenerating combat eye menu selection in 'Combat Eyes' MCM."
        RestartTasks(log, CombatEyes_Notification_OnConfigClose_StartRestartTask)
        
    endIf

    ; Provides updated MCM settings to player alias script
    ceAlias = (GetAlias(0) as CombatEyes_PlayerAlias_Script)
    ceAlias.RegisterForSingleUpdate(0)
EndEvent

Event OnPageReset(string page)

    if (page == page1)

        SetCursorFillMode(TOP_TO_BOTTOM)

        ; LEFT COLUMN
        SetCursorPosition(0) 

        ; "Select Combat Eye Color" section
        AddHeaderOption("Select Combat Eye Color")

        ; If player is a vampire, disable combat eye menu selection for now
        if(ceAlias.IsPlayerVampire)
            AddTextOption("", "Combat Eyes mod is currently ", OPTION_FLAG_DISABLED)
            AddTextOption("", "unsupported for vampire races.", OPTION_FLAG_DISABLED)

        ; If menu initialization is in progress, inform user
        elseIf(isLocked)
            AddTextOption("", "Menu initialization in progress...", OPTION_FLAG_DISABLED)
            AddTextOption("", "Check back again in a moment...", OPTION_FLAG_DISABLED)
        
        ; If we can't find any valid eye color headparts for the player's race & sex, inform user
        elseIf (CombatEyeColorFormList.GetSize()<= 0 && combatEyeColorMCMOptions.Length <= 0)
            AddTextOption("", "Unable to find valid eye colors ", OPTION_FLAG_DISABLED)
            AddTextOption("", "for the player's race and sex. ", OPTION_FLAG_DISABLED)
        
        ; Display combat eye color MCM options for user to select
        else
            AddMenuOptionST("SelectCombatEyeStateOption", "", combatEyeColorMCMOptions[CombatEyeColorOptionIndex])
        endIf

        AddEmptyOption()

        ; "Conditions to enable combat eyes" section
        AddHeaderOption("Conditions to enable combat eyes")

        AddToggleOptionST("WeaponDrawnConfigStateOption", "When player draws weapon/magic", isWeaponDrawnConfigEnabled)
        AddToggleOptionST("EnterCombatConfigStateOption", "When player is attacked", isEnterCombatConfigEnabled)
        
        AddEmptyOption()
        
        
        ; RIGHT COLUMN
        SetCursorPosition(1)

        ; "Additional configurations" section
        AddHeaderOption("Additional Conditions")
        
        if(!IsPlayerDyingConfigPrerequisitesMet())  
            ; Hardcode to false and disable this configuration, if none of the other prerequisite configurations are enabled
            isPlayerDyingConfigOptionFlag = OPTION_FLAG_DISABLED
            isPlayerDyingConfigEnabled = false
        else
            isPlayerDyingConfigOptionFlag = OPTION_FLAG_NONE
        endIf
        AddToggleOptionST("PlayerDyingConfigStateOption", "Persist combat eyes if player is dying", isPlayerDyingConfigEnabled, isPlayerDyingConfigOptionFlag)

        AddEmptyOption()

        ; "Miscellaneous" section
        AddHeaderOption("Miscellaneous")

        if(!IsResetMCMOptionPrerequisitesMet())  
            isResetMCMOptionsOptionFlag = OPTION_FLAG_DISABLED
        else
            isResetMCMOptionsOptionFlag = OPTION_FLAG_NONE
        endIf
        AddToggleOptionST("ResetMCMStateOptions", "Reset combat eye menu selection", isResetMCMOptionsEnabled, isResetMCMOptionsOptionFlag)

    endIf

EndEvent

State SelectCombatEyeStateOption

    Event OnMenuOpenST()
        SetMenuDialogOptions(combatEyeColorMCMOptions)
        SetMenuDialogStartIndex(CombatEyeColorOptionIndex) ; Designed to save the last option selected by end-user, to improve user experience.
        SetMenuDialogDefaultIndex(CombatEyeColorOptionIndex)
    EndEvent

    Event OnMenuAcceptST(int index)
        CombatEyeColorOptionIndex = index
        SetMenuOptionValueST(combatEyeColorMCMOptions[CombatEyeColorOptionIndex])
    EndEvent

    Event OnHighlightST()
        SetInfoText("Select combat eyes to apply to player.")
    EndEvent

EndState

State WeaponDrawnConfigStateOption

    Event OnSelectST()
        if (isWeaponDrawnConfigEnabled)
            isWeaponDrawnConfigEnabled = false
        else
            isWeaponDrawnConfigEnabled = true
        endIf

        ; Update isPlayerDyingConfig if necessary
        if(!IsPlayerDyingConfigPrerequisitesMet())
            isPlayerDyingConfigOptionFlag = OPTION_FLAG_DISABLED

            SetToggleOptionValueST(false, false, "PlayerDyingConfigStateOption")
        else
            isPlayerDyingConfigOptionFlag = OPTION_FLAG_NONE
        endIf
        
        SetToggleOptionValueST(isWeaponDrawnConfigEnabled)
        SetOptionFlagsST(isPlayerDyingConfigOptionFlag, false, "PlayerDyingConfigStateOption")
    EndEvent

    Event OnHighlightST()
        SetInfoText("Enable combat eyes when player draws their weapon, magic, or both.")
    EndEvent

EndState

State EnterCombatConfigStateOption

    Event OnSelectST()
        if (isEnterCombatConfigEnabled)
            isEnterCombatConfigEnabled = false
        else
            isEnterCombatConfigEnabled = true
        endIf

        ;Update isPlayerDyingConfig if necessary
        if(!IsPlayerDyingConfigPrerequisitesMet())
            isPlayerDyingConfigOptionFlag = OPTION_FLAG_DISABLED

            SetToggleOptionValueST(false, false, "PlayerDyingConfigStateOption")
        else
            isPlayerDyingConfigOptionFlag = OPTION_FLAG_NONE
        endIf

        SetToggleOptionValueST(isEnterCombatConfigEnabled)
        SetOptionFlagsST(isPlayerDyingConfigOptionFlag, false, "PlayerDyingConfigStateOption")
    EndEvent

    Event OnHighlightST()
        SetInfoText("Enable combat eyes when player is attacked in combat.")
    EndEvent

EndState

State PlayerDyingConfigStateOption

    Event OnSelectST()
        if (isPlayerDyingConfigEnabled)
            isPlayerDyingConfigEnabled = false
        else
            isPlayerDyingConfigEnabled = true
        endIf

        SetToggleOptionValueST(isPlayerDyingConfigEnabled)
    EndEvent

    Event OnHighlightST()
        SetInfoText("If disabled, player will temporarily lose combat eyes while below 20% health.  If enabled, player will continue to persist combat eyes even while below 20% health.")
    EndEvent

EndState

State ResetMCMStateOptions

    Event OnSelectST()
        if (isResetMCMOptionsEnabled)
            isResetMCMOptionsEnabled = false
        else
            isResetMCMOptionsEnabled = true
            ShowMessage("If this setting is left enabled, the combat eye menu selection will be reinitialized again after exiting this menu. Please wait up to a few seconds. You will receive a notification once menu initialization is complete.", false)
        endIf
        
        SetToggleOptionValueST(isResetMCMOptionsEnabled)
    EndEvent

    Event OnHighlightST()
        SetInfoText("If enabled, combat eye selection menu will be reinitialized again after exiting this menu. Useful if you don't see your expected set of eye colors, and want to refresh the menu.")
    EndEvent

EndState

Function StartTasks()

    CombatEyeColorOptionIndex = 0

    ; Unlock the process here anytime this method is called. 
    ; Note: This is designed so that if "StartTasks()" is ever triggered while eye generation is currently in process, we interrupt and stop that process prematurely, 
    ; prior to this iteration starting.
    isLocked = false 
    Utility.Wait(1)

    ; Generate unique 'processId' for the generate combat eyes process.  Designed for logging purposes.
    string processId = Utility.GetCurrentRealTime() + "-" + Utility.RandomFloat()
    GenerateFinalCombatEyeColorList(processId)

EndFunction

Function RestartTasks(string startTraceLog, Message startMsgLog)

    ; Clear out old forms from "CombatEyeColorList"
    CombatEyeColorFormList.Revert()
    
    ; Dynamic start logs for "RestartTasks() function"
    Debug.Trace(startTraceLog)
    startMsgLog.Show()        
    
    StartTasks()

    ; Hardcoded finish logs for "RestartTasks()" function
    string finishTraceLog = "New combat eye list has finished generating in the 'Combat Eyes' MCM."
    Debug.Trace(finishTraceLog)
    CombatEyes_Notification_FinishRestartTask.Show()

EndFunction

Function GenerateFinalCombatEyeColorList(string processId)

    int playerSex = PlayerRef.GetActorBase().GetSex()
    Race playerRace = PlayerRef.GetActorBase().GetRace()

    Debug.Trace("[GenerateFinalCombatEyeColorList]: 'isLocked' is: " + isLocked)

    ; Condition to put a lock on combat eye list menu generation, and prevent possibility of multiple processes running at the same time
    if(!isLocked)
        Debug.Trace("[GenerateFinalCombatEyeColorList]: Eye generation processId '" + processId + "' has started.")
        isLocked = true
        CombatEyeColorFormList = GetCombatEyeColorFormList(playerSex, playerRace, processId)
        combatEyeColorMCMOptions = GetCombatEyeColorMCMOptions(CombatEyeColorFormList, processId)
        isLocked = false
        Debug.Trace("[GenerateFinalCombatEyeColorList]: Eye generation processId '" + processId + "' has finished.")
    else
        ; Should ultimately never hit this condition, but provided as a safe guard just in case
        Debug.Trace("[GenerateFinalCombatEyeColorList]: Combat eye menu generation already in progress.  Stopping all processes so a new one can be triggered manually.", 1)
        isLocked = false
        CombatEyes_MessageBox_GenerateFinalCombatEyeColorList_MultipleProcessesDetected.Show()
    endIf

EndFunction

FormList Function GetCombatEyeColorFormList(int playerSex, Race playerRace, string processId)

    ; Save this as a property, to also be used for comparison when player loads into game
    CombatEyeColorList = GetAllPlayerEyeColorOptions(playerSex, playerRace)
    
    int i = 0
    int count = CombatEyeColorList.Length

    while (i < count)
    
        ; Check if lock is in place during each iteration, in case the eye generation process gets interrupted by a new "StartTask()" process.
        ; This way if an end user triggers a new process while the current process is still running somehow, we stop the current process and let the new process run.
        ;
        ; Why this is important:
        ;   - Use case #1: User continously enters race menu, chooses a race or sex, exits race menu, repeat 2-3+ times within a short period.
        ;   - Use case #2: User manually triggers a new process from the MCM while a current process is already running.
        ; In both cases, the use cases can result in invalid eye color selections displaying for the player (i.e. MaleArgonian eyes displaying for female wood elves, etc).  This check
        ; is designed to prevent this use case from occurring for end users. 
        if(isLocked)
            CombatEyeColorFormList.AddForm(CombatEyeColorList[i])
            Debug.Trace("ProcessId: '" + processId + "' - Adding entry '" + CombatEyeColorList[i].GetPartName() + "' to 'CombatEyeColorList'")
            i += 1
        else
            Debug.Trace("Eye color generation for processId '" + processId + "' has been unlocked prematurely.  Ending the process early to avoid issues.", 2)
            i = count
        endIf

    endWhile

    Debug.Trace("Finished generating 'CombatEyeColorList'")
    return CombatEyeColorFormList

EndFunction

string[] Function GetCombatEyeColorMCMOptions(FormList fList, string processId)
    Debug.Trace("Function 'GenerateCombatEyeColorMCMOptions' detected")

    int i = 0

    int fListCount = fList.GetSize()
    string[] list = Utility.CreateStringArray(fListCount)
    
    while (i < fListCount)
        
        ; Check if lock is in place during each iteration, in case the eye generation process gets interrupted by a new "StartTask()" process.
        ; This way if an end user triggers a new process while the current process is still running somehow, we stop the current process and let the new process run.
        ;
        ; Why this is important:
        ;   - Use case #1: User continously enters race menu, chooses a race or sex, exits race menu, repeat 2-3+ times within a short period.
        ;   - Use case #2: User manually triggers a new process from the MCM while a current process is already running.
        ; In both cases, the use cases can result in invalid eye color selections displaying for the player (i.e. MaleArgonian eyes displaying for female wood elves, etc).  This check
        ; is designed to prevent this use case from occurring for end users. 
        if(isLocked)
            HeadPart formOption = fList.GetAt(i) as HeadPart 
            list[i] = formOption.GetPartName()
            Debug.Trace("ProcessId: '" + processId + "' - Adding MCM option: '" + list[i] + "'")
            i += 1
        else
            Debug.Trace("Eye color generation for processId '" + processId + "' has been unlocked prematurely.  Ending the process early to avoid issues.", 2)
            i = fListCount
        endIf

    endWhile
    
    Debug.Trace("Finished generating MCM options")
    return list

EndFunction

HeadPart[] Function GetAllPlayerEyeColorOptions(int playerSex, Race playerRace)
    return GetPlayerEyeColorOptions(playerSex, playerRace)
EndFunction

bool Function IsPlayerDyingConfigPrerequisitesMet()
    Debug.Trace("Function 'IsPlayerDyingConfigPrerequisitesMet' detected")

    bool isPrerequisitesMet = false

    if(isWeaponDrawnConfigEnabled || isEnterCombatConfigEnabled)  
        isPrerequisitesMet = true
    endIf

    return isPrerequisitesMet

EndFunction

bool Function IsResetMCMOptionPrerequisitesMet()
    Debug.Trace("Function 'IsResetMCMOptionPrerequisitesMet' detected")

    bool isPrerequisitesMet = false
    bool isVampire = ceAlias.IsPlayerVampire

    if(!isVampire)  
        isPrerequisitesMet = true
    endIf

    return isPrerequisitesMet

EndFunction

Function LoadDefaultMCMSettings()

    ; Default MCM settings
    isWeaponDrawnConfigEnabled = false
    isEnterCombatConfigEnabled = false
    isPlayerDyingConfigEnabled = false

EndFunction

; NATIVE FUNCTIONS
; Retrieves the list of all "playable", "non extra-headPart" eye colors available across mods for the player, based on player's sex and race
HeadPart[] Function GetPlayerEyeColorOptions(int playerSex, Race playerRace) global native
