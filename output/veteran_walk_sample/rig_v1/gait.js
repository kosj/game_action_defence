// A distance-driven periodic gait. Units are source-art pixels, seconds.
// Body coordinates: x = forward, y = lateral, z = up.
export const SETTINGS = {cycle: 0.96, stance: 0.6, reach: 13, lift: 10, hip: 57, bone: 26.5, ankle: 7};
export const DIRECTIONS = ['S','SW','W','NW','N','NE','E','SE'];
export const VECTORS = [[0,1],[-Math.SQRT1_2,Math.SQRT1_2],[-1,0],[-Math.SQRT1_2,-Math.SQRT1_2],[0,-1],[Math.SQRT1_2,-Math.SQRT1_2],[1,0],[Math.SQRT1_2,Math.SQRT1_2]];
export const wrap = p => ((p % 1) + 1) % 1;
export function footAt(phase) {
  const p = wrap(phase), {stance:s,reach:a,lift} = SETTINGS;
  if (p < s) return {x:a-2*a*p/s,z:0,contact:true};
  const u=(p-s)/(1-s), m=-2*a*(1-s)/s;
  const x=(2*u**3-3*u*u+1)*(-a)+(u**3-2*u*u+u)*m+(-2*u**3+3*u*u)*a+(u**3-u*u)*m;
  return {x,z:lift*Math.sin(Math.PI*u)**2,contact:false};
}
export function poseAt(phase, idle=false, halfStance=6) {
  const p=wrap(phase), bob=idle?0:-1.1*Math.cos(4*Math.PI*p);
  const legs=[0,1].map(i=>{
    const f=idle?{x:0,z:0,contact:true}:footAt(p+i*.5), lateral=i===0?-halfStance:halfStance;
    const hip={x:0,y:lateral,z:SETTINGS.hip+bob};
    const ankle={x:f.x,y:lateral,z:SETTINGS.ankle+f.z};
    const dx=ankle.x-hip.x,dz=ankle.z-hip.z,d=Math.hypot(dx,dz);
    if(d>2*SETTINGS.bone) throw new Error('IK target exceeds fixed leg length');
    const bend=Math.sqrt(SETTINGS.bone**2-d*d/4);
    const knee={x:(hip.x+ankle.x)/2-dz/d*bend,y:lateral,z:(hip.z+ankle.z)/2+dx/d*bend};
    return {hip,knee,ankle,foot:{x:f.x,y:lateral,z:f.z},contact:f.contact};
  });
  return {phase:p,bob,legs};
}
export function project(p,dir) {
  const [dx,dy]=VECTORS[dir];
  return {x:p.x*dx+p.y*dy,y:(p.x*dy-p.y*dx)*.42-p.z,depth:p.x*dy-p.y*dx};
}
