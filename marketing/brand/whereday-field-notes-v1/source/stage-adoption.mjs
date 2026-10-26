import {createRequire} from 'node:module';
import {mkdir,copyFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const req=createRequire(import.meta.url);
const sharp=req('sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.resolve(root,'../../public/assets/whereday-field-notes-v1');await mkdir(out,{recursive:true});
for(const [name,source,widths] of [
 ['product-banner','headers/product-banner-1600x600.png',[768,1280,1600]],
 ['product-hero','headers/product-hero-2400x1350.png',[768,1280,1920]],
 ['launch-card','headers/launch-card-1080x1080.png',[640,1080]],
 ['city-panorama','art/city-panorama.png',[768,1280,1920]]
])for(const width of widths)await sharp(path.join(root,source)).resize({width}).webp({quality:88,effort:6}).toFile(path.join(out,`${name}-${width}.webp`));
await copyFile(path.join(root,'headers/social-preview-1200x630.png'),path.join(out,'social-preview-1200x630.png'));
console.log('Prepared responsive header assets and the approved social preview.');
