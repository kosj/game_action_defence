import assert from 'node:assert/strict';
import fs from 'node:fs';
import {footAt,poseAt,SETTINGS} from './gait.js';
let maxLengthError=0,maxSlip=0,minLift=Infinity;
for(let i=0;i<2000;i++){
  const t=i/2000,p=poseAt(t);
  assert(p.legs.some(l=>l.contact),'Both feet airborne');
  for(const l of p.legs){
    for(const [a,b] of [[l.hip,l.knee],[l.knee,l.ankle]]){
      const e=Math.abs(Math.hypot(a.x-b.x,a.z-b.z)-SETTINGS.bone);
      maxLengthError=Math.max(maxLengthError,e);assert(e<1e-10);
    }
    minLift=Math.min(minLift,l.foot.z);assert(l.foot.z>=0);
  }
  if(t>1e-4&&t<SETTINGS.stance-1e-4){
    const velocity=(footAt(t+1e-5).x-footAt(t-1e-5).x)/2e-5;
    maxSlip=Math.max(maxSlip,Math.abs(velocity+2*SETTINGS.reach/SETTINGS.stance));
  }
}
assert.deepEqual(poseAt(0),poseAt(1),'Loop endpoints differ');
const eps=1e-6;
for(const boundary of [0,SETTINGS.stance]){
  const c=footAt(boundary),left=footAt(boundary-eps),right=footAt(boundary+eps);
  for(const k of ['x','z'])assert(Math.abs((c[k]-left[k])/eps-(right[k]-c[k])/eps)<.02,'Velocity discontinuity');
}
const report={samples:2000,loopPositionExact:true,loopAndLiftoffVelocityContinuous:true,
  atLeastOneFootGrounded:true,fixedBoneLengthMaxError:maxLengthError,stanceVelocityError:maxSlip,minimumFootHeight:minLift};
fs.writeFileSync(new URL('verification.json',import.meta.url),JSON.stringify(report,null,2));
console.log(report);
