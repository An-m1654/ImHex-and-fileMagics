//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//      THIS PATTERN FILE IS VERY INCOMPLETE!
//      idk how to do the address thingies in imhex
//      so this will probably stay this way.
//      
//      Any help is appriciated.
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


// Specifications from https://zeldamods.org/wiki/BYML

#pragma author AnmPro
#pragma description Nintendo's byml binary
#pragma magic [ BY ] @ 0x00
#pragma magic [ YB ] @ 0x00

import std.mem;
import std.io;
import std.core;
import std.string;
import std.math;
import std.array;

// Detect Endianness
str magic = std::mem::read_string(0, 2);
if (magic == "BY") {
    std::core::set_endian(std::mem::Endian::Big);
} else if (magic == "YB") {
    std::core::set_endian(std::mem::Endian::Little);
} else {
    std::core::set_endian(std::mem::Endian::Native);
}

// BYML HEADER
struct BYMLHeader {
    char magic[2];
    str endianness = magic == "BY" ? "Big Endian" : magic == "YB" ? "Little Endian" : "Unknown/Broken" [[export]];
    u16 version;
    u32 hashKeyTableOffset;
    u32 stringTableOffset;
    u32 rootNodeOffset;
};

struct Node {
    char nodeType[1];
    u24 entryCount;
};

// STRING HASH NODE
struct BYMLStringHashNode: Node {
    u24 stringLocation;
    u8 stringNodeType;
    u32 stringValue;
};

// BYML STRING TABLE NODE
struct BYMLStringTableNode: Node {
    u128 prevPosition = $; // This is the 0x04 relative position as stated in the documentation
    u128 stringOffsetArraySize = 4*(entryCount+1); //This is the Y in the documentation
    u32 stringOffsets[stringOffsetArraySize/4];

    u128 newPosition = prevPosition + (stringOffsetArraySize + (4 - (stringOffsetArraySize % 4)) % 4); //This is the Y' in the documentation
    std::string::NullString string[entryCount] @ newPosition;
};

// BYML ARRAY NODE
struct BYMLArrayNode: Node {
    u128 prevPosition = $; // This is the 0x04 relative position as stated in the documentation
    u8 entryNodeTypes[entryCount];
    u128 newPosition = prevPosition + (entryCount + (4 - (entryCount % 4)) % 4); //This is the N' in the documentation
    
    u32 entryNodeTypesValues[entryCount] @ newPosition;
};

// BYML
struct Byml {
    BYMLHeader Header;
    BYMLStringTableNode HashKeyTable @ Header.hashKeyTableOffset;

    if (Header.stringTableOffset != 0) {
        BYMLStringTableNode StringTable @ Header.stringTableOffset;
    }

    u8 rootNodeType @ Header.rootNodeOffset [[hidden]];

    if (rootNodeType == 0xc0) {
        BYMLArrayNode RootNode @ Header.rootNodeOffset;
        // INCOMPLETE
    } else if (rootNodeType == 0x20) {
        // INCOMPLETE
    } else if (rootNodeType == 0x21) {
        // INCOMPLETE
    } else if (rootNodeType == 0xc1) {
        // INCOMPLETE
    }
};

Byml BYML @ 0;
