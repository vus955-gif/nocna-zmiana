"""Floor I's biome score: every music zone of the floor plays one loop in
four synced stems (band.py: explore, tension, combat, hi), each zone a
genre with its culture's colour. All on the tonic D (drop-D guitars), so
the game can crossfade zone to zone.

    zone           genre                          culture                       mode / tempo
    court (hub)    darksynth, guitars in combat   the museum's lullaby          d harmonic minor, 105
    egypt          oriental death/thrash          ney, mizmar, darbuka, oud     D hijaz (+ double harmonic), 150
    assyria        doom / sludge war march        lyre, duduk, frame drums      D kurd (Phrygian), 90
    greece         epic heavy metal (gallop)      aulos, kithara, tympanon      D Dorian, B part Mixolydian, 180
    enlightenment  neoclassical ("baroque") metal harpsichord, organ, clocks    d harmonic minor, 140
    asia           taiko metal with electronics   taiko, shamisen, koto, shaku  D in-scale / minor pentatonic, 144
    americas       tribal groove metal            slit drums, clay flute,       D Aeolian (+ Phrygian Eb), 100
                                                  death whistle, conch
    basement       industrial metal               pipes, hammers, steam         D Locrian (the tritone Ab), 120
    roof           blackgaze                      bells and wind over the city  D Aeolian, open chords, 135

The compositions: biomes_west.py (Egypt, Assyria, Greece, the Americas),
biomes_east.py (the hub, the Enlightenment, Asia, the basement, the roof),
the guardians' themes in each wing's sound: guardians.py.

Writes WAV intermediates to build/audio_src/music/ (gen_music.write):
explore_<zone>, explore_<zone>_tension, combat_<zone>, combat_<zone>_hi.

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/music/gen_music.py zone_egypt
    ... gen_music.py biomes          (all nine zones)
"""
import biomes_east
import biomes_west
import guardians

ZONES = dict(biomes_west.ZONES)
ZONES.update(biomes_east.ZONES)


def tracks():
    """name -> renderer, for gen_music.py (the guardians' themes too)."""
    out = {f"zone_{z}": f for z, f in ZONES.items()}
    out["biomes"] = lambda: [f() for f in ZONES.values()]
    out.update(guardians.tracks())
    return out
