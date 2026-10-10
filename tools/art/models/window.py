"""Iron window for the arched opening of wall_window_4m: 2 m wide, sill at
1.30 m, semicircular head springing at 3.8 m. Origin on the floor at the
opening's centre on the wall plane; the frame sits 0.3 m deep in the reveal
(Blender +Y, Godot -Z). Two objects: "window" (iron glazing bars, brass
catch) and "window_glass" (one pane, casts no shadow in the game)."""
import math

from mathutils import Matrix

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

R = 1.0
SILL = 1.30
SPRING = 3.8
Y = 0.30        # glazing plane depth


def build():
    frame = Part("window")
    glass = Part("window_glass")
    # outer frame hugging the reveal: jambs + arch (swept), sill rail (box)
    path = [(-R, SILL), (-R, SPRING)]
    for i in range(1, 24):
        a = math.pi - i * math.pi / 24
        path.append((R * math.cos(a), SPRING + R * math.sin(a)))
    path += [(R, SPRING), (R, SILL)]
    prof = [(0.045, 0.0), (0.045, -0.06), (0.03, -0.075), (-0.03, -0.075), (-0.045, -0.06), (-0.045, 0.0)]
    frame.sweep(prof, path, "iron", y0=Y)
    frame.box((0, Y, SILL + 0.04), (2 * R, 0.09, 0.08), "iron", bevel=0.01)
    # glazing bars
    bar = 0.036
    frame.box((0, Y, (SILL + SPRING + R) / 2), (bar, 0.05, SPRING + R - SILL), "iron", bevel=0.006)
    for x in (-0.5, 0.5):
        frame.box((x, Y, (SILL + SPRING) / 2), (bar, 0.05, SPRING - SILL), "iron", bevel=0.006)
    for z in (2.13, 2.96, SPRING):
        frame.box((0, Y, z), (2 * R, 0.05, bar), "iron", bevel=0.006)
    for deg in (45.0, 135.0):
        a = math.radians(deg)
        faces = frame.box((0, 0, 0), (R, 0.05, bar), "iron", bevel=0.006)
        frame.move(faces, Matrix.Translation((0.5 * R * math.cos(a), Y, SPRING + 0.5 * R * math.sin(a)))
                   @ Matrix.Rotation(-a, 4, 'Y'))
    # brass catch on the central bar
    frame.box((0.035, Y - 0.04, 2.5), (0.03, 0.03, 0.14), "brass", bevel=0.006)
    frame.box((0.05, Y - 0.06, 2.45), (0.07, 0.02, 0.025), "brass", bevel=0.005)
    # one glass pane (convex outline: rectangle + half disc)
    pts = [(-R, Y + 0.004, SILL), (R, Y + 0.004, SILL)]
    for i in range(0, 25):
        a = i * math.pi / 24
        pts.append((R * math.cos(a), Y + 0.004, SPRING + R * math.sin(a)))
    f = glass.poly(pts, "glass")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    return Model("window", [frame, glass], {"iron": M.iron, "brass": M.brass}, kinds={"glass": "glass"},
                 ppm=128, ground=None, ao_dist=0.25)
