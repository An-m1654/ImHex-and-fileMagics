// https://osu.ppy.sh/wiki/en/Client/File_formats/osr_%28file_format%29
// https://github.com/ppy/osu/blob/master/osu.Game/Scoring/Legacy/LegacyScoreDecoder.cs
// https://github.com/ppy/osu/blob/master/osu.Game/Scoring/Legacy/LegacyScoreEncoder.cs

#pragma author OMGasm (original) & AnmPro (lazer support)
#pragma description Osu replay file

#include <type/leb128.pat>
#include <std/string.pat>
#include <std/time.pat>
#include <type/time.pat>
#include <hex/dec.pat>
#include <hex/type/json.pat>

bool shouldDecompress_OverridesOthers in;

bool shouldDecompressReplayData in;
bool shouldDecompressScoreInfo in;

using uLEB128 = type::uLEB128;
using string_t = std::string::SizedString<uLEB128>;
using time64_t = type::time64_t;

enum StringType : u8 {
    Empty,
    String = 0x0b
};

struct Empty {};

struct String {
    StringType flag;
    match (flag) {
        (StringType::Empty): Empty;
        (StringType::String): string_t string;
    }
};

enum GameMode : u8 {
    std   = 0,
    taiko = 1,
    ctb   = 2,
    mania = 3
};

struct Judgements_std {
    u16 judge_100;
    u16 judge_50;
    u16 judge_geki;
    u16 judge_katu;
};

struct Judgements_taiko {
    u16 judge_150;
    // no idea what these are, there's two places in the ui that seem to be zeroes though
    padding[6];
};

struct Judgements_ctb {
    u16 judge_100;
    u16 judge_small_fruits;
    u16 unknown_a; // TODO: figure out what these are
    u16 unknown_b;
};

struct Judgements_mania {
    u16 judge_100;
    u16 judge_50;
    u16 judge_max_300;
    u16 judge_200;

};

struct Judgements {
    u16 judge_300;
    match ($[0]) {
        (GameMode::std):   Judgements_std   [[inline]];
        (GameMode::taiko): Judgements_taiko [[inline]];
        (GameMode::ctb):   Judgements_ctb   [[inline]];
        (GameMode::mania): Judgements_mania [[inline]];
    }
    u16 judge_miss;
};

enum Combo : u8 {
    Normal,
    Full
};

bitfield Mod_flags {
    no_fail         : 1;
    easy            : 1;
    touch_device    : 1;
    hidden          : 1;
    hardRock        : 1;
    SuddenDeath     : 1;
    DoubleTime      : 1;
    Relax           : 1;
    HalfTime        : 1;
    Nightcore       : 1; // always with DT
    Flashlight      : 1;
    Autoplay        : 1;
    SpunOut         : 1;
    Relax2          : 1;
    Perfect         : 1;
    Key4            : 1;
    Key5            : 1;
    Key6            : 1;
    Key7            : 1;
    Key8            : 1;
    keyMod          : 1;
    FadeIn          : 1;
    Random          : 1;
    LastMod         : 1;
    TargetPractice  : 1; // CE only
    Key9            : 1;
    Coop            : 1;
    Key1            : 1;
    Key3            : 1;
    Key2            : 1;
    ScoreV2         : 1;
    Mirror          : 1;
};

// TODO: figure out how to use this
fn timestamp_to_date(u64 ts) {
    const u64 ticks_per_second = 10000000U; // 10_000_000
    u64 seconds = ts / ticks_per_second;

    return std::time::to_utc(seconds);
};

struct Key_or_mouse_pressed {
    bool Mouse1 = parent.key_mouse_buttons_bitwise & 1 [[export]];
    bool Mouse2 = (parent.key_mouse_buttons_bitwise >> 1) & 1 [[export]];
    bool Key1 = (parent.key_mouse_buttons_bitwise >> 2) & 1 [[export]];
    bool Key2 = (parent.key_mouse_buttons_bitwise >> 3) & 1 [[export]];
    bool Smoke = parent.key_mouse_buttons_bitwise >> 4 [[export]];
};

std::mem::Section replay_data_section = std::mem::create_section("Replay Data");

struct Replay_data_item {
    // turn this into a searcher
    char msSincePrevStr[std::mem::find_string_in_range(0, $, std::mem::get_section_size(replay_data_section), "|") - $] [[hidden]];
    s128 msSincePrev = std::string::parse_int(msSincePrevStr, 10) [[export]];
    $ += 1;
    char xCoordStr[std::mem::find_string_in_range(0, $, std::mem::get_section_size(replay_data_section), "|") - $] [[hidden]];
    float xCoord = std::string::parse_float(xCoordStr) [[export]];
    $ += 1;
    char yCoordStr[std::mem::find_string_in_range(0, $, std::mem::get_section_size(replay_data_section), "|") - $] [[hidden]];
    float yCoord = std::string::parse_float(yCoordStr) [[export]];
    $ += 1;
    u128 key_mouse_buttons_boundary = std::mem::find_string_in_range(0, $, std::mem::get_section_size(replay_data_section), ",");
    char key_mouse_buttons_bitwise_str[key_mouse_buttons_boundary <= std::mem::get_section_size(replay_data_section) ? key_mouse_buttons_boundary - $ : std::mem::get_section_size(replay_data_section) - $] [[hidden]];
    u128 key_mouse_buttons_bitwise = std::string::parse_int(key_mouse_buttons_bitwise_str, 10);
    Key_or_mouse_pressed key_mouse_buttons [[export]];
    $ += 1;
};

struct Osu {
    GameMode mode [[hex::editor_export]];
    u32 version [[hex::editor_export]];
    String beatmap_hash [[hex::editor_export]];
    String player [[hex::editor_export]];
    String replay_hash [[hex::editor_export]];
    Judgements judgements [[hex::editor_export]];
    u32 score [[hex::editor_export]];
    u16 max_combo [[hex::editor_export]];
    Combo combo_type [[hex::editor_export]];
    Mod_flags mods [[hex::editor_export]];
    String life_bar_graph [[hex::editor_export]];
    time64_t timestamp [[hex::editor_export]]; // TODO: find a better way to decode this (win32 ticks)
    u32 compressed_replay_length;
    u8 compressed_replay_data[compressed_replay_length]; // LZMA
    
    
    if (shouldDecompress_OverridesOthers && shouldDecompressReplayData && hex::dec::lzma_decompress(compressed_replay_data, replay_data_section)) {
        Replay_data_item replay_data_items[while($ <= std::mem::get_section_size(replay_data_section))] @ 0x00 in replay_data_section;
    }
    
    if (version >= 20140721) {
        u64 online_score_id [[hex::editor_export]];
    } else {
        u32 online_score_id [[hex::editor_export]];
    }
    
    // Doesn't seem to exist any more
    // if (mods.TargetPractice) { double tp_hit_accuracy; }
    
    if (version >= 30000001) {
        u32 compressed_score_info_length;
        u8 compressed_score_info_data[compressed_score_info_length];
        
        // Temp section to store decompressed data
        std::mem::Section score_info_section = std::mem::create_section("Score Info");
        if (shouldDecompress_OverridesOthers && shouldDecompressScoreInfo && hex::dec::lzma_decompress(compressed_score_info_data, score_info_section)) {
            //char decompressed_score_info_data_in_score_info_section[std::mem::get_section_size(score_info_section)] @ 0x00 in score_info_section [[hidden]];
            hex::type::Json<std::mem::get_section_size(score_info_section)> decompressed_score_info_data @ 0x00 in score_info_section;
        }
    }
};

Osu wu @ 0x0;