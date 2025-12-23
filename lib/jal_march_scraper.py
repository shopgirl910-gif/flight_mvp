"""
JAL国内線時刻表スクレイピング（3月ダイヤ専用・修正版）
- 往復重複バグ修正済み
- コードシェア便も取得
- 出力: jal_march_schedules.csv

使用方法:
1. pip install playwright beautifulsoup4
2. playwright install chromium
3. python jal_march_scraper.py
"""

from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import re
import os

# 出力ファイル
OUTPUT_FILE = 'jal_march_schedules.csv'

# 3月ダイヤのみ
PERIOD = '20260301_20260328'
PERIOD_START = '2026-03-01'
PERIOD_END = '2026-03-28'

# JAL国内線就航空港コード
AIRPORTS = [
    'HND', 'NRT',  # 東京
    'ITM', 'KIX',  # 大阪
    'CTS', 'OKD',  # 札幌
    'NGO', 'NKM',  # 名古屋
    'FUK',  # 福岡
    'OKA',  # 沖縄
    'NGS', 'KMJ', 'OIT', 'MYJ', 'HIJ', 'TAK', 'KCZ', 'TKS', 'KOJ',
    'SDJ', 'AOJ', 'AKJ', 'AXT', 'GAJ',
    'MMB', 'OBO', 'KUH', 'HKD',
    'ISG', 'MMY', 'UBJ', 'IWK',
    'OKJ', 'TTJ', 'YGJ', 'IZO',
    'HSG', 'KMI',
    'ASJ', 'TKN', 'FKS', 'HNA', 'MSJ', 'ONJ', 'SHM',
    'NTQ', 'KKJ', 'TNE', 'KUM', 'RNJ', 'OGN', 'HAC',
    'MBE', 'SHB', 'WKJ', 'OIR',
    'IKI', 'TSJ', 'FUJ', 'MMJ', 'AXJ', 'KKX',
    'FSZ', 'KIJ', 'SYO', 'TOY', 'KMQ',
]

# 空港コード→名前マッピング（ページ解析用）
AIRPORT_NAMES_TO_CODE = {
    '東京(羽田)': 'HND', '羽田': 'HND',
    '東京(成田)': 'NRT', '成田': 'NRT',
    '大阪(関西)': 'KIX', '関西': 'KIX',
    '大阪(伊丹)': 'ITM', '伊丹': 'ITM',
    '大阪(神戸)': 'UKB', '神戸': 'UKB',
    '名古屋(中部)': 'NGO', '中部': 'NGO',
    '名古屋(小牧)': 'NKM', '小牧': 'NKM',
    '札幌(新千歳)': 'CTS', '新千歳': 'CTS',
    '札幌(丘珠)': 'OKD', '丘珠': 'OKD',
    '福岡': 'FUK',
    '沖縄(那覇)': 'OKA', '那覇': 'OKA',
    '長崎': 'NGS', '熊本': 'KMJ', '大分': 'OIT', '松山': 'MYJ',
    '広島': 'HIJ', '高松': 'TAK', '高知': 'KCZ', '徳島': 'TKS',
    '鹿児島': 'KOJ', '仙台': 'SDJ', '青森': 'AOJ', '旭川': 'AKJ',
    '秋田': 'AXT', '山形': 'GAJ', '女満別': 'MMB', '帯広': 'OBO',
    '釧路': 'KUH', '函館': 'HKD', '石垣': 'ISG', '宮古': 'MMY',
    '山口宇部': 'UBJ', '岩国': 'IWK', '岡山': 'OKJ', '鳥取': 'TTJ',
    '米子': 'YGJ', '出雲': 'IZO', '佐賀': 'HSG', '宮崎': 'KMI',
    '奄美': 'ASJ', '奄美大島': 'ASJ', '徳之島': 'TKN', '福島': 'FKS',
    '花巻': 'HNA', '三沢': 'MSJ', '大館能代': 'ONJ', '南紀白浜': 'SHM',
    '能登': 'NTQ', '北九州': 'KKJ', '種子島': 'TNE', '屋久島': 'KUM',
    '与論': 'RNJ', '与那国': 'OGN', '八丈島': 'HAC',
    '紋別': 'MBE', '中標津': 'SHB', '稚内': 'WKJ', '奥尻': 'OIR',
    '壱岐': 'IKI', '対馬': 'TSJ', '五島福江': 'FUJ', '松本': 'MMJ',
    '天草': 'AXJ', '喜界': 'KKX', '静岡': 'FSZ', '新潟': 'KIJ',
    '庄内': 'SYO', '富山': 'TOY', '小松': 'KMQ', '隠岐': 'OKI',
    '沖永良部': 'OKE', '久米島': 'UEO', '北大東': 'KTD', '南大東': 'MMD',
    '多良間': 'TRA', '利尻': 'RIS',
}


