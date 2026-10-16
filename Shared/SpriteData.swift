//
//  SpriteData.swift
//  OurLog
//
//  도트 스프라이트 데이터. 자동 생성 파일이니 직접 고치지 말고
//  scripts/sprites/ 의 파이썬 원본을 고친 뒤 export_swift.py 를 다시 돌릴 것.
//

import SwiftUI

// MARK: - 팔레트

nonisolated enum PixelPalette {
    static let colors: [Character: Color] = [
        "#": Color(hex: 0x5B3B34),
        "w": Color(hex: 0xF9F3EF),
        "v": Color(hex: 0xEEE2DA),
        "h": Color(hex: 0xFFFFFF),
        "g": Color(hex: 0xB7ABAA),
        "s": Color(hex: 0x948280),
        "k": Color(hex: 0xF4C0BC),
        "c": Color(hex: 0xF6E9DB),
        "C": Color(hex: 0xECDAC0),
        "r": Color(hex: 0xF06080),
        "*": Color(hex: 0xF2CC55),
        "p": Color(hex: 0xF29CB2),
        "R": Color(hex: 0xC84A64),
        "y": Color(hex: 0xF6D365),
        "Y": Color(hex: 0xC8963C),
        "u": Color(hex: 0xC4ACE2),
        "U": Color(hex: 0x9C84C4),
        "m": Color(hex: 0x96D0BE),
        "M": Color(hex: 0x62A692),
        "b": Color(hex: 0x96BCE6),
        "B": Color(hex: 0x628CC4),
        "G": Color(hex: 0x86C078),
        "e": Color(hex: 0x3A3236),
        "n": Color(hex: 0xC49A74),
        "N": Color(hex: 0x9C7250),
        "o": Color(hex: 0xE49C6C),
        "D": Color(hex: 0x5E9A58),
        "a": Color(hex: 0xF7EEE2),
        "A": Color(hex: 0xEFE3D3),
        "f": Color(hex: 0xE6CCAA),
        "F": Color(hex: 0xD6B892),
        "l": Color(hex: 0xCFE6F6),
        "L": Color(hex: 0xFFFFFF),
    ]
}

// MARK: - 고양이

