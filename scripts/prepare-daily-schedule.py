"""Prepare and validate a daily schedule from verified fixture data; never writes to DB.

Usage: python scripts/prepare-daily-schedule.py FIXTURES_JSON OUTPUT_DIR
Busy days use six fixtures (2+2+2+2+1+1). A documented focus is an explicit exception.
"""
import csv
import json
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

BRASILIA = timezone(timedelta(hours=-3))
BUSY_WEEKDAYS = {1, 2, 3, 5, 6}
SIX_FIXTURE_ALLOCATION = [0, 1, 2, 3, 4, 3, 1, 0, 2, 5]
# Seven different markets for a focused match, plus three other fixtures.
FOCUS_ALLOCATION = [0, 0, 0, 0, 0, 1, 2, 0, 3, 0]
NAMES = {
    'Bayern Munich': 'Bayern de Munique', 'FC Augsburg': 'Augsburg',
    'AS Roma': 'Roma', 'AC Milan': 'Milan', 'Paris Saint-Germain': 'PSG',
    'Atlético Madrid': 'Atlético de Madrid', 'Instituto (Córdoba)': 'Instituto',
    'PSV Eindhoven': 'PSV', 'TSG Hoffenheim': 'Hoffenheim',
    'RB Salzburg': 'Salzburg', 'Lech Poznan': 'Lech Poznań',
    'Internazionale': 'Inter de Milão', 'Viking FK': 'Viking',
    'LASK Linz': 'LASK', 'Fenerbahce': 'Fenerbahçe', 'FC Cologne': 'Colônia',
    'Estudiantes de La Plata': 'Estudiantes de La Plata',
    'Talleres (Córdoba)': 'Talleres', 'Deportivo': 'Deportivo La Coruña',
    'Bodo/Glimt': 'Bodø/Glimt', 'FC Porto': 'Porto', 'VfB Stuttgart': 'Stuttgart',
    'Feyenoord Rotterdam': 'Feyenoord', 'Stade Rennais': 'Rennes',
    'Borussia Mönchengladbach': 'Borussia Mönchengladbach',
    'Vitória de Guimaraes': 'Vitória de Guimarães',
}
LEAGUES = {
    'ger.1': 'Bundesliga', 'eng.1': 'Premier League', 'fra.1': 'Ligue 1',
    'ned.1': 'Eredivisie', 'esp.1': 'La Liga', 'ita.1': 'Serie A',
    'arg.1': 'Campeonato Argentino', 'bra.1': 'Brasileirão',
    'por.1': 'Campeonato Português', 'uefa.champions': 'Liga dos Campeões',
    'uefa.europa': 'Europa League', 'uefa.europa.conf': 'Conference League',
    'conmebol.libertadores': 'Copa Libertadores',
    'conmebol.sudamericana': 'Copa Sul-Americana',
}
MARKETS = [
    ('Partida Clássica — Quem vence?', 'Resultado nos 90 minutos e acréscimos. X significa empate no placar.'),
    ('Duelo de Finalizações?', 'Vence o time com mais finalizações totais nos 90 minutos e acréscimos. X significa totais iguais.'),
    ('Duelo de Chutes ao Gol?', 'Vence o time com mais chutes ao gol nos 90 minutos e acréscimos. X significa totais iguais.'),
    ('Duelo de Cartões?', 'Vence o time com mais cartões amarelos e vermelhos, conforme as estatísticas do Sofascore, nos 90 minutos e acréscimos. X significa totais iguais.'),
    ('Duelo de Impedimentos?', 'Vence o time com mais impedimentos nos 90 minutos e acréscimos. X significa totais iguais.'),
    ('Primeiro a 7 Finalizações?', 'Vence o primeiro time a atingir 7 finalizações totais. Nenhum vence se nenhum dos times atingir 7 até o fim dos 90 minutos e acréscimos.'),
    ('Primeiro a 5 Escanteios?', 'Vence o primeiro time a atingir 5 escanteios. Nenhum vence se nenhum dos times atingir 5 até o fim dos 90 minutos e acréscimos.'),
    ('Ambos os times marcam?', 'Sim vence se os dois times marcarem pelo menos um gol nos 90 minutos e acréscimos. Gols contra contam para o placar. Não vence se pelo menos um time terminar sem marcar.'),
    ('Duelo de Faltas Cometidas?', 'Vence o time com mais faltas cometidas nos 90 minutos e acréscimos. X significa totais iguais.'),
    ('Goleiro — Total de Defesas?', 'Total de defesas dos goleiros do visitante nos 90 minutos e acréscimos, incluindo eventual substituição.'),
]
POINTS = [[40, 60, 50], [40, 60, 70], [30, 100, 60], [20, 40, 20],
          [40, 80, 40], [30, 360, 50], [30, 60, 90], [45, 45],
          [30, 60, 30], [50, 36, 76]]


