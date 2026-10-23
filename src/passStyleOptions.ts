import type { PassNameStyle } from './types';
import { ownerStyleVariants } from './ownerStyleVariants';

export const commonPassStyles = new Set<PassNameStyle>(['none','purple','green','dark-blue','ember','green-gold']);

export const creatorStyleOptions: [PassNameStyle, string][] = [
  ['none', 'Normal'],
  ['purple', 'Purple'], ['green', 'Green'], ['dark-blue', 'Blue'],
  ['pink', 'Pink'], ['sunset', 'Fade'],
  ['ember', 'Salmão'],
  ['green-gold', 'Braza'], ['lilac-silver', 'Prata Lilás'],
  ['ice-blue', 'Gelo'], ['navy-pink', 'Fade Alternativo'],
  ['royal-sapphire', 'Safira'], ['coral-lilac', 'Coral'],
  ['midnight-electric', 'Tempestade'],
  ['graphite-silver', 'Grafite'],
  ['wine-rose', 'Vinho'],
  ['neon-circuit', 'Camaleão'],
  ['sunset-ocean', 'Pôr do sol'],
  ['rare-plum-beige', 'Ameixa'],
  ['halloween-pumpkin', 'Abóbora Neon'],
  ['myth-petroleum-bronze', 'Petróleo'],
  ['myth-burgundy-sand', 'Bordô'],
  ['myth-cerulean-rust', 'Ferrugem'],
  ['myth-jade-mauve', 'Jade'],
  ['myth-olive-rose-graphite', 'Oliva'],
  ['myth-fuchsia-petroleum', 'Fúscia'],
  ...ownerStyleVariants.filter(([style])=>style==='lab-blue-10-jade-sky').map(([style,label]):[PassNameStyle,string]=>[style,label]),
  ['halloween-semaforo', 'Semáforo'],
  ['halloween-bloodmoon', 'Lua Sangrenta'],
  ['halloween-mist', 'Névoa Roxa'],
  ['halloween-cleopatra', 'Cleópatra'], ['halloween-clown', 'Clown'], ['gold', 'Gold'], ['rainbow', 'Arco-íris'],
  ['legend-kryptonite', 'Criptônita'],
  ['legend-sky-blue', 'Sky Blue'],
  ['legend-blood-wave', 'Blood Wave'],
  ['myth-orizonte', 'Orizonte'],
  ['myth-barbie', 'Barbie'],
  ['legend-nebula', 'Nebulosa'], ['legend-abyss', 'Abismo'],
  ['legend-prism', 'Prisma'], ['legend-solar', 'Solar'],
  ['legend-ruby-eclipse', 'Eclipse Rubro'],
  ['legend-arcane-twilight', 'Crepúsculo'],
  ['legend-lunar-prism', 'Prisma Lunar'],
  ['lab-blue-9', 'Órbita Azul'],
  ['lab-blue-6', 'Luz de Alma'],
  ['lab-blue-4', 'Azul 4'],
  ['lab-blue-7', 'Azul 7'],
  ['lab-blue-10', 'Azul 10'],
  ...ownerStyleVariants.filter(([style])=>style!=='lab-blue-10-jade-sky').map(([style,label]):[PassNameStyle,string]=>[style,label]),
];

// Private effect templates are only available inside the admin creator.
export const passStyleOptions=creatorStyleOptions.filter(([style])=>!style.startsWith("lab-blue-")||["lab-blue-6","lab-blue-9","lab-blue-9-red-orbit","lab-blue-9-green-orbit","lab-blue-10-jade-sky"].includes(style));