nonisolated enum CatSprites {
    static let eggIdle = PixelSprite(rows: [
        ".........##.........",
        ".......##ww##.......",
        "......#wwwwwv#......",
        ".....#wwwwwwwv#.....",
        "....#wwwwwwwwwv#....",
        "...#wwwwwwwwwwwv#...",
        "...#whwwwwwwwwwv#...",
        "..#wwhwwwwwwwwwwv#..",
        "..#wwhhwwwwwwwwwv#..",
        ".#wwwwwwwwwwwwwwvv#.",
        ".#wwwwwwwwwwwwwwvv#.",
        ".#wwwwwwwwwwwwwwwv#.",
        ".#wwwwwwwwwwwwwwwv#.",
        ".#wwwwwwwwwwwwwwwv#.",
        ".#wwwwwwwwwwwwwwwv#.",
        ".#wwwwwwwwwwwwwwvv#.",
        ".#wwwwwwwwwwwwwwvv#.",
        ".#wwwwwwwwwwwwwwvv#.",
        ".#vwwwwwwwwwwwwvvv#.",
        "..#wwwwwwwwwwwwvv#..",
        "..#vwwwwwwwwwwvvv#..",
        "...#vvwwwwwwvvvv#...",
        "....#vvvvvvvvvv#....",
        ".....###vvvv###.....",
        "........####........",
    ])

    static let crackedEggIdle = PixelSprite(rows: [
        "................###....",
        "....##.........#ggg#...",
        "...#gg##......#gggg#...",
        "...#gggg######ggkkgg#..",
        "..#gkggggggggggskkgg#..",
        "..#gkkggssgggssgssggg#.",
        ".#ggkksgggggggggggggg#.",
        ".#gggsgggggwwggggggss#.",
        ".#ssgggggggwwwgggggggg#",
        ".#sgggggggwwwwwggggggg#",
        "#sgggg##wwwwwww##gggss#",
        "#ssggg##wwwwwww##ggggg#",
        "#ggggg##w#w#w#w##wgggg#",
        "#gggwkkwww#w#wwwkkwwww#",
        ".#ggwkkkwwwwwwwwkkkww#.",
        ".##wwwwwwwwwwwwwwwww#..",
        "...####wwwwwwwww####...",
        "..#wwww#wwwwwww#wwww#..",
        "..#w#ww#########ww#w#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "...#CCccccccccccccc#...",
        "....###############....",
    ])

    static let crackedEggBlink = PixelSprite(rows: [
        "................###....",
        "....##.........#ggg#...",
        "...#gg##......#gggg#...",
        "...#gggg######ggkkgg#..",
        "..#gkggggggggggskkgg#..",
        "..#gkkggssgggssgssggg#.",
        ".#ggkksgggggggggggggg#.",
        ".#gggsgggggwwggggggss#.",
        ".#ssgggggggwwwgggggggg#",
        ".#sgggggggwwwwwggggggg#",
        "#sggggggwwwwwwwwwgggss#",
        "#ssggg##wwwwwww##ggggg#",
        "#gggg#gg##w#w##ww#gggg#",
        "#gggwkkwww#w#wwwkkwwww#",
        ".#ggwkkkwwwwwwwwkkkww#.",
        ".##wwwwwwwwwwwwwwwww#..",
        "...####wwwwwwwww####...",
        "..#wwww#wwwwwww#wwww#..",
        "..#w#ww#########ww#w#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "..#CCCcccccccccccccc#..",
        "...#CCccccccccccccc#...",
        "....###############....",
    ])

    static let kittenIdle = PixelSprite(rows: [
        "....##.........###......",
        "...#gg#......##ggg#.....",
        "..#gkgg#######ggkg#.....",
        "..#gkgggsgggsggkkg#.....",
        ".#ggkksgggggggskkgg#....",
        ".#gggsggggwggggsggg#....",
        ".#ggggggggwwggggggg#....",
        "#sssgggggwwwwgggggss#...",
        "#gggggggwwwwwggggggg#...",
        "#sgggggwwwwwwwggggss#...",
        "#ssgggwwwwwwwwwgggggg#..",
        "#ggg####wwwwww####ggg#..",
        "#ggwwwww#w##w#wwwwggg#..",
        "#gwkkkwww#ww#wwkkkwww#..",
        ".#wwwwwwwwwwwwwwwww#gg#.",
        "..#wwwwwwwwwwwwwww#gggg#",
        "...#wwwwwwwwwwwww##gggg#",
        "....#wwwwwwwwwwww##ssss#",
        "...#wwwwwwwwwwwww##gggg#",
        "...#vw#vwwwwww#ww#ssssg#",
        "...#vw#vwwwwww#ww#ssss#.",
        "....#v#vwwwwww#w#ssg#...",
        "....#v#w#w#w#ww#wsg#....",
        ".....##############.....",
    ])

    static let teenIdle = PixelSprite(rows: [
        "....##...........##......",
        "...#gg#........##gg#.....",
        "...#gggg########gggg#....",
        "..#gkkggggggggggggkkg#...",
        "..#gkkgggsgggsssgkkgs#...",
        ".#ggkkksggggggggssggg#...",
        ".#gggggggggwggggggggg#...",
        ".#ssggggggwwwggggggsss#..",
        "#sssgggggwwwwwgggggssg#..",
        "#ggggggggwwwwwwggggggg#..",
        "#ssggg##wwwwwwww##gsss#..",
        "#ggggg##gwwwwwww##ggggg#.",
        "#ggggg##w#w#w#ww##ggggg#.",
        "#gggwkkwww#w#wwwkkwgggg#.",
        ".#wwkkkwwwwwwwwwkkkwww#..",
        ".#wwwwwwwwwwwwwwwwwww#...",
        "....#wwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##ssss#",
        "...#wwwwwwwwwwwwwww##ggg#",
        "...#vwwwwwwwwwwwww##gggg#",
        "...#vw#vwwwwwww#vw##ssss#",
        "...#vw#vwww#vww#vw#ssss#.",
        "....#w#vwww#vww#vw#sss#..",
        "....#w#v##w##w##vw#gg#...",
        "....#################....",
    ])

    static let teenBlink = PixelSprite(rows: [
        "....##...........##......",
        "...#gg#........##gg#.....",
        "...#gggg########gggg#....",
        "..#gkkggggggggggggkkg#...",
        "..#gkkgggsgggsssgkkgs#...",
        ".#ggkkksggggggggssggg#...",
        ".#gggggggggwggggggggg#...",
        ".#ssggggggwwwggggggsss#..",
        "#sssgggggwwwwwgggggssg#..",
        "#ggggggggwwwwwwggggggg#..",
        "#ssgggggwwwwwwwwwwgsss#..",
        "#ggggg##gwwwwwww##ggggg#.",
        "#gggg#gg##w#w#w#ww#gggg#.",
        "#gggwkkwww#w#wwwkkwgggg#.",
        ".#wwkkkwwwwwwwwwkkkwww#..",
        ".#wwwwwwwwwwwwwwwwwww#...",
        "....#wwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##ssss#",
        "...#wwwwwwwwwwwwwww##ggg#",
        "...#vwwwwwwwwwwwww##gggg#",
        "...#vw#vwwwwwww#vw##ssss#",
        "...#vw#vwww#vww#vw#ssss#.",
        "....#w#vwww#vww#vw#sss#..",
        "....#w#v##w##w##vw#gg#...",
        "....#################....",
    ])

    static let adultIdle = PixelSprite(rows: [
        "....##...........##......",
        "...#gg#........##gg#.....",
        "...#gggg########gggg#....",
        "..#gkkggggggggggggkkg#...",
        "..#gkkgggsgggsssgkkgs#...",
        ".#ggkkksggggggggssggg#...",
        ".#gggggggggwggggggggg#...",
        ".#ssggggggwwwggggggsss#..",
        "#sssgggggwwwwwgggggssg#..",
        "#ggggggggwwwwwwggggggg#..",
        "#ssggggwwwwwwwwwgggsss#..",
        "#ggggg###wwwwww###ggggg#.",
        "#ggggg#ww#w#w#www#ggggg#.",
        "#gggwkkwww#w#wwwkkwgggg#.",
        ".#wwkkkwwwwwwwwwkkkwww#..",
        ".#wwwwwwwwwwwwwwwwwww#...",
        "..##wwwwwwwwwwwwwww#####.",
        "....#wwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##gggg#",
        "...#wwwwwwwwwwwwww##ssss#",
        "...#wwwwwwwwwwwwwww##ggg#",
        "...#vwwwwwwwwwwwww##gggg#",
        "...#vw#vwwwwwww#vw##ssss#",
        "...#vw#vwww#vww#vw#ssss#.",
        "....#w#vwww#vww#vw#sss#..",
        "....#w#v##w##w##vw#gg#...",
        "....#################....",
    ])

    static let radiantIdle = PixelSprite(rows: [
        ".........................rr.rr...",
        "........................rrrrrrr..",
        "........................rrrrrrr..",
        ".........................rrrrr...",
        "..........................rrr....",
        "........##...........##....r.....",
        ".......#gg#........##gg#.........",
        ".*.....#gggg########gggg#........",
        "***...#gkkggggggggggggkkg#....*..",
        ".*....#gkkgggsgggsssgkkgs#.......",
        ".....#ggkkksggggggggssggg#.......",
        ".....#gggggggggwggggggggg#.......",
        ".....#ssggggggwwwggggggsss#......",
        "....#sssgggggwwwwwgggggssg#......",
        "....#ggggggggwwwwwwggggggg#......",
        "....#ssggggwwwwwwwwwgggsss#......",
        "....#ggggg###wwwwww###ggggg#.....",
        "....#ggggg#ww#w#w#www#ggggg#.....",
        "....#gggwkkwww#w#wwwkkwgggg#.....",
        ".*...#wwkkkwwwwwwwwwkkkwww#......",
        "***..#wwwwwwwwwwwwwwwwwww#.......",
        ".*....##wwwwwwwwwwwwwww#####..*..",
        "........#wwwwwwwwwwwww##gggg#***.",
        ".......#wwwwwwwwwwwwww##gggg#.*..",
        ".......#wwwwwwwwwwwwww##gggg#....",
        ".......#wwwwwwwwwwwwww##ssss#....",
        ".......#wwwwwwwwwwwwwww##ggg#....",
        ".......#vwwwwwwwwwwwww##gggg#....",
        "...*...#vw#vwwwwwww#vw##ssss#....",
        "..***..#vw#vwww#vww#vw#ssss#.....",
        "...*....#w#vwww#vww#vw#sss#......",
        "........#w#v##w##w##vw#gg#.......",
        "........#################........",
    ])

    static func idle(_ stage: CatStage) -> PixelSprite {
        switch stage {
        case .egg: eggIdle
        case .crackedEgg: crackedEggIdle
        case .kitten: kittenIdle
        case .teen: teenIdle
        case .adult: adultIdle
        case .radiant: radiantIdle
        }
    }

    /// 눈을 뜨고 있는 단계만 깜빡임 프레임이 있다.
    static func blink(_ stage: CatStage) -> PixelSprite? {
        switch stage {
        case .crackedEgg: crackedEggBlink
        case .teen: teenBlink
        default: nil
        }
    }

    /// 착용 아이템이 붙는 자리 (스프라이트 안 좌표, 칸 단위).
    /// head 는 아이템 아랫줄 가운데, face 는 아이템 가운데, neck 은 아이템 윗줄 가운데가 여기에 온다.
    static func anchor(_ stage: CatStage, _ slot: AccessorySlot) -> (x: Double, y: Int)? {
        switch (stage, slot) {
        case (.crackedEgg, .head): (11.5, 3)
        case (.crackedEgg, .face): (11.5, 11)
        case (.crackedEgg, .neck): (11.5, 16)
        case (.kitten, .head): (10.5, 2)
        case (.kitten, .face): (10.5, 11)
        case (.kitten, .neck): (10.5, 15)
        case (.teen, .head): (11.5, 2)
        case (.teen, .face): (12.0, 11)
        case (.teen, .neck): (11.5, 15)
        case (.adult, .head): (11.5, 2)
        case (.adult, .face): (12.0, 11)
        case (.adult, .neck): (11.5, 16)
        case (.radiant, .head): (15.5, 7)
        case (.radiant, .face): (16.0, 16)
        case (.radiant, .neck): (15.5, 21)
        default: nil
        }
    }
}

