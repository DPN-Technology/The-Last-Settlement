#!/usr/bin/env python3
"""Quantitative guardrail for actual GL rendered screenshots.

Values from the player's 1600x900 reference image in central unobscured
world region x=300:1400, y=130:650. High edge contrast alone is NOT proof
of art quality or fidelity; a human must inspect PNG captures before signoff.
"""
import json
import math
from pathlib import Path
import struct
import zlib

TARGET = {"mean_luminance":76.4,"detail":25.6,"luma_spread":42.2,"structural_detail":32.8}
# Built-in Python PNG decoder; dependency-free and safely bounds image sizes.
def decode_png(path):
    data=Path(path).read_bytes()
    if data[:8]!=b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    w=h=mode=0
    compressed=bytearray()
    p=8
    while p<len(data):
        n=struct.unpack(">I",data[p:p+4])[0]
        chunk=data[p+4:p+8]
        body=data[p+8:p+8+n]
        if chunk==b"IHDR":
            w,h,depth,mode,_,_,interlace=struct.unpack(">IIBBBBB",body)
            if w>4096 or h>2500 or depth!=8 or mode not in (2,6) or interlace!=0:
                raise ValueError("expected 8-bit non-interlaced RGB/RGBA screenshot")
        if chunk==b"IDAT":
            compressed.extend(body)
        if chunk==b"IEND":
            break
        p+=n+12
    channels=3 if mode==2 else 4
    pixels=zlib.decompress(compressed)
    row_size=w*channels
    if len(pixels)!=(row_size+1)*h:
        raise ValueError("bad PNG data length")
    rows=[]
    old=bytearray(row_size)
    offset=0
    for _ in range(h):
        typ=pixels[offset]
        offset+=1
        encoded=pixels[offset:offset+row_size]
        offset+=row_size
        row=bytearray(row_size)
        for j,b in enumerate(encoded):
            left=row[j-channels] if j>=channels else 0
            up=old[j]
            ul=old[j-channels] if j>=channels else 0
            if typ==0:
                v=b
            elif typ==1:
                v=b+left
            elif typ==2:
                v=b+up
            elif typ==3:
                v=b+(left+up)//2
            elif typ==4:
                predictor=left+up-ul
                a,bp,c=abs(predictor-left),abs(predictor-up),abs(predictor-ul)
                v=b+([left,up,ul][0 if a<=bp and a<=c else 1 if bp<=c else 2])
            else:
                raise ValueError("unsupported PNG filter")
            row[j]=v&255
        rows.append(row)
        old=row
    return w,h,channels,rows

def measure(png):
    width,height,ch,rows=decode_png(png)
    # Explicit reference ROI definition scales with the captured screen.
    scale_x=width/1600.0
    scale_y=height/900.0
    left,right=int(300*scale_x),int(1400*scale_x)
    top,bottom=int(130*scale_y),int(650*scale_y)
    area=[]
    edges=[]
    structural=[]
    last_blocks=None
    first=None
    for y in range(top,bottom):
        line=rows[y]
        values=[]
        for x in range(left,right):
            c=line[x*ch:x*ch+3]
            values.append((54*c[0]+183*c[1]+19*c[2])/256.0)
        area.extend(values)
        edges.extend(abs(values[i]-values[i-1]) for i in range(1,len(values)))
        if first is not None:
            edges.extend(abs(v-first[i]) for i,v in enumerate(values))
        first=values
        # Downsampling 4x4 blocks suppresses granular texture that would
        # otherwise inflate a visual metric without enriching the buildings.
        if (y-top)%4==3:
            blocks=[]
            for x in range(0,len(values)-3,4):
                start=left+x
                total=0.0
                for yy in range(y-3,y+1):
                    source=rows[yy]
                    for xx in range(start,start+4):
                        idx=xx*ch
                        total+=(54*source[idx]+183*source[idx+1]+19*source[idx+2])/256.0
                blocks.append(total/16.0)
            structural.extend(abs(blocks[i]-blocks[i-1]) for i in range(1,len(blocks)))
            if last_blocks is not None:
                structural.extend(abs(current-prior) for current,prior in zip(blocks,last_blocks))
            last_blocks=blocks
    mean=sum(area)/len(area)
    std=math.sqrt(sum((v-mean)**2 for v in area)/len(area))
    detail=sum(edges)/len(area) * 2 # Match adjacent x+y per-pixel detail
    shape_detail=sum(structural)/max(1,len(structural))*2
    return {"mean_luminance":round(mean,1),"luma_spread":round(std,1),"detail":round(detail,1),"structural_detail":round(shape_detail,1),"size":[width,height]}

def main():
    folder=Path("dist/visual")
    outcomes={}
    for path in sorted(folder.glob("*_HUD.png")):
        outcomes[path.stem]=measure(path)
    if len(outcomes)!=4:
        raise SystemExit("Missing actual in-engine screenshots; refusing to judge art")
    overview=outcomes["01_Overview_HUD"]
    overview["detail_fraction_of_target"]=round(overview["detail"]/TARGET["detail"],2)
    overview["brightness_fraction_of_target"]=round(overview["mean_luminance"]/TARGET["mean_luminance"],2)
    overview["structural_fraction_of_target"]=round(overview["structural_detail"]/TARGET["structural_detail"],2)
    overview["reference_ready_metric_only"]=(
        overview["structural_fraction_of_target"]>=0.87
        and 0.78<=overview["brightness_fraction_of_target"]<=1.20
        and overview["luma_spread"]>=TARGET["luma_spread"]*0.78
    )
    record={"source":"actual Godot gl_compatibility rendered frames","reference":"user-provided cinematic concept", "goal":TARGET,"captures":outcomes,"note":"Numeric similarity is NOT visual approval; manually inspect PNGs."}
    (folder/"visual-review.json").write_text(json.dumps(record,indent=2)+"\n")
    print(json.dumps(record,indent=2))
    if not overview["reference_ready_metric_only"]:
        print("VISUAL REVIEW: NOT REFERENCE READY; retain PR open and keep replacing low-fidelity assets")
    else:
        print("VISUAL REVIEW: METRICS ACCEPTABLE ONLY; must still compare images manually")

if __name__=="__main__":
    main()
