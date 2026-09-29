import type { PassNameStyle } from './types';

export const commonPassStyles = new Set<PassNameStyle>(['none','blood','purple','green','dark-blue','orange','pink']);

export const passStyleOptions: [PassNameStyle, string][] = [
  ['none', 'Normal'], ['blood', 'Red'],
  ['purple', 'Purple'], ['green', 'Green'], ['dark-blue', 'Blue'],
  ['orange', 'Orange'], ['pink', 'Pink'], ['sunset', 'Fade'],
  ['ember', 'Salmão'],
  ['rose-purple', 'Algodão'],
  ['green-gold', 'Braza'], ['lilac-silver', 'Prata Lilás'],
  ['ice-blue', 'Gelo'], ['navy-pink', 'Fade Alternativo'],
  ['royal-sapphire', 'Safira'], ['coral-lilac', 'Coral'],
  ['halloween-pumpkin', 'Abóbora Neon'],
  ['midnight-electric', 'Tempestade'],
  ['graphite-silver', 'Grafite'],
  ['wine-rose', 'Vinho'],
  ['neon-circuit', 'Camaleão'],
  ['sunset-ocean', 'Pôr do sol'],
  ['rare-plum-beige', 'Ameixa'],
  ['halloween-bloodmoon', 'Lua Sangrenta'],
  ['myth-petroleum-bronze', 'Petróleo'],
  ['myth-burgundy-sand', 'Bordô'],
  ['myth-cerulean-rust', 'Ferrugem'],
  ['myth-plum-copper', 'Cobre Rosado'],
  ['myth-jade-mauve', 'Jade'],
  ['myth-olive-rose-graphite', 'Oliva'],
  ['myth-fuchsia-petroleum', 'Fúscia'],
  ['halloween-mist', 'Névoa Roxa'],
  ['gold', 'Gold'], ['rainbow', 'Arco-íris'],
  ['legend-nebula', 'Nebulosa'], ['legend-abyss', 'Abismo'],
  ['legend-prism', 'Prisma'], ['legend-solar', 'Solar'],
  ['legend-ruby-eclipse', 'Eclipse Rubro'],
];
