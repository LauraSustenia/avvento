/* Cornice vettoriale: ogni raccordo è identico, indipendentemente dall'ordine. */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'images', 'cornice');
fs.mkdirSync(output, { recursive: true });
function samplePath(d) {
  const points=[]; let x=0,y=0;
  for(const match of d.matchAll(/([MCQVLl])([^MCQVLl]*)/g)) {
    const values=match[2].match(/-?\d*\.?\d+/g).map(Number),command=match[1];
    if(command==='M'){[x,y]=values;points.push([x,y]);continue;}
    const start=[x,y];
    for(let step=1;step<=12;step++) {
      const t=step/12,u=1-t;
      if(command==='C'){x=u*u*u*start[0]+3*u*u*t*values[0]+3*u*t*t*values[2]+t*t*t*values[4];y=u*u*u*start[1]+3*u*u*t*values[1]+3*u*t*t*values[3]+t*t*t*values[5];}
      if(command==='Q'){x=u*u*start[0]+2*u*t*values[0]+t*t*values[2];y=u*u*start[1]+2*u*t*values[1]+t*t*values[3];}
      if(command==='V'){x=start[0];y=start[1]+t*(values[0]-start[1]);}
      if(command==='L'){x=start[0]+t*(values[0]-start[0]);y=start[1]+t*(values[1]-start[1]);}
      if(command==='l'){x=start[0]+t*values[0];y=start[1]+t*values[1];}
      points.push([x,y]);
    }
  }
  return points;
}
const pen = (d, color='#887553', width=6.5) => {
  const points=samplePath(d),left=[],right=[];
  points.forEach((p,i)=>{
    const a=points[Math.max(0,i-1)],b=points[Math.min(points.length-1,i+1)];
    const boundary=i===0||i===points.length-1;
    const dx=boundary?0:b[0]-a[0],dy=boundary?1:b[1]-a[1],length=Math.hypot(dx,dy)||1;
    const endpoint=i<2||i>points.length-3;
    const taper=width<5?Math.max(.025,1-i/(points.length-1)):1;
    const radius=width/2*taper*(endpoint?1:1+.12*Math.sin(i*1.71)+.07*Math.sin(i*.53));
    left.push([p[0]-dy/length*radius,p[1]+dx/length*radius]);
    right.push([p[0]+dy/length*radius,p[1]-dx/length*radius]);
  });
  const outline=[...left,...right.reverse()].map(p=>p.map(n=>n.toFixed(2)).join(' '));
  return `<path d="M${outline.join('L')}Z" fill="url(#bark)" stroke="#77562f" stroke-width=".2" stroke-linejoin="round"/>`;
};
// Due rametti si incrociano. Ogni modulo raccorda x=42 e x=60 con tangenti verticali.
const twigProfiles = [
  [[42,38,48,57,56,60],[60,66,57,44,47,42]],
  [[42,47,40,56,64,60],[60,63,55,49,38,42]],
  [[42,37,54,50,63,60],[60,65,52,57,37,42]],
  [[42,49,45,61,55,60],[60,59,65,44,47,42]],
  [[42,39,46,62,57,60],[60,67,53,48,39,42]],
  [[42,46,41,54,65,60],[60,62,58,41,48,42]]
];
function twigPath(xs) {
  const points=xs.map((x,i)=>[x,i*36]);
  const tangents=points.map((p,i)=>i===0||i===5?[0,36]:[(points[i+1][0]-points[i-1][0])/2,36]);
  let d=`M${points[0].join(' ')}`;
  for(let i=1;i<points.length;i++) {
    const a=points[i-1],b=points[i],ta=tangents[i-1],tb=tangents[i];
    d+=`C${(a[0]+ta[0]/3).toFixed(2)} ${a[1]+12} ${(b[0]-tb[0]/3).toFixed(2)} ${b[1]-12} ${b.join(' ')}`;
  }
  return d;
}
function twigPair(index) {
  const profiles=twigProfiles[index];
  let result=pen(twigPath(profiles[0]))+pen(twigPath(profiles[1]));
  // Piccole diramazioni cieche con lunghezze e orientamenti diversi, unite ai nodi reali.
  const branches=index%2===0?[[0,1,-1,14],[1,3,1,18],[0,4,-1,9]]:[[1,1,1,10],[0,2,-1,19],[1,4,1,14],[0,3,1,8]];
  for(const [stem,node,direction,length] of branches) {
    const x=profiles[stem][node],y=node*36;
    const endX=x+direction*length,endY=y-length*.85;
    result+=pen(`M${x} ${y}Q${x+direction*length*.7} ${y-3} ${endX} ${endY}`,'#99825e',2.2);
    if(length>14) result+=pen(`M${x+direction*length*.7} ${y-length*.4}l${direction*3} -7`,'#a28a63',1.3);
  }
  return result;
}
const decorTypes={leaf:'foglia-pioppo.png',oak:'foglia-farnia.png',ivy:'foglia-edera.png',snow:'fiocco-cornice.png'};
const decorationManifest={};
// Le foglie sono PNG illustrate condivise: non piccole sagome vettoriali.
const decorativeUse = (id,x,y,size,angle=0) => ({file:decorTypes[id],x,y,size,angle});
const paintedVariants=[
 [decorativeUse('leaf',21,38,23,-55),decorativeUse('snow',86,129,26),decorativeUse('oak',1148,79,29,42)],
 [decorativeUse('ivy',52,112,29,34),decorativeUse('snow',1181,33,22),decorativeUse('leaf',1106,151,24,-62)],
 [decorativeUse('snow',93,28,25),decorativeUse('oak',23,146,26,-32),decorativeUse('ivy',1121,94,31,24)],
 [decorativeUse('leaf',77,59,29,62),decorativeUse('snow',1153,137,22),decorativeUse('oak',1180,37,24,-40)],
 [decorativeUse('oak',49,86,28,-25),decorativeUse('leaf',1110,27,26,75),decorativeUse('snow',1179,152,23)],
 [decorativeUse('snow',20,103,23),decorativeUse('ivy',91,154,29,-26),decorativeUse('leaf',1135,58,24,28),decorativeUse('snow',1148,121,20)]
];
const bark=fs.readFileSync(path.join(root,'images','corteccia-cornice.jpg')).toString('base64');
const svg = (height,body,phase=0) => `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="${height}" viewBox="0 0 1200 ${height}"><defs><pattern id="bark" patternUnits="userSpaceOnUse" width="96" height="180" y="${phase}"><image width="96" height="180" preserveAspectRatio="none" href="data:image/jpeg;base64,${bark}"/></pattern></defs>${body}</svg>`;
paintedVariants.forEach((decorations,i)=>{
  const left=twigPair(i);
  const right=twigPair((i+3)%6);
  decorationManifest[String(i+1)]=paintedVariants[i];
  fs.writeFileSync(path.join(output,`fascia-${i+1}.svg`),svg(180,left+`<g transform="translate(1200 0) scale(-1 1)">${right}</g>`));
});
fs.mkdirSync(path.join(root,'_data'),{recursive:true});
fs.writeFileSync(path.join(root,'_data','frame_decorations.json'),JSON.stringify(decorationManifest,null,2));
const original = name => `<image width="1200" height="400" href="data:image/png;base64,${fs.readFileSync(path.join(root,'images',name+'.png')).toString('base64')}"/>`;
const headStart=pen('M25 338C28 358 42 373 42 400')+pen('M29 343C36 363 60 375 60 400');
fs.writeFileSync(path.join(output,'testa.svg'),svg(400,headStart+`<g transform="translate(1200 0) scale(-1 1)">${headStart}</g>`+original('testa'),40));
const tailEnd=pen('M42 0C42 42 51 80 44 116C38 157 27 195 24 228')+pen('M60 0C60 38 48 71 55 110C60 164 48 211 42 246');
fs.writeFileSync(path.join(output,'coda.svg'),svg(400,tailEnd+`<g transform="translate(1200 0) scale(-1 1)">${tailEnd}</g>`+original('coda')));
console.log('Testa e coda originali; sei moduli con due rametti incrociati e accenti irregolari. Raccordi x42/x60.');
