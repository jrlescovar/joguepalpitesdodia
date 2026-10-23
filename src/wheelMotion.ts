function prizeRotations(disc:HTMLElement){
 return Array.from(disc.querySelectorAll<HTMLElement>('.wheel-prize-rotation'));
}
export function setWheelAngle(disc:HTMLElement,angle:number){
 disc.style.transform=`rotate(${angle}deg)`;
 for(const artwork of prizeRotations(disc))artwork.style.transform=`rotate(${-angle}deg)`;
}
export function animateWheel(disc:HTMLElement,start:number,target:number){
 // The sectors and icon positions belong to this single rotating disc.
 // Only the artwork counter-rotates, around its own center, to stay upright.
 const options:KeyframeAnimationOptions={duration:4400,easing:'cubic-bezier(0.23, 1, 0.32, 1)',fill:'forwards'};
 const motion=disc.animate([{transform:`rotate(${start}deg)`},{transform:`rotate(${target}deg)`}],options);
 const icons=prizeRotations(disc).map(artwork=>artwork.animate([{transform:`rotate(${-start}deg)`},{transform:`rotate(${-target}deg)`}],options));
 const clock=disc.ownerDocument.timeline.currentTime;
 if(typeof clock==='number')for(const item of [motion,...icons])item.startTime=clock;
 return {motion,finish(){for(const icon of icons)icon.finish();motion.finish();},cancel(){motion.onfinish=null;motion.cancel();for(const icon of icons)icon.cancel();}};
}