// MARK: - 착용 아이템

nonisolated enum AccessorySprites {
    static let all: [String: PixelSprite] = [
        "acc-ribbon": PixelSprite(rows: [
            ".##...##.",
            "#pp#.#pp#",
            "#ppp#ppp#",
            "#pp#R#pp#",
            ".##.#.##.",
        ]),
        "acc-crown": PixelSprite(rows: [
            "#...#...#",
            "##.###.##",
            "#y#yyy#y#",
            "#yyyyyyy#",
            "#yRyyyRy#",
            "#########",
        ]),
        "acc-flower": PixelSprite(rows: [
            "..#.#..",
            ".#p#p#.",
            "#ppypp#",
            ".#ppp#.",
            "..#G#..",
            "...#...",
        ]),
        "acc-beret": PixelSprite(rows: [
            "......#....",
            "...######..",
            ".##uuuuuu#.",
            "#uuuuuuuuu#",
            "#UUUUUUUUU#",
            ".#########.",
        ]),
        "acc-scarf": PixelSprite(rows: [
            ".###########.",
            "#mmMmmMmmMmm#",
            ".#####mm####.",
            ".....#mm#....",
            ".....#MM#....",
            "......##.....",
        ]),
        "acc-bell": PixelSprite(rows: [
            "###########",
            "#RRRRRRRRR#",
            "####yyy####",
            "...#yYy#...",
            "....###....",
        ]),
        "acc-bowtie": PixelSprite(rows: [
            "##.....##",
            "#bb###bb#",
            "#bbbBbbb#",
            "#bb###bb#",
            "##.....##",
        ]),
        "acc-glasses": PixelSprite(rows: [
            ".YYY.......YYY.",
            "Y...YYYYYYY...Y",
            "Y...Y.....Y...Y",
            ".YYY.......YYY.",
        ]),
        "acc-sunglasses": PixelSprite(rows: [
            "###############",
            "#eheee#.#eheee#",
            ".#eee#...#eee#.",
            "..###.....###..",
        ]),
    ]
}

