// Keep a requested page selected while smooth scrolling crosses other cards.
export class CarouselIndicator {
  private target:number|null=null;
  select(page:number){this.target=page;}
  cancel(){this.target=null;}
  read(left:number,offsets:number[]){
    let nearest=0;let distance=Infinity;
    offsets.forEach((offset,page)=>{
      const delta=Math.abs(left-offset);
      if(delta<distance){nearest=page;distance=delta;}
    });
    if(this.target!==null){
      const offset=offsets[this.target];
      if(offset!==undefined&&Math.abs(left-offset)>2)return this.target;
      this.target=null;
    }
    return nearest;
  }
}
