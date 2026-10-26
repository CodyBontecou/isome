#!/usr/bin/env python3
"""Compose localized, real iPad feature captures in Whereday's field-notes design."""
import argparse,json,pathlib,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageFilter
from compose_white import FONT_OVERRIDES,FONT_TTC_INDEX,load_font,word_wrap,fit_wrapped_font,shape_arabic
ROOT=pathlib.Path(__file__).resolve().parents[1]
PAPER='#F8F5EB';INK='#203557';MUTED='#566272'

def compose(locale,copy,raw,out):
    lang=locale.split('-')[0];font=FONT_OVERRIDES.get(locale,FONT_OVERRIDES.get(lang,'/System/Library/Fonts/Supplemental/Georgia.ttf'))
    index=FONT_TTC_INDEX.get(locale,FONT_TTC_INDEX.get(lang,0));transform=shape_arabic if lang=='ar' else None
    canvas=ImageOps.fit(Image.open(ROOT/'marketing/brand/whereday-field-notes-v1/art/city-portrait.png').convert('RGB'),(2064,2752))
    wash=Image.new('RGB',canvas.size,PAPER);canvas=Image.blend(canvas,wash,.32);draw=ImageDraw.Draw(canvas)
    draw.text((125,90),'Whereday',font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Georgia.ttf',80),fill=INK)
    mono=ImageFont.truetype('/System/Library/Fonts/SFNSMono.ttf',30)
    draw.text((1939,130),'FIELD NOTES / '+copy['name'][:2],font=mono,fill=MUTED,anchor='ra')
    draw.line((125,205,1939,205),fill='#B8BEBC',width=3)
    titlefont=fit_wrapped_font(copy['title'],1814,2,116,72,font,index,transform=transform)
    bodyfont=fit_wrapped_font(copy['subtitle'],1780,2,52,38,font,index,transform=transform)
    for text,y,f,gap in [(copy['title'],260,titlefont,140),(copy['subtitle'],555,bodyfont,68)]:
        for i,line in enumerate(word_wrap(draw,text,f,1780,transform)):
            line=transform(line) if transform else line
            draw.text((1032,y+i*gap),line,font=f,fill=INK if y==260 else MUTED,anchor='mt')
    screen=Image.open(raw).convert('RGB');assert screen.size==(2064,2752),screen.size
    screen=screen.resize((1450,1933),Image.Resampling.LANCZOS)
    x=307;y=741
    shadow=Image.new('RGBA',canvas.size);sd=ImageDraw.Draw(shadow);sd.rounded_rectangle((x-20,y-12,x+1470,y+1953),radius=66,fill=(24,38,54,80));shadow=shadow.filter(ImageFilter.GaussianBlur(20));canvas=Image.alpha_composite(canvas.convert('RGBA'),shadow)
    draw=ImageDraw.Draw(canvas);draw.rounded_rectangle((x-18,y-18,x+1468,y+1951),radius=64,fill='#252E35',outline='#788287',width=3)
    mask=Image.new('L',screen.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,1449,1932),radius=49,fill=255);canvas.paste(screen,(x,y),mask)
    out.parent.mkdir(parents=True,exist_ok=True);canvas.convert('RGB').save(out)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--locales',default='en-US,ar-SA,es-ES,fr-FR,hi,ja,pt-BR,ru,zh-Hans');a=ap.parse_args()
    copy=json.loads((ROOT/'screenshots/localized-copy.json').read_text());base=ROOT/'screenshots/whereday/ipad-v2';manifest=[]
    for locale in a.locales.split(','):
        for c in copy[locale]:
            out=base/'ready'/locale/(c['name']+'.png');compose(locale,c,base/'raw'/locale/(c['name']+'.png'),out)
            manifest.append(dict(file=str(out.relative_to(ROOT)),width=2064,height=2752,sha256=hashlib.sha256(out.read_bytes()).hexdigest()))
        files=sorted((base/'ready'/locale).glob('*.png'));sheet=Image.new('RGB',(1660,490),'#DDDCD4')
        for i,p in enumerate(files):sheet.paste(Image.open(p).resize((330,440)),(i*332,25))
        (base/'review').mkdir(exist_ok=True);sheet.save(base/'review'/(locale+'.jpg'),quality=92)
    (base/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Composed',len(manifest),'iPad screenshots')
if __name__=='__main__':main()
