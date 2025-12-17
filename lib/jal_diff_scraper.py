"""
JAL国内線時刻表 差分スクレイピング
既存CSVにない路線のみ取得
"""

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from bs4 import BeautifulSoup
import csv
import time
import re

# 既存路線ペア（スキップ対象）
EXISTING_ROUTES = {
    'AOJ-CTS', 'AOJ-ITM', 'AOJ-UKB', 'ASJ-FUK', 'ASJ-HND', 'ASJ-ITM', 'ASJ-OKA', 'ASJ-RNJ',
    'AXJ-FUK', 'AXJ-KMJ', 'AXT-ITM', 'AXT-OKD', 'CTS-FSZ', 'CTS-FUK', 'CTS-GAJ', 'CTS-HIJ',
    'CTS-HND', 'CTS-ITM', 'CTS-MMJ', 'FSZ-CTS', 'FSZ-FUK', 'FSZ-IZO', 'FSZ-KMJ', 'FSZ-KOJ',
    'FUJ-FUK', 'FUK-ASJ', 'FUK-CTS', 'FUK-HNA', 'FUK-HND', 'FUK-ITM', 'FUK-KIJ', 'FUK-KOJ',
    'FUK-KUM', 'FUK-OKA', 'GAJ-CTS', 'GAJ-ITM', 'HIJ-CTS', 'HKD-ITM', 'HKD-OIR', 'HKD-OKD',
    'HNA-CTS', 'HNA-FUK', 'HNA-ITM', 'HND-AKJ', 'HND-AOJ', 'HND-ASJ', 'HND-AXT', 'HND-CTS',
    'HND-FUK', 'HND-GAJ', 'HND-HIJ', 'HND-HKD', 'HND-ISG', 'HND-ITM', 'HND-IZO', 'HND-KCZ',
    'HND-KIX', 'HND-KKJ', 'HND-KMI', 'HND-KMJ', 'HND-KMQ', 'HND-KOJ', 'HND-KUH', 'HND-MMB',
    'HND-MMY', 'HND-MSJ', 'HND-MYJ', 'HND-NGO', 'HND-NGS', 'HND-OBO', 'HND-OIT', 'HND-OKA',
    'HND-OKJ', 'HND-SHM', 'HND-TAK', 'HND-TKS', 'HND-UBJ', 'ISG-HND', 'ISG-MMY', 'ISG-OGN',
    'ISG-OKA', 'ITM-CTS', 'ITM-FUK', 'ITM-HKD', 'ITM-HND', 'ITM-KUM', 'ITM-NRT', 'ITM-OKA',
    'ITM-OKI', 'ITM-TKN', 'ITM-TNE', 'IZO-FSZ', 'IZO-FUK', 'IZO-ITM', 'IZO-NGO', 'IZO-OKI',
    'KCZ-FUK', 'KCZ-NKM', 'KIJ-CTS', 'KIJ-FUK', 'KIJ-ITM', 'KMI-FUK', 'KMI-ITM', 'KMJ-AXJ',
    'KMJ-ITM', 'KOJ-FSZ', 'KOJ-FUK', 'KOJ-ITM', 'KOJ-MYJ', 'KUH-OKD', 'KUM-FUK', 'KUM-ITM',
    'MMB-CTS', 'MMB-OKD', 'MMJ-CTS', 'MMJ-FUK', 'MMY-HND', 'MMY-ISG', 'MMY-OKA', 'MSJ-ITM',
    'MSJ-OKD', 'MYJ-FUK', 'MYJ-ITM', 'MYJ-KOJ', 'NGO-CTS', 'NGO-IZO', 'NGO-OKA', 'NGS-ITM',
    'NKM-FUK', 'NKM-KCZ', 'NRT-ITM', 'NRT-NGO', 'OGN-ISG', 'OGN-OKA', 'OIR-HKD', 'OIR-OKD',
    'OIT-ITM', 'OKA-ASJ', 'OKA-FUK', 'OKA-HND', 'OKA-ISG', 'OKA-ITM', 'OKA-MMY', 'OKA-NGO',
    'OKA-OGN', 'OKA-OKE', 'OKA-RNJ', 'OKD-MSJ', 'OKD-OIR', 'OKE-OKA', 'OKE-TKN', 'OKI-ITM',
    'OKI-IZO', 'RNJ-ASJ', 'RNJ-OKA', 'SDJ-CTS', 'SDJ-FUK', 'SDJ-ITM', 'SHB-OKD', 'TJH-ITM',
    'TKN-ITM', 'TKN-OKE', 'TKS-FUK', 'TNE-ITM', 'TSJ-FUK'
}

# 期間設定
PERIODS = [
    ('2025-10-26', '2026-01-05'),
    ('2026-01-06', '2026-02-28'),
    ('2026-03-01', '2026-03-28'),
]

