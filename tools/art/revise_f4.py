"""Original MIT revision sculpt: irregular branch, integrated torn twig, stained bark."""
import bpy, math, random
from mathutils import Vector

def branch(wood,blood,export):
    rng=random.Random(47)
    bark=[]
    for i,c in enumerate([(.27,.18,.105),(.34,.245,.157),(.22,.145,.083),(.39,.29,.19)]):
        m=wood.copy();m.name='Ash bark warm muted '+str(i);m.diffuse_color=(*c,1)
        m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*c,1)
        m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.93
        bark.append(m)
    blood.diffuse_color=(.19,.012,.016,1)
    p=blood.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.19,.012,.016,1);p.inputs['Roughness'].default_value=.96
    # Continuous fork topology: twig starts at an existing shaft ring, not a tool handle.
    n=10; verts=[];faces=[]
    centers=[(-.49,0,.015),(-.40,.009,.022),(-.26,.014,.036),(-.10,.003,.024),(.05,-.018,.037),(.20,-.031,.064),(.36,-.042,.087),(.49,-.045,.10)]
    radii=[.010,.022,.026,.023,.028,.023,.018,.008]
    for i,(x,y,z) in enumerate(centers):
        for j in range(n):
            a=j*math.tau/n;r=radii[i]*(1+.12*math.sin(j*3+i*.8))
            verts.append((x+(rng.random()-.5)*.008,y+math.cos(a)*r,z+math.sin(a)*r))
    # Preserve the exact accepted shaft; interpolated rings break up stain boundaries.
    original=[Vector(v) for v in verts];verts=[];stains=[]
    for i in range(21):
        k,t=divmod(i,3)
        verts.extend(tuple(original[k*n+j].lerp(original[(k+1)*n+j],t/3)) for j in range(n))
    verts.extend(tuple(v) for v in original[-n:])
    patches={11:{1,2},13:{2,3,4},16:{0,1,2},18:{3,4},19:{4}}
    for i in range(21):
        for j in range(n):
            if (i,j)==(12,2):continue
            faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
            stains.append(j in patches.get(i,set()))
    faces.extend([tuple(reversed(range(n))),tuple(range(210,220))]);stains.extend([False,False])
    # Four compact roundish cross sections form a narrow, kinked, tapered twig.
    root=[122,123,133,132]
    center=sum((Vector(verts[k]) for k in root),Vector())/4
    previous=root
    for offset,radius in [((.005,.002,.014),.009),((.011,.005,.051),.007),((.002,.009,.087),.0045),((.009,.011,.119),.0015)]:
        c=center+Vector(offset);ring=[]
        for j in range(4):
            a=math.pi/4+j*math.tau/4
            ring.append(len(verts));verts.append(tuple(c+Vector((math.cos(a)*radius,math.sin(a)*radius,0))))
        for j in range(4):faces.append((previous[j],previous[(j+1)%4],ring[(j+1)%4],ring[j]));stains.append(False)
        previous=ring
    faces.append(tuple(previous));stains.append(False)
    mesh=bpy.data.meshes.new('Connected torn branch topology');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Bent ash branch integrated snapped offshoot',mesh);bpy.context.collection.objects.link(o)
    for m in bark+[blood]:mesh.materials.append(m)
    for p,stained in zip(mesh.polygons,stains):
        p.material_index=4 if stained else rng.randrange(4)
    export('bent_stick',[o])
    return o
