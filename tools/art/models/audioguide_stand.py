"""Audio-guide stand of the museum's System at an exhibit: a heavy cast-iron
base, a brushed steel post, a black sloped pulpit with a big brass button
and a row of speaker slits, and a blank white enamel plate on the post under
the pulpit: the stop number is drawn on it in the game (AudioguideStand,
one model for every stop). Reads as "press me" from across the room
(backlog #39). 1.08 m tall.

Origin at the centre of the base on the floor; the pulpit slopes down
toward +Y (Godot -Z: the marker's front faces the visitor). Parts:
    audioguide_stand  (0, 0, 0)              base, post, pulpit, slits, number plate (blank)
    button            on the pulpit, right   the brass button; its local Z is the
                                             pulpit's normal (press it along -Z)
"""
import math

from mathutils import Vector

from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

POST_TOP = 1.0
PULPIT = Vector((0.0, 0.10, 1.02))             # centre of the sloped panel
TILT = -28.0                                   # degrees about X: the near (+Y) edge lower
PANEL = (0.36, 0.26, 0.03)
BUTTON_AT = Vector((0.09, -0.04, PANEL[2] / 2))   # on the panel's top face, panel-local
SIGN_Z = 0.80                                  # the plate's centre; its front face is 0.051 m before the post


def panel_matrix():
    return T(*PULPIT) @ R("X", TILT)


def iron(ctx):
    return M.iron(ctx, seed=617)


def steel(ctx):
    return M.steel(ctx, seed=619, center=7.0, dent=0.05, rust=0.1, polish=0.35, scratch=0.3)


def panel(ctx):
    return M.plastic(ctx, "plastic_black", 3.0, seed=621, rough=0.5, scuff=0.6)


def brass(ctx):
    return M.brass(ctx, seed=623, tarnish_amount=0.8)


def number(ctx):
    """White enamel plate for the stop number (the game draws the digits)."""
    return M.enamel(ctx, "enamel_white", 6.0, seed=625, chip=0.1, gloss=0.4, under="steel")


FNS = {"iron": iron, "steel": steel, "panel": panel, "brass": brass, "number": number}


def build():
    p = Part("audioguide_stand")
    octagon = [(0.26 * math.cos(a), 0.26 * math.sin(a)) for a in (math.radians(22.5 + 45 * i) for i in range(8))]
    p.ngon_prism(octagon, 0.0, 0.05, "iron", bevel=0.006)                                   # base slab
    p.ngon_prism([(x * 0.65, y * 0.65) for x, y in octagon], 0.05, 0.09, "iron", bevel=0.005)
    p.tube([(0, 0, 0.09), (0, 0, POST_TOP)], 0.035, "steel", sides=12)                      # post
    p.box((0, 0.02, POST_TOP - 0.02), (0.12, 0.10, 0.04), "steel", bevel=0.004)             # head under the pulpit
    m = panel_matrix()
    faces = p.box((0, 0, 0), PANEL, "panel", bevel=0.006)                                   # the sloped pulpit
    for i in range(5):                                                                       # speaker slits, left
        faces += p.box((-0.10, -0.06 + i * 0.014, PANEL[2] / 2 + 0.001), (0.07, 0.004, 0.003), "iron")
    faces += p.box((0.0, 0.08, PANEL[2] / 2 + 0.001), (0.30, 0.02, 0.002), "iron")          # a dark strip at the far edge
    p.move(faces, m)
    p.box((0, 0.045, SIGN_Z), (0.12, 0.012, 0.12), "number", bevel=0.002)                   # the stop number on the post
    button = Part("button", origin=tuple(m @ BUTTON_AT))
    faces = button.tube([(0, 0, 0.0), (0, 0, 0.022)], 0.045, "brass", sides=16)
    faces += button.tube([(0, 0, 0.022), (0, 0, 0.030)], 0.036, "brass", sides=16)
    button.move(faces, m @ T(*BUTTON_AT))
    return Model("audioguide_stand", [p, button], FNS, ppm=256, ground=0.0, ao_dist=0.15,
                 preview_elevation=12.0)
