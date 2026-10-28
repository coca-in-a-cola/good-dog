#!/usr/bin/env python3
"""Verify native production credit glyph pixels, not merely Control bounds."""
import json
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[2]
def main():
    results = {}
    for width, height in [(1920,1080),(720,1280),(2560,1080)]:
        path = ROOT / f'evidence/f3/credits-repair/credits-{width}x{height}.png'
        pixels = subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','rawvideo','-pix_fmt','rgb24','-'])
        assert len(pixels) == width*height*3, path
        rows = {}
        count = 0
        for y in range(height):
            row = pixels[y*width*3:(y+1)*width*3]
            xs = [x for x in range(width) if max(row[x*3:x*3+3])<90]
            if xs:
                rows[y] = (min(xs),max(xs))
                count += len(xs)
        assert count > 1000, 'missing native text pixels'
        left=min(x[0] for x in rows.values()); right=max(x[1] for x in rows.values())
        top=min(rows); bottom=max(rows)
        assert left > width*.055 and right < width*.945, 'horizontal glyph clipping'
        assert top > height*.055 and bottom < height*.945, 'vertical glyph clipping'
        bands=[]
        for y in rows:
            if not bands or y>bands[-1][-1]+1: bands.append([])
            bands[-1].append(y)
        lines=[]
        for band in bands:
            lo=min(rows[y][0] for y in band); hi=max(rows[y][1] for y in band)
            center=(lo+hi)/2
            assert abs(center-width/2)<5, f'uncentered actual glyph line {center} at {width}'
            lines.append([lo,band[0],hi,band[-1]])
        assert abs((top+bottom)/2-height/2)<12, 'uncentered vertical glyph group'
        results[path.name]={'ink_pixels':count,'glyph_bounds':[left,top,right,bottom],'line_ink_bounds':lines}
    print(json.dumps(results,indent=2))
if __name__ == '__main__': main()
