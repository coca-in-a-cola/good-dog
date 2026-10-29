"""Original GOOD DOG representative art. Blender 3.4+, metres, MIT project license."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/f4'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0

def mat(name, color, rough=.75, metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    return m
white=mat('Institution enamel E9EEF0',(.815,.855,.871))
cyan=mat('Desaturated cyan BFE3EA',(.521,.768,.823))
shadow=mat('Blue grey 7FA9B3',(.212,.397,.451))
blood=mat('Dry blood C1121F',(.533,.006,.014))
wood=mat('Worn ash wood',(.32,.235,.15),.93)
dark=mat('Recess graphite',(.025,.04,.045))

def finish(obj,name,material):
    obj.name=name; obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return obj

def box(name,loc,size,material=white,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.dimensions=size
    finish(o,name,material)
    if bevel:
        b=o.modifiers.new('Rounded manufactured edges','BEVEL'); b.width=bevel; b.segments=2
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=b.name)
        o.data.use_auto_smooth=True
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o

def rod(name,a,b,r,material,sides=10):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return finish(o,name,material)

def export(name, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)

# Sculpted asymmetrical taper, continuous mesh; dry blood is a face material, not a red brick.
import sys
sys.path.insert(0,str(ROOT/'tools/art'))
from revise_f4 import branch
branch(wood,blood,export)
# Bunk designed around accepted shelf collision, not a replacement collider.
start=set(bpy.context.scene.objects)
box('Bunk folded enamel tray',(-1.45,1.1,.45),(.9,2,.12),shadow)
box('Thin sealed mattress',(-1.45,1.1,.555),(.85,1.94,.095),white,.035)
box('Integrated pillow',(-1.45,1.76,.64),(.65,.4,.09),cyan,.035)
for x in [-1.8,-1.1]:
    for y in [.28,1.93]: rod('Bunk tubular leg',(x,y,.04),(x,y,.4),.025,shadow)
for y in [.19,2.01]:box('Bunk hem seam',(-1.45,y,.6),(.8,.016,.007),cyan,.003)
# Abstract institutional toilet: square plinth, rounded rim, dark inset and cistern.
box('Toilet enamel plinth',(1.6,2,.25),(.5,.5,.5),white,.025)
box('Toilet inset',(1.6,1.96,.507),(.30,.32,.013),dark,.04)
for x in [1.39,1.81]:box('Toilet rim side',(x,2,.54),(.07,.47,.06),white,.025)
for y in [1.8,2.2]:box('Toilet rim end',(1.6,y,.54),(.4,.07,.06),white,.025)
box('Wall cistern',(1.6,2.36,.75),(.5,.16,.58),white,.02)
box('Flush slot',(1.6,2.267,.92),(.12,.018,.025),shadow,.004)
# Lamp housings with recessed twin diffusers and end clips.
for y in [0,-5.6,-10.3]:
    box('Fluorescent housing',(0,y,2.94),(.34,1.45,.09),shadow,.012)
    for x in [-.085,.085]:box('Opal diffuser',(x,y,2.885),(.065,1.27,.035),white,.012)
    for yy in [y-.65,y+.65]:box('Lamp end clip',(0,yy,2.88),(.31,.04,.05),cyan,.005)
# Floor-wall coved trim and shallow numbered door hints. Blender XY -> Godot X/-Z.
for x in [-1.135,1.135]:
    box('Corridor cove skirting',(x,-7,.09),(.025,8.5,.18),cyan,.008)
for x in [-1,1]:
    for y in [-4.8,-8,-11.2]:
        xx=x*1.132
        box('Closed recessed door',(xx,y,1.12),(.025,1.02,2.24),cyan,.008)
        for yy in [y-.54,y+.54]:box('Door jamb',(xx-x*.015,yy,1.14),(.04,.035,2.3),shadow,.004)
        box('Door lintel',(xx-x*.015,y,2.28),(.04,1.11,.04),shadow,.004)
        box('Door ID backing',(xx-x*.026,y,1.82),(.02,.32,.16),white,.003)
        box('Door latch',(xx-x*.035,y-.32,1.05),(.035,.08,.13),shadow,.005)
for x in [-1.98,1.98]:box('Cell cove',(x,0,.09),(.025,5,.18),cyan,.008)
# Single restrained cable at wall base; no new collision or route obstruction.
for i in range(24):
    y=-3.1-i*.34; xx=1.04+.025*math.sin(i*.4)
    rod('Floor cable',(xx,y,.026),(1.04+.025*math.sin((i+1)*.4),y-.34,.026),.012,shadow,8)
dressing=list(set(bpy.context.scene.objects)-start)
# Author coordinates are game X/Z; reflect Blender Y so glTF -Y -> game Z.
from mathutils import Matrix
for o in dressing:
    o.location.y *= -1
    o.data.transform(Matrix.Diagonal((1,-1,1,1)))
    o.data.flip_normals()
export('cell_corridor',dressing)
# A true floor annulus, radius 1.25 matches old disk and leaves center readable.
start=set(bpy.context.scene.objects)
bpy.ops.mesh.primitive_torus_add(major_radius=1.225,minor_radius=.025,major_segments=64,minor_segments=6,location=(0,0,0))
ring=finish(bpy.context.object,'Placement circle 2.5m diameter',cyan)
ring.scale.z=.18;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
export('placement_circle',list(set(bpy.context.scene.objects)-start))
# Keep all modeled geometry editable in a real native Blender document.
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':
        obj.data.calc_loop_triangles(); assert len(obj.data.loop_triangles)<=2000,obj.name
source=ROOT/'tools/art/source'; source.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'representative_slice.blend'))
report={'units':'metres','objects':[{'name':o.name,'triangles':len(o.data.loop_triangles),'scale':list(o.scale),'rotation':list(o.rotation_euler)} for o in bpy.context.scene.objects if o.type=='MESH']}
(OUT/'mesh_manifest.json').write_text(json.dumps(report,indent=2))
