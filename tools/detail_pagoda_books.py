"""Original cloth/leather bindings and two deliberately different shelf layouts."""
import math
import random

TITLES = [
    'COASTAL\nFIELD NOTES', 'TIDAL\nATLAS', 'BIRDS OF\nTHE ISLANDS',
    'HERBAL', 'TEA\nCEREMONIES', 'GARDEN\nJOURNAL', 'BOTANICAL\nSTUDIES',
    'SEASONS', 'STONE &\nWATER', 'ISLAND\nHISTORY', 'MARINE\nSURVEY',
    'POEMS', 'STAR\nCHARTS', 'CALLIGRAPHY', 'NATURAL\nPHILOSOPHY',
    'TRAVEL\nLETTERS', 'THE OLD\nCOAST', 'INK &\nBRUSH', 'WILD\nFLOWERS',
    'ARCHIVE\nVOL. IV', 'OBSERVATIONS', 'WEATHER\nRECORDS', 'CERAMICS',
    'A SMALL\nHERBARIUM', 'RIVER\nSTUDIES', 'FIELD\nSKETCHES', 'THE\nGARDENER',
    'COLLECTED\nESSAYS', 'VOYAGES', 'MOSS &\nFERNS', 'WATER\nGARDENS', 'NOTES\nVOL. II',
]
PALETTE = [(38,78,81),(133,66,45),(39,46,63),(110,92,48),
           (127,111,82),(83,49,58),(42,76,54),(170,144,98),
           (65,86,112),(92,61,41),(137,129,101),(53,72,73)]


