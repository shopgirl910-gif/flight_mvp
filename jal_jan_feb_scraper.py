"""
JAL国内線時刻表スクレイピング（就航路線自動取得版）
1. 各空港の就航先を自動取得
2. 実際に存在する路線だけスクレイピング
3. 出力: jal_march_schedules.csv

使用方法:
1. pip install playwright beautifulsoup4
2. python -m playwright install chromium
3. python jal_march_scraper_v2.py
"""

from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import re
import os
import json

# 出力ファイル
OUTPUT_FILE = 'jal_jan_feb_schedules.csv'
ROUTES_CACHE_FILE = 'jal_routes_cache_jan_feb.json'

# 1月〜2月ダイヤ
PERIOD = '20260106_20260228'
PERIOD_START = '2026-01-06'
PERIOD_END = '2026-02-28'

# 空港名→コードマッピング
AIRPORT_NAME_TO_CODE = {
    '東京(羽田)': 'HND', '羽田': 'HND',
    '東京(成田)': 'NRT', '成田': 'NRT',
    '大阪(関西)': 'KIX', '関西': 'KIX',
    '大阪(伊丹)': 'ITM', '伊丹': 'ITM',
    '大阪(伊丹・関西・神戸)': 'ITM',  # グループはITM代表
    '大阪(神戸)': 'UKB', '神戸': 'UKB',
    '名古屋(中部)': 'NGO', '中部': 'NGO',
    '名古屋(中部・小牧)': 'NGO',  # グループはNGO代表
    '名古屋(小牧)': 'NKM', '小牧': 'NKM',
    '札幌(新千歳)': 'CTS', '新千歳': 'CTS',
    '札幌(新千歳・丘珠)': 'CTS',  # グループはCTS代表
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

# 出発空港コード一覧（JALが就航している空港）
DEPARTURE_AIRPORTS = [
    'HND', 'NRT', 'ITM', 'KIX', 'UKB', 'NGO', 'NKM', 'CTS', 'OKD', 'FUK', 'OKA',
    'NGS', 'KMJ', 'OIT', 'MYJ', 'HIJ', 'TAK', 'KCZ', 'TKS', 'KOJ',
    'SDJ', 'AOJ', 'AKJ', 'AXT', 'GAJ', 'MMB', 'OBO', 'KUH', 'HKD',
    'ISG', 'MMY', 'UBJ', 'IWK', 'OKJ', 'TTJ', 'YGJ', 'IZO', 'HSG', 'KMI',
    'ASJ', 'TKN', 'FKS', 'HNA', 'MSJ', 'ONJ', 'SHM',
    'NTQ', 'KKJ', 'TNE', 'KUM', 'RNJ', 'OGN', 'HAC',
    'MBE', 'SHB', 'WKJ', 'OIR', 'IKI', 'TSJ', 'FUJ', 'MMJ', 'AXJ', 'KKX',
    'FSZ', 'KIJ', 'SYO', 'TOY', 'KMQ', 'OKI', 'OKE', 'UEO', 'KTD', 'MMD', 'TRA', 'RIS',
]


def get_destinations_for_airport(dep_code, browser):
    """出発空港から就航している到着空港リストを取得"""
    url = f"https://www.jal.co.jp/jp/ja/dom/route/time/departure-arrival/?departure={dep_code}&arrival=ALL&month={PERIOD}"
    
    destinations = []
    
    try:
        page = browser.new_page()
        page.goto(url, timeout=60000)
        page.wait_for_timeout(3000)
        html = page.content()
        page.close()
        
        soup = BeautifulSoup(html, 'html.parser')
        
        # 就航先のリンクを探す
        # パターン1: ボタン形式
        buttons = soup.find_all(['a', 'button', 'div'], class_=re.compile(r'btn|button|card|link', re.I))
        
        for btn in buttons:
            text = btn.get_text(strip=True)
            # 空港名をコードに変換
            for name, code in AIRPORT_NAME_TO_CODE.items():
                if name == text or text.startswith(name):
                    if code != dep_code:  # 自分自身は除外
                        destinations.append(code)
                    break
        
        # パターン2: リンクのhrefから取得
        links = soup.find_all('a', href=re.compile(r'departure=.*&arrival='))
        for link in links:
            href = link.get('href', '')
            match = re.search(r'arrival=([A-Z]{3})', href)
            if match:
                arr_code = match.group(1)
                if arr_code != dep_code and arr_code != 'ALL':
                    destinations.append(arr_code)
        
        # パターン3: テキストから空港名を抽出
        if not destinations:
            all_text = soup.get_text()
            for name, code in AIRPORT_NAME_TO_CODE.items():
                if name in all_text and code != dep_code:
                    destinations.append(code)
        
        # 重複除去
        destinations = list(set(destinations))
        
    except Exception as e:
        print(f"  エラー: {e}")
        try:
            page.close()
        except:
            pass
    
    return destinations


def get_all_routes(browser):
    """全ての就航路線を取得"""
    print("\n[Phase 1] 就航路線を取得中...")
    
    # キャッシュがあれば使用
    if os.path.exists(ROUTES_CACHE_FILE):
        with open(ROUTES_CACHE_FILE, 'r', encoding='utf-8') as f:
            routes = json.load(f)
        print(f"  キャッシュから読み込み: {len(routes)}路線")
        return routes
    
    all_routes = set()
    
    for i, dep in enumerate(DEPARTURE_AIRPORTS):
        print(f"  [{i+1}/{len(DEPARTURE_AIRPORTS)}] {dep} の就航先を取得中...", end='', flush=True)
        
        destinations = get_destinations_for_airport(dep, browser)
        
        for arr in destinations:
            # 両方向を追加（ソートしてユニーク化）
            route_key = tuple(sorted([dep, arr]))
            all_routes.add(route_key)
        
        print(f" {len(destinations)}空港")
        time.sleep(random.uniform(1, 2))
    
    routes = [list(r) for r in all_routes]
    
    # キャッシュに保存
    with open(ROUTES_CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(routes, f)
    
    print(f"  合計: {len(routes)}路線")
    return routes


def get_jal_timetable(dep, arr, browser):
    """JAL時刻表ページをスクレイピング"""
    url = f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep}&arrival={arr}&month={PERIOD}"
    
    for attempt in range(3):
        try:
            page = browser.new_page()
            page.goto(url, timeout=60000)
            page.wait_for_timeout(4000)
            html = page.content()
            page.close()
            
            soup = BeautifulSoup(html, 'html.parser')
            
            # 方向を判定するためのヘッダーを探す
            direction_headers = []
            for elem in soup.find_all(['h2', 'h3', 'h4', 'div', 'p', 'span']):
                text = elem.get_text(strip=True)
                if '→' in text or '⇒' in text:
                    direction_headers.append(text)
            
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
                # 方向を決定
                current_dep, current_arr = None, None
                
                # ヘッダーから方向を取得
                if table_idx < len(direction_headers):
                    header = direction_headers[table_idx]
                    for name, code in AIRPORT_NAME_TO_CODE.items():
                        if current_dep is None and name in header.split('→')[0] if '→' in header else header.split('⇒')[0]:
                            current_dep = code
                        if current_arr is None and name in header.split('→')[-1] if '→' in header else header.split('⇒')[-1]:
                            current_arr = code
                
                # ヘッダーから取得できなければURL順
                if current_dep is None or current_arr is None:
                    if table_idx == 0:
                        current_dep, current_arr = dep, arr
                    else:
                        current_dep, current_arr = arr, dep
                
                rows = table.find_all('tr')
                
                for row in rows:
                    cells = row.find_all(['td', 'th'])
                    if len(cells) < 3:
                        continue
                    
                    first_cell_text = cells[0].get_text(strip=True)
                    
                    # 便名を探す
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
                            
                            # コードシェア情報
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
    print("JAL 3月ダイヤ スクレイピング（就航路線自動取得版）")
    print(f"期間: {PERIOD_START} 〜 {PERIOD_END}")
    print("=" * 60)
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        
        # Phase 1: 就航路線を取得
        routes = get_all_routes(browser)
        
        # 処理済みルートを追跡
        processed_routes = set()
        
        # ダウンロード済みをチェック
        if os.path.exists(OUTPUT_FILE):
            with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    key = tuple(sorted([row['departure_code'], row['arrival_code']]))
                    processed_routes.add(key)
            print(f"\nダウンロード済み: {len(processed_routes)}路線")
        
        # 未処理の路線を抽出
        remaining_routes = [r for r in routes if tuple(sorted(r)) not in processed_routes]
        print(f"残り: {len(remaining_routes)}路線\n")
        
        if not remaining_routes:
            print("全路線取得済み！")
            browser.close()
            return
        
        # Phase 2: 時刻表をスクレイピング
        print("[Phase 2] 時刻表を取得中...")
        
        # CSVファイル準備
        file_exists = os.path.exists(OUTPUT_FILE) and os.path.getsize(OUTPUT_FILE) > 0
        
        with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as f:
            fieldnames = ['airline_code', 'flight_number', 'departure_code', 'arrival_code',
                          'departure_time', 'arrival_time', 'period_start', 'period_end',
                          'remarks', 'is_active']
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            
            if not file_exists:
                writer.writeheader()
            
            total_flights = 0
            
            for i, route in enumerate(remaining_routes):
                dep, arr = route[0], route[1]
                print(f"  [{i+1}/{len(remaining_routes)}] {dep} ⇔ {arr} ... ", end='', flush=True)
                
                flights = get_jal_timetable(dep, arr, browser)
                
                if flights:
                    # 重複除去
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
                
                time.sleep(random.uniform(2, 4))
            
            print(f"\n取得完了: {total_flights}便")
        
        browser.close()
    
    print("\n" + "=" * 60)
    print(f"完了！ 出力ファイル: {OUTPUT_FILE}")
    print("=" * 60)


if __name__ == '__main__':
    main()
