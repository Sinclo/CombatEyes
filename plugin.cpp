#include <excpt.h>
#include <spdlog/sinks/basic_file_sink.h>

#include <algorithm>

namespace logger = SKSE::log;

RE::BSTArray<RE::BGSHeadPart*> eye_color_list;

void SetupLog() {
    const auto logsFolder = SKSE::log::log_directory();
    if (!logsFolder) {
        SKSE::stl::report_and_fail("SKSE log_directory not provided, logs disabled.");
        return;
    }
    auto pluginName = SKSE::PluginDeclaration::GetSingleton()->GetName();
    const auto logFilePath = *logsFolder / std::format("{}.log", pluginName);
    auto fileLoggerPtr = std::make_shared<spdlog::sinks::basic_file_sink_mt>(logFilePath.string(), true);
    auto loggerPtr = std::make_shared<spdlog::logger>("log", std::move(fileLoggerPtr));
    spdlog::set_default_logger(std::move(loggerPtr));
    spdlog::set_level(spdlog::level::trace);
    spdlog::flush_on(spdlog::level::info);
}

/*
 * Retrieves all eye head parts across the user's entire game, including mods.
 * However, this also excludes any eye head parts that are configured as "non-playable" or as an "extra part" 
 */
void GetAllEyeHeadParts() {

    // List of all head parts across the entire game, including mods
    const auto& head_parts = RE::TESDataHandler::GetSingleton()->GetFormArray<RE::BGSHeadPart>();

    // Specified head part type to search for
    const auto& expected_type = RE::BGSHeadPart::HeadPartType::kEyes;

    // Only keep "eye" headParts that are configured as playable, and not configured as an "extra head part"
    logger::debug("There are {} HeadParts detected", head_parts.size());
    for (auto head_part : head_parts) {
    
        if (head_part->type == expected_type && !head_part->IsExtraPart() && head_part->GetPlayable()) {
    
            eye_color_list.push_back(head_part);
            logger::info("Detected 'Eyes' HeadPart: {}", head_part->GetFormEditorID());
        }
    }
    logger::debug("eye_color_list count is: '{}'", eye_color_list.size());
}

/*
 * Papyrus binding used for retrieving valid eye color options for player, based on their sex and race.
 */
RE::BSTArray<RE::BGSHeadPart*> GetPlayerEyeColorOptionsFunction(RE::StaticFunctionTag*, int32_t playerSex, RE::TESRace* playerRace) {

    logger::info("Player sex is {}, player race is {}", playerSex, playerRace->GetFormEditorID());

    // Player eye color list to return
    RE::BSTArray<RE::BGSHeadPart*> player_eye_color_list;

    // If player is unisex / no sex
    if (playerSex == RE::SEXES::SEX::kNone) {

        // ...start going through the list, and validate for any headParts with "unisex" option enabled
        for (const auto& entry : eye_color_list) {
            logger::info("Verifying head part '{}'", entry->GetFormEditorID());
            if (entry->flags == RE::BGSHeadPart::Flag::kNone) {

                // ...then start validating the headPart's "validRaces" entry, to ensure it matches with player's race
                if (entry->validRaces->HasForm(playerRace)) {

                    // Found a match.  Add as an available eye color option for player
                    player_eye_color_list.push_back(entry);
                    logger::info("Added '{}' as an available eye color option for player", entry->GetFormEditorID());
                }
            }
        }
    }

    // If player is male
    else if (playerSex == RE::SEXES::SEX::kMale) {

        // ...start going through the list, and validate for any headParts with "male" or "unisex" option enabled
        for (const auto entry : eye_color_list) {
            logger::info("Verifying head part '{}'", entry->GetFormEditorID());
            if (entry->flags & RE::BGSHeadPart::Flag::kMale || entry->flags == RE::BGSHeadPart::Flag::kNone) {

                // ...then start validating the headPart's "validRaces" entry, to ensure it matches with player's race
                if (entry->validRaces->HasForm(playerRace)) {
                    logger::info("validRace 'if-condition' has been met!");

                    // Found a match.  Add as an available eye color option for player
                    player_eye_color_list.push_back(entry);
                    logger::info("Added '{}' as an available eye color option for player", entry->GetFormEditorID());
                }
            }
        }
    }

    // If player is female
    else if (playerSex == RE::SEXES::SEX::kFemale) {

        // ...start going through the list, and validate for any headParts with "female" or "unisex" option enabled
        for (const auto& entry : eye_color_list) {
            logger::info("Verifying head part '{}'", entry->GetFormEditorID());
            if (entry->flags & RE::BGSHeadPart::Flag::kFemale || entry->flags == RE::BGSHeadPart::Flag::kNone) {

                // ...then start validating the headPart's "validRaces" entry, to ensure it matches with player's race
                if (entry->validRaces->HasForm(playerRace)) {

                    // Found a match.  Add as an available eye color option for player
                    player_eye_color_list.push_back(entry);
                    logger::info("Added '{}' as an available eye color option for player", entry->GetFormEditorID());
                }
            }
        }
    }

    // Else return an error message (this part of the method SHOULD be unreachable)
    else {
        logger::error("Unrecognized player sex: '{}'", playerSex);
    }

    return player_eye_color_list;
}

bool BindPapyrusFunctions(RE::BSScript::IVirtualMachine* vm) {
    vm->RegisterFunction("GetPlayerEyeColorOptions", "CombatEyes_MCM_Script", GetPlayerEyeColorOptionsFunction);
    return true;
}

void OnFormsAvailable() {
    GetAllEyeHeadParts();
}

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SKSE::Init(skse);
    SetupLog();

    // Load data
    SKSE::GetMessagingInterface()->RegisterListener([](SKSE::MessagingInterface::Message* message) {
        if (message->type == SKSE::MessagingInterface::kDataLoaded) OnFormsAvailable();
    });

    // Bind papyrus functions
    SKSE::GetPapyrusInterface()->Register(BindPapyrusFunctions);

    return true;
}