def make_atlas(path):
    """Draw our own binding cloth, foil, small titles and spine medallions."""
    from PIL import Image, ImageDraw, ImageFont
    rng=random.Random(8317)
    image=Image.new('RGB',(1024,1024))
    for index,title in enumerate(TITLES):
        color=PALETTE[index%len(PALETTE)]
        tile=Image.new('RGB',(128,256));pixels=[]
        for y in range(256):
            for x in range(128):
                cloth=((x%3==0)-(y%3==0))*.9
                mottling=rng.uniform(-3,3)+2*math.sin(y*.079+x*.053)
                edge=-7*(abs(x-63)/64)**3
                pixels.append(tuple(max(0,min(255,round(c+cloth+mottling+edge))) for c in color))
        tile.putdata(pixels);draw=ImageDraw.Draw(tile)
        gold=(205,176,111);cream=(225,214,181)
        # A quiet border and different tooling distinguish each binding.
        if index%3!=1:draw.rounded_rectangle((17,17,110,239),radius=6,outline=gold,width=1)
        for yy in ([30,221] if index%4 else [26,34,218,226]):
            draw.line((20,yy,107,yy),fill=gold,width=2)
        font=ImageFont.truetype('/usr/share/fonts/noto/NotoSerif-Regular.ttf',14 if len(title)>15 else 16)
        if index%4==1:
            draw.rectangle((22,68,105,161),fill=(43,46,41),outline=gold,width=2)
        draw.multiline_text((64,107),title,font=font,fill=cream,anchor='mm',align='center',spacing=6)
        cx,cy=64,183
        if index%3==0:
            draw.ellipse((cx-13,cy-13,cx+13,cy+13),outline=gold,width=2)
            draw.line((cx-8,cy,cx+8,cy),fill=gold,width=1)
            draw.line((cx,cy-8,cx,cy+8),fill=gold,width=1)
        elif index%3==1:
            draw.polygon([(cx,cy-11),(cx+10,cy),(cx,cy+11),(cx-10,cy)],outline=gold,width=2)
        else:
            draw.line((cx,cy+11,cx,cy-11),fill=gold,width=2)
            for k in [-1,1]:
                draw.arc((cx-12,cy-5,cx+12,cy+7),0 if k>0 else 180,160 if k>0 else 340,fill=gold,width=2)
        small=ImageFont.truetype('/usr/share/fonts/noto/NotoSerif-Regular.ttf',11)
        draw.text((64,207),['I','II','III','IV'][index%4],font=small,fill=cream,anchor='mm')
        image.paste(tile,((index%8)*128,(index//8)*256))
    image.save(path)


def shelf_books(m,x,y,z,width,sign,level,bindings,papers,bronze,dark):
    """Books sit on the actual shelf; ground floor is a small tea/garden library."""
    from mathutils import Vector, Matrix
    rng=random.Random(310+level*701)
    inventory=[]

    def book(xx,base,thickness,height,depth,style,angle=0,flat=False):
        rotation=Matrix.Rotation(math.pi/2 if flat else angle,3,'Y')
        extent=abs(rotation[2][0])*thickness+abs(rotation[2][2])*height
        center=Vector((xx,y,base+extent/2))
        def place(p):
            q=rotation@(Vector(p)-Vector((0,0,height/2)))+center
            return m.transform(q)
        child=m.__class__(m.collection,place)
        atlas_x=style%8/8;atlas_y=1-(style//8+1)/4
        def color_patch(obj):
            for uv in obj.data.uv_layers.active.data:
                uv.uv=(atlas_x+.008,atlas_y+.008)
        cover=.0055
        for side in [-1,1]:
            obj=child.box('cloth binding cover',(side*(thickness/2-cover/2),0,height/2),
                          (cover,depth,height),bindings,.0015)
            color_patch(obj)
        child.box('recessed layered pages',(0,sign*.006,height/2),
                  (thickness-.013,depth-.026,height-.019),papers[style%len(papers)],.001)
        # Rounded convex spine, with a full original atlas tile facing outward.
        vertices=[];faces=[];segments=8
        for zz in [0,height]:
            for i in range(segments+1):
                u=i/segments
                vertices.append(((u-.5)*thickness,-sign*(depth/2+.004*math.sin(math.pi*u)),zz))
        for i in range(segments):
            a=i;b=i+1;c=b+segments+1;d=a+segments+1
            faces.append((a,b,c,d) if sign>0 else (d,c,b,a))
        spine=child.mesh('rounded titled book spine',vertices,faces,bindings,True)
        for face in spine.data.polygons:
            for li in face.loop_indices:
                vi=spine.data.loops[li].vertex_index
                u=(vi%(segments+1))/segments
                if sign<0:u=1-u
                v=vi//(segments+1)
                spine.data.uv_layers.active.data[li].uv=(atlas_x+(u*.96+.02)/8,atlas_y+(v*.98+.01)/4)
        # Bound ribs and visible fine page edges break up the simple block form.
        if style%3==0:
            for fraction in [.14,.28,.77,.90]:
                color_patch(child.box('raised leather spine band',(0,-sign*(depth/2+.004),height*fraction),
                                      (thickness*.94,.004,.006),bindings,.001))
        for i in range(5):
            zz=.025+(height-.05)*(i+.3)/5
            child.box('individual page edge',(0,sign*(depth/2-.012),zz),
                      (thickness-.015,.0014,.0012),papers[(style+1)%len(papers)],0)
        # Worn gilt head and tail details are deliberately sparse.
        if style%5==2:
            for zz in [.012,height-.012]:
                child.box('binding headband',(0,-sign*(depth/2-.002),zz),
                          (thickness-.014,.005,.004),bronze,.0005)
        m.parts.extend(child.parts)
        inventory.append({'style':style,'title':TITLES[style].replace('\n',' '),
                          'height':height,'thickness':thickness,'flat':flat})

    def upright_group(left,styles,span):
        sizes=[rng.uniform(.048,.082) for _ in styles]
        factor=(span-.003*(len(styles)-1))/sum(sizes)
        cursor=left
        for j,(style,t) in enumerate(zip(styles,sizes)):
            t*=factor
            h=rng.uniform(.275,.405) if level==0 else rng.uniform(.32,.49)
            book(cursor+t/2,z,t,h,rng.uniform(.21,.27),style)
            cursor+=t+.003

    left=x-width/2
    if level==0:
        # Low horizontal garden folios on the left, nine eclectic bindings right.
        stack_z=z
        for j,style in enumerate([25,18,5]):
            t=[.042,.034,.048][j]
            book(left+.165+(.012 if j==1 else 0),stack_z,t,.29-j*.017,.245,style,flat=True)
            stack_z+=t+.002
        upright_group(left+.35,[3,6,29,4,30,7,22,23,0],width-.35)
    else:
        # A fuller reading collection: tall run, four stacked volumes, short run.
        upright_group(left,[12,9,14,1,20,15,27],.49)
        stack_z=z
        for j,style in enumerate([19,28,16,10]):
            t=[.051,.044,.038,.048][j]
            book(left+.665+(.012 if j%2 else -.008),stack_z,t,.30-j*.012,.25,style,flat=True)
            stack_z+=t+.002
        upright_group(left+.85,[11,8,17,21,24,26],width-.85)
    # Slim brass stops frame each collection, without repeating its book order.
    for side in [-1,1]:
        xx=x+side*(width/2+.018)
        m.box('slim brass book stop',(xx,y,z+.095),(.012,.20,.19),bronze,.003)
        m.box('book stop foot',(xx-side*.027,y,z+.006),(.065,.20,.012),dark,.002)
    return inventory
