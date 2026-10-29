"""Original MIT observation/pit kit; executed in existing Blender MCP. Metres."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('/home/tyler/workspaces/good-dog')
OUT=ROOT/'assets/models/f4'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC'
bpy.context.scene.unit_settings.scale_length=1

def mat(name,c,rough=.7,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
white=mat('Clinical enamel',(.815,.855,.871));cyan=mat('Cyan enamel',(.52,.768,.823))
metal=mat('Brushed desaturated steel',(.18,.29,.32),.65,.65)
black=mat('Lens and collar graphite',(.008,.012,.014),.7)

def finish(o,name,m):
    o.name=name;o.data.materials.append(m)
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return o

def box(name,p,d,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.dimensions=d
    finish(o,name,m);b=o.modifiers.new('Small manufactured bevel','BEVEL');b.width=.008;b.segments=2
    bpy.ops.object.modifier_apply(modifier=b.name);return o

def tube(name,a,b,r,m):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,name,m)

def ring(name,radii,heights,m,n=48):
    vs=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),h) for r,h in zip(radii,heights) for i in range(n)]
    fs=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(radii)-1) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(o);o.data.materials.append(m);return o

def export(name):
    objects=list(bpy.context.scene.objects)
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
    return objects

def clear():
    for o in list(bpy.context.scene.objects):
        for c in list(o.users_collection): c.objects.unlink(o)
# Local front = glTF -Z / Blender +Y. Pivot is the tilt head, mount separate.
box('CCTV enamel hood',(0,0,0),(.32,.45,.18),white)
box('CCTV graphite face',(0,.23,0),(.25,.018,.13),black)
tube('CCTV lens barrel',(0,.24,0),(0,.31,0),.055,metal)
tube('CCTV optical glass',(0,.31,0),(0,.316,0),.043,black)
box('CCTV visor',(0,.08,.11),(.35,.48,.025),cyan)
all_objects=export('surveillance_head');clear()
box('Ceiling camera mounting plate',(0,0,0),(.22,.22,.04),metal)
tube('Ceiling camera stalk',(0,0,-.02),(0,0,-.23),.028,metal)
all_objects+=export('surveillance_mount');clear()
# Flush lip: inner radius remains exactly 1.5, no curb, no cap or collision.
ring('Flush pit lip',[1.5,1.53,1.58],[0,0,-.018],metal,64)
ring('Vertical black shaft lining',[1.5,1.5],[0,-18],black,64)
all_objects+=export('pit_lining');clear()
# Open bowl section, with closed small base and rounded rolled rim.
ring('Institution bowl',[0,.12,.24,.265,.27,.25,.225,.105,0],[.018,.018,.035,.105,.12,.13,.105,.045,.045],metal)
all_objects+=export('bowl');clear()
# Hanging loop in vertical plane (glTF XY), clear empty center and buckle.
o=ring('Hanging collar strap',[.13,.16,.16,.13,.13],[0,0,.035,.035,0],black,40)
o.rotation_euler.x=math.pi/2;finish(o,'Hanging collar strap',black)
box('Collar buckle',(0,0,-.145),(.09,.045,.065),metal)
tube('Collar hook',(0,0,.15),(0,.08,.15),.012,metal)
box('Hook backplate',(0,-.01,.19),(.09,.025,.16),cyan)
all_objects+=export('collar_hook')
# Restore exported objects into editable source scene without re-exporting accepted kit.
for o in all_objects:
    if o.name not in bpy.context.scene.objects:
        bpy.context.collection.objects.link(o)
report=[]
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        o.data.calc_loop_triangles();n=len(o.data.loop_triangles);assert n<=2000,(o.name,n)
        report.append({'name':o.name,'triangles':n,'scale':list(o.scale)})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/art/source/observation_pit.blend'))
(OUT/'remaining_mesh_manifest.json').write_text(json.dumps({'units':'metres','objects':report},indent=2))
print('F4_REMAINING_BUILD_OK',len(report))