def parse_direction_from_header(soup):
    """ページ内のヘッダーから出発地・到着地を取得"""
    directions = []
    
    # 「○○ → △△」形式のヘッダーを探す
    headers = soup.find_all(['h2', 'h3', 'h4', 'div', 'p'])
    
    for header in headers:
        text = header.get_text(strip=True)
        # 「出発地 → 到着地」パターンを探す
        match = re.search(r'(.+?)\s*[→⇒]\s*(.+?)(?:\s|$|区間)', text)
        if match:
            dep_name = match.group(1).strip()
            arr_name = match.group(2).strip()
            
            # 空港名をコードに変換
            dep_code = None
            arr_code = None
            
            for name, code in AIRPORT_NAMES_TO_CODE.items():
                if name in dep_name:
                    dep_code = code
                    break
            
            for name, code in AIRPORT_NAMES_TO_CODE.items():
                if name in arr_name:
                    arr_code = code
                    break
            
            if dep_code and arr_code:
                directions.append((dep_code, arr_code))
    
    return directions


def get_jal_timetable(dep, arr, browser):
    """JAL時刻表ページをスクレイピング"""
    url = f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep}&arrival={arr}&month={PERIOD}"
    
    for attempt in range(3):
        try:
            page = browser.new_page()
            page.goto(url, timeout=60000)
            page.wait_for_timeout(5000)
            html = page.content()
            page.close()
            
            soup = BeautifulSoup(html, 'html.parser')
            
            # ページ内の方向を解析
            directions = parse_direction_from_header(soup)
            
            # 時刻表テーブルを探す
            tables = soup.find_all('table')
            timetable_tables = []
            
            for table in tables:
                rows = table.find_all('tr')
                for row in rows:
                    cells = row.find_all(['td', 'th'])
                    if cells:
                        first_cell_text = cells[0].get_text(strip=True)
                        if re.search(r'(JAL|JTA|JAC|RAC|HAC|FDA)\s*\d+', first_cell_text):
                            timetable_tables.append(table)
                            break
            
            flights = []
            
            for table_idx, table in enumerate(timetable_tables[:2]):
                # 方向を決定（ヘッダーから取得、なければURL順）
                if table_idx < len(directions):
                    current_dep, current_arr = directions[table_idx]
                elif table_idx == 0:
                    current_dep, current_arr = dep, arr
                else:
                    current_dep, current_arr = arr, dep
                
                rows = table.find_all('tr')
                
                for row in rows:
                    cells = row.find_all(['td', 'th'])
                    if len(cells) < 3:
                        continue
                    
                    first_cell_text = cells[0].get_text(strip=True)
                    
                    # JAL便名を探す（JAL, JTA, JAC, RAC, HAC, FDA）
                    flight_match = re.search(r'(JAL|JTA|JAC|RAC|HAC|FDA)\s*(\d+)', first_cell_text)
                    
                    if flight_match:
                        airline_prefix = flight_match.group(1)
                        flight_number = flight_match.group(2)
                        
                        # 時刻を取得
                        dep_time = cells[1].get_text(strip=True) if len(cells) > 1 else ''
                        arr_time = cells[2].get_text(strip=True) if len(cells) > 2 else ''
                        
                        # 時刻形式の検証
                        dep_time_match = re.search(r'(\d{1,2}:\d{2})', dep_time)
                        arr_time_match = re.search(r'(\d{1,2}:\d{2})', arr_time)
                        
                        if dep_time_match and arr_time_match:
                            dep_time_clean = dep_time_match.group(1)
                            arr_time_clean = arr_time_match.group(1)
                            
                            # ゼロパディング
                            if len(dep_time_clean.split(':')[0]) == 1:
                                dep_time_clean = '0' + dep_time_clean
                            if len(arr_time_clean.split(':')[0]) == 1:
                                arr_time_clean = '0' + arr_time_clean
                            
                            # 備考
                            remarks = cells[3].get_text(strip=True) if len(cells) > 3 else ''
                            
                            # コードシェア情報を追加
                            if airline_prefix != 'JAL':
                                operator = f"{airline_prefix}運航"
                                if remarks:
                                    remarks = f"{operator}、{remarks}"
                                else:
                                    remarks = operator
                            
                            flights.append({
                                'airline_code': 'JAL',
                                'flight_number': flight_number,
                                'departure_code': current_dep,
                                'arrival_code': current_arr,
                                'departure_time': dep_time_clean + ':00',
                                'arrival_time': arr_time_clean + ':00',
                                'period_start': PERIOD_START,
                                'period_end': PERIOD_END,
                                'remarks': remarks,
                                'is_active': 'true'
                            })
            
            return flights
            
        except Exception as e:
            print(f"  エラー: {e}")
            try:
                page.close()
            except:
                pass
            if attempt < 2:
                time.sleep(5)
    
    return []


