#[
    Reference(s):
        http://codeslinger.co.uk/pages/projects/gameboy
]#

import sdl2, imgui

var
    vram: array[8192, uint8]
    screen: array[160 * 144, 0..3]

proc render() = discard