"""Scales of the six wings and the museum lullaby in scale steps.

Every wing plays on the tonic D (smooth crossfades from wing to wing); a
mode is seven semitone offsets from D. A melody is written in steps (0 =
D4, 7 = D5, -3 = A3; one step = one scale degree), so the same tune sounds
in each wing's scale: note(step, mode).

    hijaz      Egypt         D Eb F# G A Bb C   (Phrygian dominant)
    kurd       Assyria       D Eb F  G A Bb C   (Phrygian)
    dorian     Greece        D E  F  G A B  C
    harmonic   Enlightenment D E  F  G A Bb C#  (the lullaby's own minor)
    penta      Asia          D F  F  G A A  C   (minor pentatonic: the
               second and sixth degrees fold onto their neighbours)
    aeolian    Americas      D E  F  G A Bb C
"""

MODES = {
    "hijaz": [0, 1, 4, 5, 7, 8, 10],
    "kurd": [0, 1, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "penta": [0, 3, 3, 5, 7, 7, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    # the biome score's (gen_biomes): Greece's bright B part, Asia's dark
    # in-scale (miyako-bushi D Eb G A Bb: the third and seventh degrees fold
    # down onto Eb and Bb), the boiler room's Locrian (the tritone Ab)
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "insen": [0, 1, 1, 5, 7, 8, 8],
    # the in-scale with the third folded up onto G (a held lullaby F becomes G,
    # not a long Eb over the tonic)
    "insen_up": [0, 1, 5, 5, 7, 8, 8],
    "locrian": [0, 1, 3, 5, 6, 8, 10],
}
D4 = 62


def note(step, mode, tonic=D4, alter=0):
    """MIDI note of scale [param step] (0 = the tonic) in [param mode]."""
    octave, degree = divmod(int(step), 7)
    return tonic + 12 * octave + MODES[mode][degree] + alter


def pcs(mode):
    """Pitch classes of the mode (0 = D)."""
    return sorted(set(MODES[mode]))


# The lullaby (menu: "Nokturn dozorcy", 3/4) in steps: (beat, step, beats).
LULLABY_A = [(0, 4, 1), (1, 7, 1), (2, 9, 1), (3, 9, 2), (5, 7, 1), (6, 8, 1), (7, 7, 1), (8, 5, 1), (9, 6, 3),
             (12, 4, 1), (13, 7, 1), (14, 9, 1), (15, 11, 2), (17, 10, 1), (18, 9, 1), (19, 8, 1), (20, 6, 1), (21, 7, 3)]
LULLABY_B = [(0, 6, 1), (1, 9, 1), (2, 11, 1), (3, 10, 2), (5, 8, 1), (6, 9, 1), (7, 8, 1), (8, 7, 1), (9, 9, 2),
             (11, 7, 1), (12, 5, 1), (13, 7, 1), (14, 10, 1), (15, 9, 2), (17, 4, 1), (18, 10, 1), (19, 8, 1), (20, 5, 1),
             (21, 6, 1), (22, 8, 1), (23, 10, 1)]
# The head of the tune (A D F E D) and its tail (Bb C# D).
HEAD = [(0, 4, 1), (1, 7, 1), (2, 9, 1), (3, 8, 2), (5, 7, 1)]
