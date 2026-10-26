import {createRequire} from 'node:module';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const req=createRequire(import.meta.url);
const sharp=req('sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const C={paper:'#F8F5EB',ink:'#203557',muted:'#566272',rust:'#A95138',rule:'#B8BEBC'};
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const imgs={};
async function image(file){if(!imgs[file])imgs[file]='data:image/png;base64,'+(await readFile(path.join(root,file))).toString('base64');return imgs[file]}
function text(s,x,y,size=48,opts={}){return `<text x="${x}" y="${y}" font-family="${opts.mono?'SFMono-Regular, monospace':'Georgia, serif'}" font-size="${size}" fill="${opts.fill||C.ink}" ${opts.anchor?`text-anchor="${opts.anchor}"`:''} ${opts.spacing?`letter-spacing="${opts.spacing}"`:''}>${esc(s)}</text>`}
function lines(a,x,y,size,gap,opts={}){return a.map((s,i)=>text(s,x,y+i*gap,size,opts)).join('')}
function svg(w,h,content){return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><rect width="${w}" height="${h}" fill="${C.paper}"/>${content}</svg>`}
function label(s,x,y,size=27){return text(s.toUpperCase(),x,y,size,{mono:true,spacing:2,fill:C.muted})}
function dot(x,y,r=7){return `<circle cx="${x}" cy="${y}" r="${r}" fill="${C.rust}"/>`}
async function background(w,h,wide=false){return `<image href="${await image('art/'+(wide?'city-panorama.png':'city-portrait.png'))}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid slice"/>`}
async function phone(name,x,y,w,angle=0){
 const file='source/screens/'+name+'.png';const meta=await sharp(path.join(root,file)).metadata();
 const h=w*meta.height/meta.width;const b=12;const id='screen-'+name;
 return `<g transform="rotate(${angle} ${x+w/2} ${y+h/2})"><defs><clipPath id="${id}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${w*.095}"/></clipPath><filter id="soft-${name}" x="-25%" y="-10%" width="150%" height="130%"><feDropShadow dx="0" dy="16" stdDeviation="17" flood-color="#1E2D40" flood-opacity=".13"/></filter></defs><rect x="${x-b}" y="${y-b}" width="${w+2*b}" height="${h+2*b}" rx="${w*.108}" fill="#252E35" filter="url(#soft-${name})"/><rect x="${x-5}" y="${y-5}" width="${w+10}" height="${h+10}" rx="${w*.10}" fill="none" stroke="#788287" stroke-width="2"/><image href="${await image(file)}" x="${x}" y="${y}" width="${w}" height="${h}" clip-path="url(#${id})"/></g>`;
}
const assets=[];
async function save(kind,name,w,h,content){
 const doc=svg(w,h,content),dir=path.join(root,kind);await mkdir(dir,{recursive:true});
 await writeFile(path.join(dir,name+'.svg'),doc);
 await sharp(Buffer.from(doc)).flatten({background:C.paper}).png().toFile(path.join(dir,name+'.png'));
 assets.push({file:kind+'/'+name+'.png',source:kind+'/'+name+'.svg',width:w,height:h});
}
const frames=[
 {name:'01-places',screen:'map',tag:'Your private location journal',title:['Remember where','you’ve been.'],body:['Your visits and routes.','Privately on your device.'],x:326,y:856,w:834,angle:2,caption:'THE PLACES THAT MAKE A DAY'},
 {name:'02-timeline',screen:'timeline',tag:'A record of the everyday',title:['Your day.','All in one place.'],body:['Visits and journeys, together','in one daily timeline.'],x:122,y:856,w:834,angle:-2,caption:'ONE DAY, VISIT BY VISIT'},
 {name:'03-routes',screen:'route',tag:'Every outing has a story',title:['A route worth','remembering.'],body:['Replay the path, time and distance','of each recorded outing.'],x:326,y:856,w:834,angle:2,caption:'FOLLOW YOUR OWN FOOTSTEPS'},
 {name:'04-country-days',screen:'country',tag:'For days a little farther away',title:['A little here.','A little there.'],body:['Count your days by country.','Add past stays to your record.'],x:122,y:856,w:834,angle:-2,caption:'YOUR DAYS, COUNTRY BY COUNTRY'},
 {name:'05-export',screen:'export',tag:'Your data travels with you',title:['Your history.','Yours to keep.'],body:['Export GPX, CSV and more.','One purchase. No subscription.'],x:186,y:1140,w:1000,angle:2,caption:'8 OPEN FORMATS'}
];

for(let i=0;i<frames.length;i++){
 const f=frames[i];let s=await background(1290,2796);
 s+=text('Whereday',105,142,66)+label('FIELD NOTES / '+String(i+1).padStart(2,'0'),1185,130,25).replace('<text ','<text text-anchor="end" ');
 s+=`<path d="M105 195 Q640 198 1185 194" fill="none" stroke="${C.rule}" stroke-width="2"/>`;
 s+=label(f.tag,105,270,23);
 s+=lines(f.title,100,448,128,146);
 s+=lines(f.body,105,704,43,61,{fill:C.muted});
 if(i===4)s+=dot(112,882)+label('Eight formats. One lifetime unlock.',140,890,25);
 s+=await phone(f.screen,f.x,f.y,f.w,f.angle);
 if(i!==4)s+=`<rect x="85" y="2680" width="1120" height="65" fill="${C.paper}" fill-opacity=".93"/>`+dot(111,2715,6)+label(f.caption,137,2724,22);
 await save('app-store',f.name,1290,2796,s);
}

// Product hero: 16:9, with a real map screen as the focal product proof.
let hero=await background(2400,1350,true);
hero+=text('Whereday',140,151,74)+label('A PRIVATE LOCATION JOURNAL',142,220,24);
hero+=lines(['A little journal.','Of everywhere.'],132,464,132,160);
hero+=lines(['Remember your visits, replay your routes,','and keep a record that stays yours.'],142,744,38,58,{fill:C.muted});
hero+=dot(153,858,7)+label('Free tracking. Lifetime export options.',180,867,24);
hero+=await phone('map',1580,110,497,5);
await save('headers','product-hero-2400x1350',2400,1350,hero);

let og=await background(1200,630,true);
og+=text('Whereday',64,74,40)+label('A PRIVATE LOCATION JOURNAL',66,110,13);
og+=lines(['A little journal.','Of everywhere.'],60,232,72,86);
og+=lines(['Your visits and routes.','Privately on your iPhone.'],66,378,24,35,{fill:C.muted});
og+=await phone('map',831,55,247,4);
await save('headers','social-preview-1200x630',1200,630,og);

// Compact product header: artwork plus editorial copy, without a device mockup.
let banner=`<image href="${await image('art/city-panorama.png')}" x="0" y="-100" width="1600" height="900"/>`;
banner+=text('Whereday',80,95,48)+label('YOUR DAYS, DRAWN TOGETHER',82,152,16);
banner+=lines(['Life leaves a trail.','Keep yours.'],76,276,82,96);
banner+=text('A private journal of your visits and routes.',82,436,24,{fill:C.muted});
await save('headers','product-banner-1600x600',1600,600,banner);

// Square launch card for product directories, announcements and social posts.
let card=await background(1080,1080,true);
card+=text('Whereday',84,113,58)+label('A PRIVATE LOCATION JOURNAL',86,173,18);
card+=lines(['A little journal.','Of everywhere.'],80,330,88,108);
card+=text('Remember where you’ve been.',86,520,29,{fill:C.muted});
card+=`<rect x="70" y="974" width="940" height="54" fill="${C.paper}" fill-opacity=".94"/>`+dot(91,1001,5)+label('VISITS / ROUTES / COUNTRY DAYS / EXPORT',112,1009,16);
await save('headers','launch-card-1080x1080',1080,1080,card);

// Preview sheet. Production artwork and real app views remain separate in SVG.
await mkdir(path.join(root, "review"), { recursive: true });
const appThumbs=await Promise.all(assets.filter(a=>a.file.startsWith('app-store')).map(a=>sharp(path.join(root,a.file)).resize(258,559).toBuffer()));
const heroThumb=await sharp(path.join(root,'headers/product-hero-2400x1350.png')).resize(1390,782).toBuffer();
const bannerThumb=await sharp(path.join(root,'headers/product-banner-1600x600.png')).resize(900,338).toBuffer();
const cardThumb=await sharp(path.join(root,'headers/launch-card-1080x1080.png')).resize(420,420).toBuffer();
await sharp({create:{width:1454,height:1890,channels:3,background:'#DDDCD4'}}).composite([
 {input:heroThumb,left:32,top:32},
 ...appThumbs.map((input,i)=>({input,left:32+i*283,top:846})),
 {input:bannerThumb,left:32,top:1484},{input:cardThumb,left:1002,top:1438}
]).jpeg({quality:94}).toFile(path.join(root,'review/design-board.jpg'));
await writeFile(path.join(root,'source/copy.json'),JSON.stringify(frames,null,2)+'\n');
await writeFile(path.join(root,'manifest.json'),JSON.stringify({name:'Whereday field notes',version:1,reference:'https://kevintngo.com/',locale:'en-US',status:'design_review',uploaded:false,assets},null,2)+'\n');
console.log(JSON.stringify(assets,null,2));
