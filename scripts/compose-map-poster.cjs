/* One finished poster image: newly painted habitat, exact cartography and official GIAPP logo. */
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('C:/Users/l.porceddu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const config = require('../_data/map_poster.json');
const W = config.width, H = config.height;
const source = path.join(__dirname, 'frame-source', 'poster');

async function main() {
  await fs.mkdir(source, {recursive:true});
  const background=await sharp(path.join(source,'poster-integrated.png')).resize(W,H,{fit:'cover'}).png().toBuffer();
  const layers=[];
  let svg=await fs.readFile(path.join(root,'images/mappa-giapp.svg'),'utf8');
  svg=svg.replace(/<rect\b[^>]*fill="#f6f3e7"[^>]*\/>/,'');
  const mapWidth=config.map_width,mapHeight=Math.round(config.map_height);
  const pixels=await sharp(Buffer.from(svg),{density:190}).resize(mapWidth,mapHeight).ensureAlpha().raw().toBuffer();
  // Keep exact geographic lines, with translucent colour so the painted ground remains continuous.
  for(let i=3;i<pixels.length;i+=4)pixels[i]=Math.round(pixels[i]*.88);
  const map=await sharp(pixels,{raw:{width:mapWidth,height:mapHeight,channels:4}}).png().toBuffer();
  layers.push({input:map,left:config.map_x,top:config.map_y});
  const logoSvg=await fs.readFile(path.join(root,'images/giapp-logo.svg'),'utf8');
  const officialPng=Buffer.from(logoSvg.match(/base64,([^\"]+)/)[1],'base64');
  const officialLogo=await sharp(officialPng).trim().png().toBuffer();
  await fs.writeFile(path.join(source,'giapp-official.png'),officialLogo);
  const logo=await sharp(officialLogo).resize({width:1180}).png().toBuffer();
  layers.push({input:logo,top:100,left:Math.round((W-1180)/2)});
  const poster=await sharp(background).composite(layers).png().toBuffer();
  await sharp(poster).webp({quality:94,effort:6}).toFile(path.join(root,'images/mappa-avvento-poster.webp'));
  await sharp(poster).resize({width:1086}).png().toFile(path.join(source,'poster-preview.png'));
  console.log('Poster:',W,H,'Map:',config.map_x,config.map_y,config.map_width,config.map_height);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
