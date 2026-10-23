import CustomizationBoxIcon from './CustomizationBoxIcon';
import type { BoxTheme } from './types';

export default function ChestIcon({size=64,className,opening=false,halloween=false,graffiti=false,theme='classic'}:{size?:number;className?:string;opening?:boolean;halloween?:boolean;graffiti?:boolean;theme?:BoxTheme}) {
  return <CustomizationBoxIcon size={size} className={className} opening={opening}
    theme={halloween?'halloween':graffiti?'font':theme}/>;
}
