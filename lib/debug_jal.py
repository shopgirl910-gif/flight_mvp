# debug_jal3.py
from bs4 import BeautifulSoup

with open("debug_html2.html", "r", encoding="utf-8") as f:
    html = f.read()

soup = BeautifulSoup(html, 'html.parser')
tables = soup.find_all('table')

print(f"テーブル数: {len(tables)}")

for i, table in enumerate(tables):
    rows = table.find_all('tr')
    if len(rows) > 1:  # 2行以上あるテーブルのみ
        print(f"\n=== テーブル{i}: {len(rows)}行 ===")
        for j, row in enumerate(rows[:3]):  # 最初の3行
            cells = row.find_all(['td', 'th'])
            cell_texts = [c.get_text(strip=True)[:20] for c in cells]
            print(f"  行{j}: {cell_texts}")