def main():
    print("=" * 60)
    print("JAL 3月ダイヤ スクレイピング（修正版）")
    print(f"期間: {PERIOD_START} 〜 {PERIOD_END}")
    print(f"対象空港数: {len(AIRPORTS)}")
    print("=" * 60)
    
    # 処理済みルートを追跡
    processed_routes = set()
    all_flights = []
    
    # ダウンロード済みをチェック
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                key = (row['departure_code'], row['arrival_code'])
                processed_routes.add(key)
                processed_routes.add((row['arrival_code'], row['departure_code']))
        print(f"ダウンロード済み: {len(processed_routes)//2} ルート")
    
    # CSVファイル準備
    file_exists = os.path.exists(OUTPUT_FILE) and os.path.getsize(OUTPUT_FILE) > 0
    
    with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as f:
        fieldnames = ['airline_code', 'flight_number', 'departure_code', 'arrival_code',
                      'departure_time', 'arrival_time', 'period_start', 'period_end',
                      'remarks', 'is_active']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        
        if not file_exists:
            writer.writeheader()
        
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=False)
            
            route_count = 0
            total_flights = 0
            
            for i, dep in enumerate(AIRPORTS):
                print(f"\n[{i+1}/{len(AIRPORTS)}] {dep} 出発")
                
                for arr in AIRPORTS:
                    if dep == arr:
                        continue
                    
                    # 既に処理済みならスキップ（往復どちらかで取得済み）
                    route_key = tuple(sorted([dep, arr]))
                    if route_key in processed_routes:
                        continue
                    
                    processed_routes.add(route_key)
                    route_count += 1
                    
                    print(f"  {dep} ⇔ {arr} ... ", end='', flush=True)
                    
                    flights = get_jal_timetable(dep, arr, browser)
                    
                    if flights:
                        # 重複除去（同じ便名・同じ出発地・同じ到着地・同じ時刻）
                        seen = set()
                        unique_flights = []
                        for flight in flights:
                            key = (flight['flight_number'], flight['departure_code'], 
                                   flight['arrival_code'], flight['departure_time'])
                            if key not in seen:
                                seen.add(key)
                                unique_flights.append(flight)
                        
                        writer.writerows(unique_flights)
                        f.flush()
                        total_flights += len(unique_flights)
                        print(f"{len(unique_flights)}便")
                    else:
                        print("便なし")
                    
                    # サーバー負荷軽減
                    time.sleep(random.uniform(2, 4))
                
                print(f"  [累計: {total_flights}便]")
            
            browser.close()
    
    print("\n" + "=" * 60)
    print(f"完了！")
    print(f"処理ルート数: {route_count}")
    print(f"取得便数: {total_flights}")
    print(f"出力ファイル: {OUTPUT_FILE}")
    print("=" * 60)


if __name__ == '__main__':
    main()
