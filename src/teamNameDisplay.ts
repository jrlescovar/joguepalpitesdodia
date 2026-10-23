export const teamNameDisplay = (text: string) => text
  .replace(/\bBayern\s+de\s+Munique\b/gi, 'Bayern')
  .replace(/\bParis\s+Saint(?:\s*-\s*|\s+)Germain\b/gi, 'PSG');