// MARK: - 방

nonisolated enum RoomSprites {
    static let width = 56
    static let height = 44
    /// 고양이 발바닥 줄과 가운데 x (칸 단위)
    static let catFootY = 41
    static let catCenterX = 22

    static let background = PixelSprite(rows: [
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "AaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa##################aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#llLlllllnlllllll#aa",
        "aaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaa#lLLLllllnlllllll#aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#lLLLLlllnlllllll#aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#llllllllnlllllll#aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#llllllllnlllllll#aa",
        "AaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaa#nnnnnnnnnnnnnnnn#Aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#llllllllnlllllll#aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#llllllllnlllllll#aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#llllllllnlllllll#aa",
        "aaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaa#llllllllnlllllll#aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa##################aa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaannnnnnnnnnnnnnnnnnnna",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa####################a",
        "AaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "AaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAaaaaaAa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "########################################################",
        "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        "########################################################",
        "FfffffffffffffFfffffffffffffFfffffffffffffFfffffffffffff",
        "FfffffffffffffFfffffffffffffFfffffffffffffFfffffffffffff",
        "FfffffffffffffFfffffffffffffFfffffffffffffFfffffffffffff",
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        "fffffffFfffffffffffffFfffffffffffffFfffffffffffffFffffff",
        "fffffffFfffffffffffffFfffffffffffffFfffffffffffffFffffff",
        "fffffffFfffffffffffffFfffffffffffffFfffffffffffffFffffff",
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        "FfffffffffffffFfffffffffffffFfffffffffffffFfffffffffffff",
        "FfffffffffffffFfffffffffffffFfffffffffffffFfffffffffffff",
        "FfffffffffffffFfffffffffffffFfffffffffffffFfffffffffffff",
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    ])

    /// 아이템 스프라이트와 방 안에서의 왼쪽 위 좌표
    static let items: [String: (sprite: PixelSprite, x: Int, y: Int)] = [
        "room-frame": (PixelSprite(rows: [
            "#############",
            "#nnnnnnnnnnn#",
            "#n#########n#",
            "#n#ccccccc#n#",
            "#n#crrcrrc#n#",
            "#n#crrrrrc#n#",
            "#n#ccrrrcc#n#",
            "#n#cccrccc#n#",
            "#n#########n#",
            "#nnnnnnnnnnn#",
            "#############",
        ]), 6, 5),
        "room-garland": (PixelSprite(rows: [
            "#################",
            "#ppp#yyy#bbb#mmm#",
            ".#p#.#y#.#b#.#m#.",
            "..#...#...#...#..",
        ]), 4, 8),
        "room-clock": (PixelSprite(rows: [
            "...####...",
            ".##wwww##.",
            ".#ww#www#.",
            "#www#wwww#",
            "#www#wwww#",
            "#www###ww#",
            "#wwwwwwww#",
            ".#wwwwww#.",
            ".##wwww##.",
            "...####...",
        ]), 7, 5),
        "room-rug": (PixelSprite(rows: [
            "...##########################...",
            ".##pppppppppppppppppppppppppp##.",
            "#pppkkpkkpkkpkkpkkpkkpkkpkkpkpp#",
            "#ppkkkkkkkkkkkkkkkkkkkkkkkkkkpp#",
            ".##pppppppppppppppppppppppppp##.",
            "...##########################...",
        ]), 6, 37),
        "room-cushion": (PixelSprite(rows: [
            ".############################.",
            "#uuuuuuuuuuuuuuuuuuuuuuuuuuuu#",
            "#uuuuUuuuuuuuuuuuuuuuuuuUuuuu#",
            "#uuuuuuuuuuuuuuuuuuuuuuuuuuuu#",
            "#UUUUUUUUUUUUUUUUUUUUUUUUUUUU#",
            ".############################.",
        ]), 7, 37),
        "room-plant": (PixelSprite(rows: [
            "....##....",
            "..##GG##..",
            ".#GG##GG#.",
            "#GGDGGDGG#",
            ".#GDGGDG#.",
            "..##GG##..",
            "....##....",
            ".########.",
            ".#oooooo#.",
            "..#oooo#..",
            "..#oooo#..",
            "...####...",
        ]), 36, 4),
        "room-curtain": (PixelSprite(rows: [
            "##################",
            "#pkpkpkpkpkpkpkpk#",
            "##################",
            "#kk#..........#kk#",
            "#kk#..........#kk#",
            "#kkk#........#kkk#",
            "#kkk#........#kkk#",
            "#kkkk#......#kkkk#",
            "#kkk#........#kkk#",
            "#kk#..........#kk#",
            "#kk#..........#kk#",
            "####..........####",
        ]), 36, 4),
        "room-moon": (PixelSprite(rows: [
            "..#####..",
            ".#yyyyy#.",
            "#yyYyyyy#",
            "#yyyyyYy#",
            "#yYyyyyy#",
            ".#yyyyy#.",
            "..#####..",
            "....#....",
            "....#....",
            "..#nnn#..",
            "..#####..",
        ]), 41, 5),
        "room-ball": (PixelSprite(rows: [
            "..#####...",
            ".#ppppp#..",
            "#pkpppkp#.",
            "#ppkpkpp#.",
            "#pppkppp#.",
            ".#pkpkp#..",
            "..######..",
            ".......###",
        ]), 36, 34),
        "room-bowl": (PixelSprite(rows: [
            "...#n#n#...",
            ".#nnnnnnn#.",
            "###########",
            "#bbbbbbbbb#",
            ".#bbbbbbb#.",
            "..#######..",
        ]), 36, 36),
        "room-cake": (PixelSprite(rows: [
            ".....y.....",
            ".....#.....",
            "..#######..",
            ".#kkkkkkk#.",
            "#kwkkwkkwk#",
            "#wwwwwwwww#",
            "#ccccccccc#",
            "#kkkkkkkkk#",
            "#ccccccccc#",
            "###########",
        ]), 36, 32),
    ]
}

