#!/usr/bin/env python3
# 시안(AI 생성 이미지)에서 앱 아이콘을 깨끗하게 다시 그린다.
#
# 시안을 그대로 키우면 가장자리 잡티가 도드라진다. 그래서 모양(마스크)만 따서
# 크게 키워 흐린 뒤 이진화해 가장자리를 매끈하게 하고, 색은 원본 색을 크게 흐린
# 색 마당으로 다시 칠한다. 바탕 스퀘어클과 그림자는 새로 그린다.
#
#   python3 scripts/redraw-app-icon.py <시안.png> [x0 y0 x1 y1]
#   → Resources/AppIcon.png, Resources/MenuBarIconSource.png
#   이어서 swift scripts/make-menubar-icon.swift 를 돌린다.
#
# 자르는 상자 기본값은 2026-10-02 시안의 512×512 타일 위치다.
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, sys
SRC=sys.argv[1]
BOX=tuple(int(v) for v in sys.argv[2:6]) if len(sys.argv)>=6 else (79,60,630,613)
tile=Image.open(SRC).convert("RGB").crop(BOX).resize((551,551),Image.LANCZOS)
S=1024; side=824; off=(S-side)//2; K=4; B=side*K
# 1) 글리프 마스크: 밝기에서 부드러운 알파 → 크게 키워 블러 → 이진화 → 줄여 안티앨리어싱
lum=tile.convert("L")
soft=lum.point(lambda v: 0 if v<46 else 255 if v>77 else int((v-46)/31*255))
inner=Image.new("L",tile.size,0); ImageDraw.Draw(inner).rectangle((40,40,511,511),fill=255)
soft=ImageChops.multiply(soft,inner)
big=soft.resize((B,B),Image.LANCZOS).filter(ImageFilter.GaussianBlur(10))
big=big.point(lambda v:255 if v>=128 else 0)
glyph=big.resize((side,side),Image.LANCZOS)
# 2) 색: 원본 색을 크게 흐려 잡티 없는 색 마당을 만든다 (정규화 합성곱)
rgbm=Image.composite(tile,Image.new("RGB",tile.size),soft)
r=30
num=[c.filter(ImageFilter.GaussianBlur(r)) for c in rgbm.split()]
den=soft.filter(ImageFilter.GaussianBlur(r))
nd=den.load(); field=Image.new("RGB",tile.size); fp=field.load(); ns=[n.load() for n in num]
for y in range(551):
    for x in range(551):
        d=nd[x,y]
        if d<3: fp[x,y]=(110,150,250); continue
        fp[x,y]=tuple(min(255,int(ns[i][x,y]*255/d)) for i in range(3))
# 빈 곳까지 색을 번지게 한 뒤 한 번 더 흐린다
field=field.filter(ImageFilter.GaussianBlur(12)).resize((side,side),Image.BICUBIC)
# 3) 바탕: 연속 곡률 스퀘어클(초타원 n=5), 위가 조금 밝은 어두운 그라데이션
n=5.0; pts=[]
for i in range(2000):
    t=2*math.pi*i/2000; c,s=math.cos(t),math.sin(t)
    x=math.copysign(abs(c)**(2/n),c); y=math.copysign(abs(s)**(2/n),s)
    pts.append(((x+1)/2*(B-1),(y+1)/2*(B-1)))
sq=Image.new("L",(B,B),0); ImageDraw.Draw(sq).polygon(pts,fill=255); sq=sq.resize((side,side),Image.LANCZOS)
bg=Image.new("RGB",(side,side)); bd=ImageDraw.Draw(bg)
for y in range(side):
    t=y/(side-1); top=(40,44,54); bot=(17,19,25)
    bd.line((0,y,side,y),fill=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
art=Image.composite(field,bg,glyph); art.putalpha(sq)
canvas=Image.new("RGBA",(S,S),(0,0,0,0))
shm=Image.new("L",(S,S),0); shm.paste(sq,(off,off+10))
sh=Image.new("RGBA",(S,S),(0,0,0,0)); sh.putalpha(shm.point(lambda a:int(a*0.30))); sh=sh.filter(ImageFilter.GaussianBlur(16))
canvas=Image.alpha_composite(canvas,sh); layer=Image.new("RGBA",(S,S),(0,0,0,0)); layer.paste(art,(off,off)); canvas=Image.alpha_composite(canvas,layer)
canvas.save("Resources/AppIcon.png")
# 메뉴바 원본: 같은 깨끗한 마스크를 흰 바탕 검은 그림으로, 글리프에 꽉 맞춰
bb=glyph.getbbox(); x0,y0,x1,y1=bb; c=max(x1-x0,y1-y0); cx=(x0+x1)//2; cy=(y0+y1)//2; h=c//2+6
Image.eval(glyph,lambda v:255-v).crop((cx-h,cy-h,cx+h,cy+h)).save("Resources/MenuBarIconSource.png")
print("Resources/AppIcon.png, Resources/MenuBarIconSource.png")
