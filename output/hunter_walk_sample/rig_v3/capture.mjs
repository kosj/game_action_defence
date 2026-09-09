import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
const require=createRequire(process.env.RIG_NODE_MODULES+'/package.json');
const {chromium}=require('playwright');
const browser=await chromium.launch({headless:true,channel:'chrome'});
const page=await browser.newPage({viewport:{width:1050,height:1100}});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
await page.goto('http://127.0.0.1:8765');
await page.waitForFunction(()=>window.rig?.ready);
await page.evaluate(()=>window.captureMode=true);
const root=path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/,'$1'));
fs.mkdirSync(path.join(root,'frames'),{recursive:true});
const sheet=await page.evaluate(()=>window.rig.spriteSheet());
fs.writeFileSync(path.join(root,'hunter_walk_24x8.png'),Buffer.from(sheet.split(',')[1],'base64'));
for(let i=0;i<24;i++){
  for(const type of ['overview','east','bones']){
    const png=await page.evaluate(({phase,type})=>window.rig.render(phase,
      {direction:type==='overview'?'all':'E',bones:type==='bones',ground:true}),{phase:i/24,type});
    fs.writeFileSync(path.join(root,'frames',`${type}_${String(i).padStart(2,'0')}.png`),Buffer.from(png.split(',')[1],'base64'));
  }
}
await page.evaluate(()=>window.rig.render(0,{ground:true,bones:false}));
await page.screenshot({path:path.join(root,'review.png'),fullPage:true});
if(errors.length)throw new Error(errors.join('\n'));
console.log('Captured 24 frames each: overview, east, bones. No browser errors.');
await browser.close();
