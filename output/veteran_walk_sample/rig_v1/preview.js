import {SETTINGS,DIRECTIONS,VECTORS,poseAt,project} from './gait.js';
const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d');
const $=id=>document.getElementById(id);
const load=src=>new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>resolve(i);i.onerror=reject;i.src=src;});
// Runtime chroma-key material for the source atlas, shared by every frame.
function keyed(image){
  const c=document.createElement('canvas');c.width=image.width;c.height=image.height;
  const g=c.getContext('2d',{willReadFrequently:true});g.drawImage(image,0,0);
  const d=g.getImageData(0,0,c.width,c.height);
  for(let i=0;i<d.data.length;i+=4){const r=d.data[i],v=d.data[i+1],b=d.data[i+2];
    if(r>v*1.45+25&&b>v*1.45+25) d.data[i+3]=0;
  }g.putImageData(d,0,0);return c;
}
const [torso,parts,boots]=await Promise.all(['torso_parts.png','leg_parts.png','foot_parts.png'].map(load)).then(a=>a.map(keyed));
// Bounds/pivots are fixed rig authoring data, never estimated again per frame.
const tcw=torso.width/4,tch=torso.height/2;
// Use the same canonical art for left/right views to prevent costume drift.
// Imagegen rendered the requested E source facing left. Use the opposite profile
// cell for both cardinal sides so W points left and E points right after mirroring.
const sources=[0,7,2,5,4,5,2,7];
const mirrored=[false,true,true,true,false,false,false,false];
const anchors=[[.5,.83],[.5,.83],[.42,.83],[.36,.83],[.5,.87],[.36,.83],[.42,.83],[.46,.86]];
const pw=parts.width/3,ph=parts.height;
function segment(a,b,rect,top,bottom,width){
  const dx=b.x-a.x,dy=b.y-a.y,len=Math.hypot(dx,dy);
  ctx.save();ctx.translate(a.x,a.y);ctx.rotate(Math.atan2(dy,dx)-Math.PI/2);
  const scaleY=len/(bottom-top),height=rect[3]*scaleY;
  ctx.drawImage(parts,...rect,-width/2,-top*scaleY,width,height);ctx.restore();
}
function drawLeg(leg,dir){
  const h=project(leg.hip,dir),k=project(leg.knee,dir),a=project(leg.ankle,dir),f=project(leg.foot,dir);
  // Broader trouser attachment fills the waist connection; the source tapers at the knee.
  segment(h,k,[pw*.24,ph*.02,pw*.52,ph*.94],ph*.09,ph*.83,28);
  segment(k,a,[pw*1.22,ph*.035,pw*.53,ph*.92],ph*.075,ph*.815,21);
  const source=sources[dir],cw=boots.width/4,ch=boots.height/2;
  const footAnchors=[.5,.5,.7,.6,.5,.4,.30,.4];
  ctx.save();ctx.translate(f.x,f.y);if(mirrored[dir])ctx.scale(-1,1);
  ctx.drawImage(boots,source%4*cw,Math.floor(source/4)*ch,cw,ch,-footAnchors[source]*38,-.85*27,38,27);ctx.restore();
}
function drawTorso(p,dir){
  const source=sources[dir],col=source%4,row=Math.floor(source/4),anchor=anchors[source];
  const size=116;
  ctx.save();ctx.translate(0,-SETTINGS.hip-p.bob+4);if(mirrored[dir])ctx.scale(-1,1);
  ctx.drawImage(torso,col*tcw,row*tch,tcw,tch,-anchor[0]*size,-anchor[1]*size,size,size);ctx.restore();
}
function drawGrid(dir,phase){
  const [dx,dy]=VECTORS[dir],distance=2*SETTINGS.reach/SETTINGS.stance;
  // A repeating ground lattice moves at precisely the stance-foot velocity.
  const offset=phase*distance,spacing=distance;
  ctx.save();ctx.beginPath();ctx.rect(-72,-30,144,60);ctx.clip();ctx.strokeStyle='#38505d';ctx.lineWidth=.65;
  for(let u=-3;u<=3;u++)for(let v=-2;v<=2;v++){
    const q={x:u*spacing-offset,y:v*25,z:0},a=project(q,dir);
    ctx.beginPath();ctx.moveTo(a.x-3,a.y);ctx.lineTo(a.x+3,a.y);ctx.moveTo(a.x,a.y-2);ctx.lineTo(a.x,a.y+2);ctx.stroke();
  }ctx.restore();
}
function drawCharacter(dir,phase,x,y,scale,options={}){
  const p=poseAt(phase,options.idle??false);ctx.save();ctx.translate(x,y);ctx.scale(scale,scale);
  if(options.ground)drawGrid(dir,phase);
  if(options.shadow!==false){ctx.fillStyle='#10232b88';ctx.beginPath();ctx.ellipse(0,1,22,6,0,0,Math.PI*2);ctx.fill();}
  const ordered=[...p.legs].sort((a,b)=>project(a.hip,dir).depth-project(b.hip,dir).depth);
  ordered.forEach(l=>drawLeg(l,dir));drawTorso(p,dir);
  if(options.bones){for(const l of p.legs){const a=[l.hip,l.knee,l.ankle].map(v=>project(v,dir));
    ctx.strokeStyle='#7ee8ef';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(a[0].x,a[0].y);a.slice(1).forEach(p=>ctx.lineTo(p.x,p.y));ctx.stroke();
    for(const p of a){ctx.fillStyle='#bffcff';ctx.beginPath();ctx.arc(p.x,p.y,1.8,0,7);ctx.fill();}
    const f=project(l.foot,dir);ctx.fillStyle=l.contact?'#7aeb9b':'#ffb25d';ctx.beginPath();ctx.arc(f.x,f.y,2.5,0,7);ctx.fill();
  }}ctx.restore();
}
const positions=[[3,0,0],[4,1,0],[5,2,0],[2,0,1],[6,2,1],[1,0,2],[0,1,2],[7,2,2]];
export function render(phase,options={}){
  ctx.clearRect(0,0,canvas.width,canvas.height);
  if(!options.transparent){ctx.fillStyle='#20323d';ctx.fillRect(0,0,canvas.width,canvas.height);}
  const selected=options.direction??$('direction').value;
  if(selected!=='all'){
    const dir=typeof selected==='number'?selected:DIRECTIONS.indexOf(selected);
    drawCharacter(dir,phase,canvas.width*.5,canvas.height*.85,options.scale??3.8,options);
  }else{
    for(const [dir,col,row] of positions){
      drawCharacter(dir,phase,150+col*300,235+row*260,1.5,options);
      ctx.fillStyle='#b9d4df';ctx.font='14px system-ui';ctx.fillText(DIRECTIONS[dir],20+col*300,25+row*260);
    }
    ctx.fillStyle='#f4cf55';ctx.font='bold 19px system-ui';ctx.fillText('VETERAN · IK',327,352);
    ctx.fillStyle='#bfd1d9';ctx.font='14px system-ui';ctx.fillText('Same parts / continuous gait',322,383);
    ctx.fillText('24 frames · 0.96 seconds',333,409);
    ctx.fillText('Two alternating planted feet',326,435);
  }
  return options.encode===false?null:canvas.toDataURL('image/png');
}
function spriteSheet(cell=256,idle=false){
  const count=idle?1:24;
  const out=document.createElement('canvas');out.width=cell*count;out.height=cell*8;
  const g=out.getContext('2d'),ow=canvas.width,oh=canvas.height;
  canvas.width=cell;canvas.height=cell;
  for(let d=0;d<8;d++)for(let i=0;i<count;i++){
    ctx.clearRect(0,0,cell,cell);drawCharacter(d,i/24,cell/2,cell*220/256,1.25*cell/256,{shadow:false,idle});
    g.drawImage(canvas,i*cell,d*cell);
  }
  canvas.width=ow;canvas.height=oh;
  return out.toDataURL('image/png');
}
window.rig={render,spriteSheet,poseAt,settings:SETTINGS,ready:true};
let paused=false,t=0,last=performance.now();
$('pause').onclick=()=>{paused=!paused;$('pause').textContent=paused?'재생':'일시 정지';};
$('scrub').oninput=()=>{paused=true;t=Number($('scrub').value)/100*SETTINGS.cycle;$('pause').textContent='재생';};
function tick(now){if(!paused)t+=(now-last)/1000*Number($('speed').value);last=now;
  const phase=(t/SETTINGS.cycle)%1;
  if(!window.captureMode)render(phase,{bones:$('bones').checked,ground:$('ground').checked,encode:false});
  $('phase').textContent=`${Math.round(phase*100)}%`;
  if(!paused)$('scrub').value=Math.floor(phase*100);
  requestAnimationFrame(tick);
}requestAnimationFrame(tick);
