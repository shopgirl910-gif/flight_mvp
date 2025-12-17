from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import os

# JTA路線（PDFより）
jta_routes = [
    ('HND', 'MMY'),  # 羽田=宮古
    ('HND', 'ISG'),  # 羽田=石垣
    ('NGO', 'OKA'),  # 中部=那覇
    ('NGO', 'ISG'),  # 中部=石垣
    ('NGO', 'MMY'),  # 中部=宮古
    ('FUK', 'OKA'),  # 福岡=那覇
    ('OKA', 'MMY'),  # 那覇=宮古
    ('OKA', 'ISG'),  # 那覇=石垣
    ('OKA', 'OGN'),  # 那覇=与那国
    ('OKA', 'RNJ'),  # 那覇=与論
    ('MMY', 'ISG'),  # 宮古=石垣
    ('ISG', 'OGN'),  # 石垣=与那国
]

# RAC路線（路線図より）
rac_routes = [
    ('OKA', 'UEO'),  # 那覇=久米島
    ('OKA', 'KTD'),  # 那覇=北大東
    ('OKA', 'MMD'),  # 那覇=南大東
    ('MMY', 'TRA'),  # 宮古=多良間
    ('KTD', 'MMD'),  # 北大東=南大東
]

# 結合（重複除去）
all_routes = list(set(jta_routes + rac_routes))

months = [
    "20251026_20260105",
    "20260106_20260228",
    "20260301_20260328"
]

csv_file = 'jal_all_routes.csv'

# ダウンロード済みを読み込む
downloaded = set()
if os.path.exists(csv_file):
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            downloaded.add((row['departure'], row['arrival'], row['period']))
    print(f"ダウンロード済み: {len(downloaded)}組み合わせ")

def get_jal_timetable_both_directions(dep, arr, month, browser):
    """1回のアクセスで往復両方向を取得"""
    url = f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep}&arrival={arr}&month={month}"
    
    for attempt in range(3):
        try:
            page = browser.new_page()
            page.goto(url, timeout=60000)
            page.wait_for_timeout(5000)
            html = page.content()
            page.close()
            
            soup = BeautifulSoup(html, 'html.parser')
            
            sections = soup.find_all('div', class_='timetable-result__table')
            
            results = {
                'forward': [],
                'reverse': []
            }
            
            if len(sections) == 0:
                tables = soup.find_all('table')
                if len(tables) >= 1:
                    sections = [tables[0]]
                if len(tables) >= 2:
                    sections.append(tables[1])
            
            for idx, section in enumerate(sections):
                if idx == 0:
                    direction = 'forward'
                    departure = dep
                    arrival = arr
                else:
                    direction = 'reverse'
                    departure = arr
                    arrival = dep
                
                tables = section.find_all('table') if section.name != 'table' else [section]
                
                for table in tables:
                    rows = table.find_all('tr')
                    for row in rows:
                        cells = row.find_all('td')
                        if len(cells) >= 3:
                            flight_text = cells[0].get_text(strip=True)
                            # JAL, JTA, JAC, RAC全てを取得
                            if flight_text.startswith(('JAL', 'JTA', 'JAC', 'RAC')):
                                results[direction].append({
                                    'departure': departure,
                                    'arrival': arrival,
                                    'flight_number': flight_text,
                                    'departure_time': cells[1].get_text(strip=True),
                                    'arrival_time': cells[2].get_text(strip=True),
                                    'remarks': cells[3].get_text(strip=True) if len(cells) > 3 else '',
                                    'period': month
                                })
            
            return results
            
        except Exception as e:
            print(f"  エラー: {e}")
            try:
                page.close()
            except:
                pass
            if attempt < 2:
                time.sleep(5)
    
    return {'forward': [], 'reverse': []}

# 取得対象を計算
to_fetch_pairs = []
for dep, arr in all_routes:
    needs_fetch = False
    for month in months:
        fwd_key = (dep, arr, month)
        rev_key = (arr, dep, month)
        if fwd_key not in downloaded or rev_key not in downloaded:
            needs_fetch = True
            break
    if needs_fetch:
        to_fetch_pairs.append((dep, arr))

print(f"\n[JTA/RAC路線取得]")
print(f"  JTA路線: {len(jta_routes)}ペア")
print(f"  RAC路線: {len(rac_routes)}ペア")
print(f"  合計（重複除去）: {len(all_routes)}ペア")
print(f"  取得対象: {len(to_fetch_pairs)}ペア")

if len(to_fetch_pairs) == 0:
    print("\n取得対象がありません。完了！")
    exit()

# CSVファイル準備
file_exists = os.path.exists(csv_file) and os.path.getsize(csv_file) > 0

with open(csv_file, 'a', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=['departure', 'arrival', 'flight_number', 'departure_time', 'arrival_time', 'remarks', 'period'])
    
    if not file_exists:
        writer.writeheader()
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        
        saved = 0
        
        for i, (dep, arr) in enumerate(to_fetch_pairs):
            print(f"\n[{i+1}/{len(to_fetch_pairs)}] {dep} ⇔ {arr}")
            
            for month in months:
                fwd_key = (dep, arr, month)
                rev_key = (arr, dep, month)
                
                if fwd_key in downloaded and rev_key in downloaded:
                    print(f"  {month} スキップ（両方向ダウンロード済み）")
                    continue
                
                print(f"  {month} 取得中...")
                results = get_jal_timetable_both_directions(dep, arr, month, browser)
                
                # 往路を保存
                if fwd_key not in downloaded:
                    if len(results['forward']) > 0:
                        writer.writerows(results['forward'])
                        saved += len(results['forward'])
                        print(f"    {dep}→{arr}: {len(results['forward'])}便")
                    else:
                        print(f"    {dep}→{arr}: 便なし")
                    downloaded.add(fwd_key)
                
                # 復路を保存
                if rev_key not in downloaded:
                    if len(results['reverse']) > 0:
                        writer.writerows(results['reverse'])
                        saved += len(results['reverse'])
                        print(f"    {arr}→{dep}: {len(results['reverse'])}便")
                    else:
                        print(f"    {arr}→{dep}: 便なし")
                    downloaded.add(rev_key)
                
                f.flush()
                time.sleep(random.uniform(3, 5))
        
        browser.close()

print(f"\n完了!")
print(f"新規保存: {saved}便")