def prepare(document):
    rows = []
    dates = set()
    for day in document['days']:
        day_id = day['dayId']
        assert day_id not in dates, 'Duplicate day'
        dates.add(day_id)
        date = datetime.fromisoformat(day_id).date()
        fixtures = day['fixtures']
        assert len({f['id'] for f in fixtures}) == len(fixtures), 'Duplicate fixture'
        if day.get('focusFixtureId'):
            assert day['focusCount'] == 7 and len(fixtures) == 4
            assert fixtures[0]['id'] == day['focusFixtureId']
            allocation = FOCUS_ALLOCATION
        else:
            # Use six whenever enough games exist, including Mondays/Fridays.
            assert len(fixtures) == 6, 'A regular schedule requires six fixtures'
            allocation = SIX_FIXTURE_ALLOCATION
        counts = Counter(allocation)
        assert sorted(counts.values()) == ([1, 1, 1, 7] if day.get('focusFixtureId') else [1, 1, 2, 2, 2, 2])
        if date.weekday() in BUSY_WEEKDAYS and not day.get('focusFixtureId'):
            assert len(counts) == 6 and max(counts.values()) == 2
        for slot, fixture_index in enumerate(allocation):
            fixture = fixtures[fixture_index]
            assert fixture['timeConfirmed'], 'Kickoff time not confirmed'
            assert fixture['source'].startswith('https://site.api.espn.com/'), 'Missing fixture source'
            kickoff = datetime.fromisoformat(fixture['kickoff'].replace('Z', '+00:00'))
            assert kickoff.utcoffset() is not None
            closes = (kickoff - timedelta(minutes=10)).astimezone(BRASILIA)
            assert closes.date() == date, 'Fixture must belong to the day in Brasilia'
            home, away = [NAMES.get(fixture[k], fixture[k]) for k in ('home', 'away')]
            title, rule = MARKETS[slot]
            labels = [home, 'X', away]
            if slot in (5, 6):
                labels = [home, 'Nenhum', away]
            if slot == 7:
                labels = ['Sim', 'Não']
            if slot == 9:
                labels = ['0-2', '3-5', '6+']
                title = f'Goleiro do {away} — Total de Defesas?'
            title += f' ({home} x {away})'
            assert len(title) <= 120 and len(labels) == len(POINTS[slot])
            rows.append({'dayId': day_id, 'slot': slot, 'title': title,
                         'description': LEAGUES[fixture['league']] + ' · ' + rule,
                         'options': labels, 'rankPoints': POINTS[slot],
                         'closesAt': closes.isoformat(), 'kickoff': kickoff.isoformat(),
                         'fixtureId': fixture['id'], 'source': fixture['source']})
    return rows


def main():
    source, output = Path(sys.argv[1]), Path(sys.argv[2])
    rows = prepare(json.loads(source.read_text(encoding='utf-8-sig')))
    output.mkdir(parents=True, exist_ok=True)
    (output / 'schedule.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with (output / 'schedule.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['Data', 'Slot', 'Palpite', 'Fecha (Brasília)', 'Opções', 'Pontos', 'Fonte'])
        writer.writerows([[r['dayId'], r['slot'], r['title'], r['closesAt'], ' / '.join(r['options']),
                          ' / '.join(map(str, r['rankPoints'])), r['source']] for r in rows])
    print(f'{len(rows)} palpites validados; nenhuma alteração no banco executada.')


if __name__ == '__main__':
    main()
