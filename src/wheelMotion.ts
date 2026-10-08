function prizeOrbits(disc:HTMLElement){
  return Array.from(disc.parentElement?.querySelectorAll<HTMLElement>('.wheel-segment')??[]).map(icon=>{
    const middle=Number(icon.dataset.wheelMiddle)*Math.PI/180;
    return {icon,x:disc.clientWidth*.36*Math.sin(middle),y:-disc.clientHeight*.36*Math.cos(middle)};
  });
}

function orbitTransform(angle:number,x:number,y:number){
  // Both rotations belong to the same transform, so they always cancel.
  // Only the position travels around the wheel; the artwork remains upright.
  return `translate(-50%,-50%) translate(${-x}px,${-y}px) rotate(${angle}deg) translate(${x}px,${y}px) rotate(${-angle}deg)`;
}

export function setWheelAngle(disc:HTMLElement,angle:number){
  disc.style.transform=`rotate(${angle}deg)`;
  for(const {icon,x,y} of prizeOrbits(disc))icon.style.transform=orbitTransform(angle,x,y);
}

export function animateWheel(disc:HTMLElement,start:number,target:number){
  const options:KeyframeAnimationOptions={duration:4400,easing:'cubic-bezier(0.23, 1, 0.32, 1)',fill:'forwards'};
  const motion=disc.animate([{transform:`rotate(${start}deg)`},{transform:`rotate(${target}deg)`}],options);
  // Icons are siblings of the rotating disc. Each single animation moves its
  // orbit without inheriting an independently composited parent rotation.
  const orbits=prizeOrbits(disc).map(({icon,x,y})=>icon.animate([{transform:orbitTransform(start,x,y)},{transform:orbitTransform(target,x,y)}],options));
  const clock=disc.ownerDocument.timeline.currentTime;
  if(typeof clock==='number')for(const item of [motion,...orbits])item.startTime=clock;
  return {
    motion,
    finish(){for(const orbit of orbits)orbit.finish();motion.finish();},
    cancel(){motion.onfinish=null;motion.cancel();for(const orbit of orbits)orbit.cancel();},
  };
}
