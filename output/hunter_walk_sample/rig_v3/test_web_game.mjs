import {createRequire} from 'node:module';
import fs from 'node:fs';
const require=createRequire(process.env.RIG_NODE_MODULES+'/package.json');
const {chromium}=require('playwright');
const browser=await chromium.launch({headless:true,channel:'chrome'});
const page=await browser.newPage();const logs=[];
page.on('console',m=>logs.push(m.text()));page.on('pageerror',e=>logs.push(String(e)));
await page.goto('http://127.0.0.1:8765/game_test.html');
try{
  await page.waitForFunction(()=>{const status=document.querySelector('#status');return !status||getComputedStyle(status).visibility==='hidden';},{},{timeout:60000});
  await page.waitForTimeout(2000);
  if(logs.some(x=>/SCRIPT ERROR|Failed to load|Parse Error|Aborting/.test(x)))throw new Error('Web load error');
  await page.screenshot({path:new URL('web_game.png',import.meta.url).pathname.replace(/^\/(.:)/,'$1')});
  console.log('WEB GAME LOAD: PASS');
}finally{
  fs.writeFileSync(new URL('web_runtime.log',import.meta.url),logs.join('\n'));
  await browser.close();
}
