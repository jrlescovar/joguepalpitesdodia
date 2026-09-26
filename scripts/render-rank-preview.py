from pathlib import Path
import html
import re

source = Path('src/RankEmblem.tsx').read_text(encoding='utf-8')
tiers = [
    ('bronze', 'Bronze', '0–99', '#d39262'),
    ('silver', 'Prata', '100–149', '#d9e5f3'),
    ('gold', 'Ouro', '150–299', '#ffd46c'),
    ('platinum', 'Platina', '300–499', '#a2e4d8'),
    ('diamond', 'Diamante', '500–749', '#bc83ff'),
    ('legendary', 'Lendário', '750–999', '#fb5968'),
    ('master', 'Mestre', '1000+', '#ffd77a'),
]
parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1120 610" width="1120" height="610">',
         '<rect width="1120" height="610" fill="#12161d"/>',
         '<text x="560" y="48" text-anchor="middle" fill="#f3f5f8" font-family="Arial,sans-serif" font-size="27" font-weight="700">Emblemas do Ranking Global</text>']
for index, (key, name, interval, color) in enumerate(tiers):
    match = re.search(r"\{tier\.key === '" + key + r"' && <>(.*?)</>\}", source, re.S)
    assert match, key
    x = 24 + (index % 4) * 274
    y = 80 + (index // 4) * 256
    parts.append(f'<g transform="translate({x} {y})"><rect width="250" height="230" rx="20" fill="#1d222b" stroke="#46505f"/>')
    parts.append(f'<svg x="77" y="27" width="96" height="96" viewBox="0 0 64 64" style="color:{color}">')
    for class_name, d in re.findall(r'<path className="([^"]+)" d="([^"]+)"\s*/>', match.group(1)):
        attributes = f'd="{html.escape(d)}"'
        if class_name == 'rank-ghost':
            attributes += ' fill="currentColor" opacity=".14"'
        elif class_name == 'rank-fill':
            attributes += ' fill="currentColor"'
        else:
            width = '1.5' if class_name == 'rank-thin' else '2.4'
            attributes += f' fill="none" stroke="currentColor" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"'
            if 'rank-master-border' in class_name:
                attributes = attributes.replace('stroke="currentColor"', 'stroke="#f3f5f8"')
        parts.append(f'<path {attributes}/>')
    parts.append('</svg>')
    parts.append(f'<text x="125" y="159" text-anchor="middle" fill="#f3f5f8" font-family="Arial,sans-serif" font-size="20" font-weight="700">{name}</text>')
    parts.append(f'<text x="125" y="188" text-anchor="middle" fill="#aeb9ca" font-family="Arial,sans-serif" font-size="15">{interval} pontos</text></g>')
parts.append('</svg>')
Path('docs/emblemas-ranking.svg').write_text('\n'.join(parts), encoding='utf-8')