// MARK: - 카탈로그

nonisolated enum DecorCatalog {
    static let accessories: [CatAccessory] = [
        CatAccessory(id: "acc-ribbon", name: "리본", slot: .head),
        CatAccessory(id: "acc-crown", name: "왕관", slot: .head),
        CatAccessory(id: "acc-flower", name: "꽃 핀", slot: .head),
        CatAccessory(id: "acc-beret", name: "베레모", slot: .head),
        CatAccessory(id: "acc-scarf", name: "목도리", slot: .neck),
        CatAccessory(id: "acc-bell", name: "방울 목걸이", slot: .neck),
        CatAccessory(id: "acc-bowtie", name: "나비 넥타이", slot: .neck),
        CatAccessory(id: "acc-glasses", name: "금테 안경", slot: .face),
        CatAccessory(id: "acc-sunglasses", name: "선글라스", slot: .face),
    ]

    static let roomItems: [RoomItem] = [
        RoomItem(id: "room-frame", name: "우리 사진 액자", slot: .wall),
        RoomItem(id: "room-garland", name: "가랜드", slot: .wall),
        RoomItem(id: "room-clock", name: "벽시계", slot: .wall),
        RoomItem(id: "room-rug", name: "동그란 러그", slot: .floor),
        RoomItem(id: "room-cushion", name: "방석", slot: .floor),
        RoomItem(id: "room-plant", name: "화분", slot: .window),
        RoomItem(id: "room-curtain", name: "레이스 커튼", slot: .window),
        RoomItem(id: "room-moon", name: "달 조명", slot: .window),
        RoomItem(id: "room-ball", name: "털실 공", slot: .side),
        RoomItem(id: "room-bowl", name: "밥그릇", slot: .side),
        RoomItem(id: "room-cake", name: "케이크", slot: .side),
    ]

    static func accessory(id: String) -> CatAccessory? { accessories.first { $0.id == id } }
    static func roomItem(id: String) -> RoomItem? { roomItems.first { $0.id == id } }
}