# 出発空港リスト
AIRPORTS = [
    'HND', 'NRT', 'ITM', 'KIX', 'UKB', 'CTS', 'OKD', 'NGO', 'NKM', 'FUK', 'OKA',
    'WKJ', 'MBE', 'MMB', 'SHB', 'KUH', 'OBO', 'AKJ', 'HKD', 'OIR',
    'AOJ', 'MSJ', 'HNA', 'AXT', 'ONJ', 'GAJ', 'SDJ', 'FKS',
    'HAC', 'FSZ', 'MMJ', 'NTQ', 'TOY', 'KMQ', 'SHM',
    'TTJ', 'YGJ', 'IZO', 'OKJ', 'HIJ', 'IWK', 'UBJ', 'TKS', 'TAK', 'KCZ', 'MYJ',
    'KKJ', 'HSG', 'NGS', 'KMJ', 'OIT', 'KMI', 'KOJ', 'AXJ',
    'IKI', 'TSJ', 'FUJ', 'TNE', 'KUM', 'ASJ', 'KKX', 'TKN', 'OGN', 'MMY', 'ISG', 'RNJ',
]

def create_driver():
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    return webdriver.Chrome(options=options)

def parse_flights(html, dep_code):
    """HTMLから便情報を抽出"""
    soup = BeautifulSoup(html, 'html.parser')
    flights = []
    
    rows = soup.select('tr')
    for row in rows:
        cells = row.find_all('td')
        if len(cells) >= 4:
            flight_text = cells[0].get_text(strip=True)
            
            # JAL/JTA/JAC/RAC/HAC便のみ
            if flight_text.startswith(('JAL', 'JTA', 'JAC', 'RAC', 'HAC')):
                flight_num = re.sub(r'^(JAL|JTA|JAC|RAC|HAC)', '', flight_text)
                dep_time = cells[1].get_text(strip=True)
                arr_code = cells[2].get_text(strip=True)[:3]
                arr_time = cells[3].get_text(strip=True)
                remarks = cells[4].get_text(strip=True) if len(cells) > 4 else ''
                
                if dep_time and arr_time and arr_code:
                    flights.append({
                        'flight_number': flight_num,
                        'departure_code': dep_code,
                        'arrival_code': arr_code,
                        'departure_time': dep_time[:5],
                        'arrival_time': arr_time[:5],
                        'remarks': remarks
                    })
    
    return flights

def scrape_route(driver, dep_code, period_start, period_end):
    """1出発空港・1期間の便を取得"""
    url = f"https://www.jal.co.jp/jp/ja/dom/route/time/{dep_code}.html"
    
    try:
        driver.get(url)
        time.sleep(2)
        
        # 期間選択があれば選択
        try:
            select = Select(driver.find_element(By.ID, 'period'))
            for option in select.options:
                if period_start.replace('-', '/') in option.text:
                    select.select_by_visible_text(option.text)
                    time.sleep(1)
                    break
        except:
            pass
        
        html = driver.page_source
        return parse_flights(html, dep_code)
    
    except Exception as e:
        print(f"  エラー: {dep_code} - {e}")
        return []

def main():
    print("=" * 60)
    print("JAL国内線時刻表 差分スクレイピング")
    print(f"既存路線数: {len(EXISTING_ROUTES)} (スキップ)")
    print("=" * 60)
    
    all_flights = []
    new_routes = set()
    skipped_routes = set()
    
    driver = create_driver()
    request_count = 0
    
    try:
        for i, dep_code in enumerate(AIRPORTS):
            print(f"\n[{i+1}/{len(AIRPORTS)}] {dep_code}")
            
            for period_start, period_end in PERIODS:
                flights = scrape_route(driver, dep_code, period_start, period_end)
                
                for flight in flights:
                    route_key = f"{flight['departure_code']}-{flight['arrival_code']}"
                    
                    # 既存路線はスキップ
                    if route_key in EXISTING_ROUTES:
                        skipped_routes.add(route_key)
                        continue
                    
                    # 新規路線を追加
                    new_routes.add(route_key)
                    flight['period_start'] = period_start
                    flight['period_end'] = period_end
                    all_flights.append(flight)
                
                request_count += 1
                
                # 20リクエストごとにブラウザ再起動
                if request_count % 20 == 0:
                    print(f"  [ブラウザ再起動... ({request_count}リクエスト処理済)]")
                    driver.quit()
                    time.sleep(2)
                    driver = create_driver()
            
            if new_routes:
                print(f"  新規路線: {len([f for f in all_flights if f['departure_code'] == dep_code])}便")
    
    finally:
        driver.quit()
    
    # CSV出力
    if all_flights:
        output_file = 'jal_diff_schedules.csv'
        with open(output_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'airline_code', 'flight_number', 'departure_code', 'arrival_code',
                'departure_time', 'arrival_time', 'is_active', 'period_start', 'period_end', 'remarks'
            ])
            writer.writeheader()
            
            for flight in all_flights:
                writer.writerow({
                    'airline_code': 'JAL',
                    'flight_number': flight['flight_number'],
                    'departure_code': flight['departure_code'],
                    'arrival_code': flight['arrival_code'],
                    'departure_time': flight['departure_time'],
                    'arrival_time': flight['arrival_time'],
                    'is_active': 'true',
                    'period_start': flight['period_start'],
                    'period_end': flight['period_end'],
                    'remarks': flight.get('remarks', '')
                })
        
        print(f"\n完了: {output_file}")
        print(f"新規路線: {len(new_routes)}路線")
        print(f"新規便数: {len(all_flights)}便")
    else:
        print("\n新規路線なし")
    
    print(f"スキップした既存路線: {len(skipped_routes)}路線")

if __name__ == '__main__':
    main()
