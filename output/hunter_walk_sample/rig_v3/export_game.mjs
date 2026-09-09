import {createRequire} from 'node:module';
import fs from 'node:fs';
const require=createRequire(process.env.RIG_NODE_MODULES+'/package.json');
const {chromium}=require('playwright');
const browser=await chromium.launch({headless:true,channel:'chrome'});
const page=await browser.newPage();
await page.goto('http://127.0.0.1:8765');await page.waitForFunction(()=>window.rig?.ready);
await page.evaluate(()=>window.captureMode=true);
const dest=new URL('../../../assets/characters/hunter/',import.meta.url);
fs.mkdirSync(dest,{recursive:true});
for(const [file,idle] of [['walk.png',false],['idle.png',true]]){
  const png=await page.evaluate(idle=>window.rig.spriteSheet(128,idle),idle);
  fs.writeFileSync(new URL(file,dest),Buffer.from(png.split(',')[1],'base64'));
}
await browser.close();console.log('Exported 3072x1024 walk and 128x1024 idle');
