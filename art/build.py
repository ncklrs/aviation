import json,numpy as np,potrace
from PIL import Image, ImageDraw, ImageFilter
KEYS='highwing lowwing twin heli bizjet regional narrow wide medheli fighter milcargo tandem tiltrotor turboprop highwing-rg heavy-airlifter e-jet a320 b737 b757 a220 bizjet-light pc12'.split()
def n(v):
    a=abs(v); t=str(a//10) if a%10==0 else '%d.%d'%(a//10,a%10)
    if t.startswith('0.'): t=t[1:]
    return ('-' if v<0 else '')+t
def J(vs):
    o=''
    for v in vs:
        t=n(v); o+=t if (not o or t[0]=='-') else ' '+t
    return o
def path(pl,T):
    d=[];cur=(0,0)
    for c in pl:
        p=T(c.start_point); d.append(('m' if d else 'M')+J([p[0]-cur[0],p[1]-cur[1]])); cur=st=p
        for sg in c.segments:
            pts=[T(sg.c),T(sg.end_point)] if sg.is_corner else [T(sg.c1),T(sg.c2),T(sg.end_point)]
            vals=[];pc=cur
            for q in pts:
                ref=cur if not sg.is_corner else pc
                vals+= [q[0]-ref[0],q[1]-ref[1]]; pc=q
            d.append(('l' if sg.is_corner else 'c')+J(vals)); cur=pts[-1]
        d.append('z'); cur=st
    return ''.join(d)
out=json.load(open('art/paths.json'))
for k in (__import__('os').environ.get('ONLY') or ' '.join(KEYS)).split():
    im=Image.open(f'art/ai-{k}.jpg').convert('L')
    if k=='tandem':  # drop mid-gray fills (intake, stripes) so they trace as outlines, not black blocks
        g=np.array(im); m=Image.fromarray((((g>=70)&(g<215))*255).astype('uint8')).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5)); g=g.copy(); g[np.array(m)>0]=255; im=Image.fromarray(g)
    a=np.array(im)<150; ys,xs=np.where(a); im=im.crop((max(0,xs.min()-2),max(0,ys.min()-2),xs.max()+3,ys.max()+3))
    W=640 if k in ("bizjet","regional","narrow","wide","turboprop","fighter","e-jet","a320","b737","b757","a220","bizjet-light") else int(__import__("os").environ.get("W",600)); w,h=im.size; im=im.resize((W,round(h*W/w)),Image.LANCZOS)
    line=np.array(im)<170
    bw,bh=W,line.shape[0]; sc=min(190/bw,64/bh); ox=100-bw*sc/2; oy=69-bh*sc
    T=lambda p:(round((ox+p.x*sc)*10),round((oy+p.y*sc)*10))
    d=path(potrace.Bitmap(~line).trace(turdsize=6,alphamax=1.0,opttolerance=float(__import__("os").environ.get("OT",0.4))),T)
    b=Image.fromarray((line*255).astype('uint8')).filter(ImageFilter.MaxFilter(7))
    b=Image.fromarray(np.pad(np.array(b),2)).copy(); ImageDraw.floodfill(b,(0,0),128)
    m=np.array(b)[2:-2,2:-2]!=128
    m=np.array(Image.fromarray((m*255).astype('uint8')).filter(ImageFilter.MinFilter(7)))>0
    T2=lambda p:(round(ox+p.x*sc)*10,round(oy+p.y*sc)*10)
    s=path(potrace.Bitmap(~m).trace(turdsize=200,alphamax=1.3,opttolerance=3),T2)
    out[k]=(s,d); print(k,len(s),len(d))
    open(f'art/{k}.svg','w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -2 200 74"><path fill="#fff" d="{s}"/><path fill-rule="evenodd" d="{d}"/></svg>')
json.dump(out,open('art/paths.json','w'))
