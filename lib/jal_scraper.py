"""
JAL国内線時刻表スクレイピングRPA
出力: jal_schedules.csv

使用方法:
1. pip install selenium beautifulsoup4 pandas
2. ChromeDriverをインストール（またはselenium 4.6+なら自動管理）
3. python jal_scraper.py

所要時間: 約30〜50分
"""

import csv
import time
import re
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from bs4 import BeautifulSoup

# 出力ファイル
OUTPUT_FILE = 'jal_schedules.csv'

# 取得対象期間（追加・変更が簡単にできる）
# 形式: 'YYYYMMDD_YYYYMMDD'
PERIODS = [
    '20251026_20260105',  # 2025年10月26日〜2026年1月5日
    '20260106_20260228',  # 2026年1月6日〜2026年2月28日
    '20260301_20260328',  # 2026年3月1日〜2026年3月28日
    # '20260329_20260531',  # 2026年3月29日〜5月31日 ← 2月上旬に追加予定
]

# 期間をDB用の日付形式に変換
def period_to_dates(period):
    """'20251026_20260105' → ('2025-10-26', '2026-01-05')"""
    start, end = period.split('_')
    start_date = f"{start[:4]}-{start[4:6]}-{start[6:8]}"
    end_date = f"{end[:4]}-{end[4:6]}-{end[6:8]}"
    return start_date, end_date

# JAL国内線就航空港コード（主要空港）
AIRPORTS = [
    'HND', 'NRT',  # 東京
    'ITM', 'KIX',  # 大阪
    'CTS', 'OKD',  # 札幌
    'NGO',  # 名古屋
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
]

# 空港名マッピング（JALサイトでの表示名）
AIRPORT_NAMES = {
    'HND': '東京(羽田)', 'NRT': '東京(成田)', 'KIX': '大阪(関西)', 'ITM': '大阪(伊丹)',
    'NGO': '名古屋(中部)', 'CTS': '札幌(新千歳)', 'FUK': '福岡', 'OKA': '沖縄(那覇)',
    'NGS': '長崎', 'KMJ': '熊本', 'OIT': '大分', 'MYJ': '松山', 'HIJ': '広島', 
    'TAK': '高松', 'KCZ': '高知', 'TKS': '徳島', 'KOJ': '鹿児島',
    'SDJ': '仙台', 'AOJ': '青森', 'AKJ': '旭川', 'AXT': '秋田', 'GAJ': '山形',
    'MMB': '女満別', 'OBO': '帯広', 'KUH': '釧路', 'HKD': '函館',
    'ISG': '石垣', 'MMY': '宮古', 'UBJ': '山口宇部', 'IWK': '岩国',
    'OKJ': '岡山', 'TTJ': '鳥取', 'YGJ': '米子', 'IZO': '出雲',
    'HSG': '佐賀', 'KMI': '宮崎', 'NKM': '名古屋(小牧)', 'UKB': '神戸',
    'ASJ': '奄美', 'TKN': '徳之島', 'FKS': '福島', 'HNA': '花巻', 
    'MSJ': '三沢', 'ONJ': '大館能代', 'SHM': '南紀白浜',
    'NTQ': '能登', 'KKJ': '北九州', 'TNE': '種子島', 'KUM': '屋久島', 
    'RNJ': '与論', 'OGN': '与那国', 'HAC': '八丈島',
    'MBE': '紋別', 'SHB': '中標津', 'WKJ': '稚内', 'OKD': '札幌(丘珠)', 'OIR': '奥尻',
    'IKI': '壱岐', 'TSJ': '対馬', 'FUJ': '五島福江', 'MMJ': '松本', 'AXJ': '天草', 'KKX': '喜界',
}

def setup_driver():
    """Chromeドライバーをセットアップ"""
    options = Options()
    options.add_argument('--headless')  # ヘッドレスモード
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
    
    driver = webdriver.Chrome(options=options)
    driver.implicitly_wait(10)
    return driver


def get_jal_timetable_url(dep_code, arr_code, period):
    """JAL時刻表ページのURLを生成"""
    return f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep_code}&arrival={arr_code}&month={period}"


def parse_timetable_page(html_content, dep_code, arr_code, codeshare_only=False):
    """時刻表ページをパースしてフライト情報を抽出
    
    JALの時刻表ページは2つのテーブルを持つ:
    - テーブル0: dep_code → arr_code
    - テーブル1: arr_code → dep_code (逆方向)
    
    codeshare_only=True の場合、コードシェア便（JTA運航、RAC運航等）のみ取得
    """
    soup = BeautifulSoup(html_content, 'html.parser')
    flights = []
    
    # コードシェア運航会社のパターン
    codeshare_patterns = ['JTA運航', 'RAC運航', 'JAC運航', 'HAC運航', 'FDA運航', 'AMX運航']
    
    # 時刻表テーブルを探す（JAL便名を含むテーブル）
    tables = soup.find_all('table')
    timetable_tables = []
    
    for table in tables:
        rows = table.find_all('tr')
        if len(rows) >= 1:
            for row in rows:
                cells = row.find_all(['td', 'th'])
                if cells:
                    first_cell_text = cells[0].get_text(strip=True)
                    if 'JAL' in first_cell_text and re.search(r'JAL\s*\d+', first_cell_text):
                        timetable_tables.append(table)
                        break
    
    # テーブル0: dep_code → arr_code, テーブル1: arr_code → dep_code
    for table_idx, table in enumerate(timetable_tables[:2]):
        # 方向を決定
        if table_idx == 0:
            current_dep = dep_code
            current_arr = arr_code
        else:
            current_dep = arr_code
            current_arr = dep_code
        
        rows = table.find_all('tr')
        
        for row in rows:
            cells = row.find_all(['td', 'th'])
            if len(cells) < 3:
                continue
            
            # 便名を探す（JAL XXX形式）
            first_cell_text = cells[0].get_text(strip=True)
            flight_match = re.search(r'JAL\s*(\d+)', first_cell_text)
            
            if flight_match:
                flight_number = flight_match.group(1)
                
                # コードシェア便かどうか判定
                is_codeshare = any(pattern in first_cell_text for pattern in codeshare_patterns)
                
                # コードシェアのみモードで、コードシェアでない場合はスキップ
                if codeshare_only and not is_codeshare:
                    continue
                
                # 出発時刻と到着時刻を取得（2列目、3列目）
                dep_time = cells[1].get_text(strip=True) if len(cells) > 1 else ''
                arr_time = cells[2].get_text(strip=True) if len(cells) > 2 else ''
                
                # 時刻形式の検証（HH:MM）
                dep_time_match = re.search(r'(\d{1,2}:\d{2})', dep_time)
                arr_time_match = re.search(r'(\d{1,2}:\d{2})', arr_time)
                
                if dep_time_match and arr_time_match:
                    dep_time_clean = dep_time_match.group(1)
                    arr_time_clean = arr_time_match.group(1)
                    
                    # 時刻を HH:MM:SS 形式に（ゼロパディング）
                    if len(dep_time_clean.split(':')[0]) == 1:
                        dep_time_clean = '0' + dep_time_clean
                    if len(arr_time_clean.split(':')[0]) == 1:
                        arr_time_clean = '0' + arr_time_clean
                    
                    # 備考を取得（4列目）
                    remarks = cells[3].get_text(strip=True) if len(cells) > 3 else ''
                    
                    # コードシェアの場合、運航会社情報を備考に追加
                    if is_codeshare:
                        for pattern in codeshare_patterns:
                            if pattern in first_cell_text:
                                if remarks:
                                    remarks = f"{pattern}、{remarks}"
                                else:
                                    remarks = pattern
                                break
                    
                    flights.append({
                        'flight_number': flight_number,
                        'departure_code': current_dep,
                        'arrival_code': current_arr,
                        'departure_time': dep_time_clean + ':00',
                        'arrival_time': arr_time_clean + ':00',
                        'remarks': remarks,
                    })
    
    return flights


def scrape_route(driver, dep_code, arr_code, period, codeshare_only=False):
    """1つの路線・1つの期間をスクレイピング"""
    url = get_jal_timetable_url(dep_code, arr_code, period)
    flights = []
    period_start, period_end = period_to_dates(period)
    
    try:
        driver.get(url)
        time.sleep(8)  # JavaScript読み込み待ち（長めに）
        
        # ページが存在するか確認
        if "お探しのページは見つかりませんでした" in driver.page_source:
            return []
        
        if "該当する時刻表がありません" in driver.page_source:
            return []
        
        # HTMLを取得してパース
        html = driver.page_source
        parsed_flights = parse_timetable_page(html, dep_code, arr_code, codeshare_only)
        
        # 期間情報を追加
        for flight in parsed_flights:
            flight['period_start'] = period_start
            flight['period_end'] = period_end
        
        flights = parsed_flights
        
        if flights:
            print(f"    {dep_code} ↔ {arr_code}: {len(flights)}便")
        
    except TimeoutException:
        print(f"  {dep_code} → {arr_code}: タイムアウト")
    except Exception as e:
        print(f"  {dep_code} → {arr_code}: エラー - {e}")
    
    return flights


def restart_driver(driver):
    """ドライバーを再起動"""
    try:
        driver.quit()
    except:
        pass
    time.sleep(2)
    return setup_driver()


def main(codeshare_only=False):
    """メイン処理"""
    mode_text = "コードシェア便のみ" if codeshare_only else "全便"
    print("=" * 60)
    print(f"JAL国内線時刻表スクレイピング開始 ({mode_text})")
    print(f"対象空港数: {len(AIRPORTS)}")
    print(f"対象期間数: {len(PERIODS)}")
    for p in PERIODS:
        start, end = period_to_dates(p)
        print(f"  - {start} 〜 {end}")
    print("=" * 60)
    
    driver = setup_driver()
    all_flights = []
    processed_routes = set()
    error_count = 0
    restart_interval = 20  # 20リクエストごとにブラウザ再起動
    request_count = 0
    
    # 途中経過保存用
    TEMP_FILE = 'jal_schedules_temp.csv'
    
    try:
        for i, dep_code in enumerate(AIRPORTS):
            print(f"\n[{i+1}/{len(AIRPORTS)}] {dep_code} ({AIRPORT_NAMES.get(dep_code, dep_code)})")
            
            for arr_code in AIRPORTS:
                if dep_code == arr_code:
                    continue
                
                # 逆方向は1ページで取得できるのでスキップ
                route_key = tuple(sorted([dep_code, arr_code]))
                if route_key in processed_routes:
                    continue
                
                processed_routes.add(route_key)
                
                # 全期間を取得
                for period in PERIODS:
                    request_count += 1
                    
                    # 定期的にブラウザ再起動（メモリリーク対策）
                    if request_count % restart_interval == 0:
                        print(f"  [ブラウザ再起動中... ({request_count}リクエスト処理済)]")
                        driver = restart_driver(driver)
                        error_count = 0
                    
                    try:
                        flights = scrape_route(driver, dep_code, arr_code, period, codeshare_only)
                        all_flights.extend(flights)
                        error_count = 0
                    except Exception as e:
                        print(f"    エラー: {e}")
                        error_count += 1
                        
                        # 連続エラーが多い場合はブラウザ再起動
                        if error_count >= 3:
                            print(f"  [連続エラーのためブラウザ再起動]")
                            driver = restart_driver(driver)
                            error_count = 0
                    
                    # サーバー負荷軽減
                    time.sleep(1.5)
            
            # 各出発空港処理後に途中経過を保存
            with open(TEMP_FILE, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow([
                    'airline_code', 'flight_number', 'departure_code', 'arrival_code',
                    'departure_time', 'arrival_time', 'period_start', 'period_end',
                    'remarks', 'is_active'
                ])
                for flight in all_flights:
                    writer.writerow([
                        'JAL',
                        flight['flight_number'],
                        flight['departure_code'],
                        flight['arrival_code'],
                        flight['departure_time'],
                        flight['arrival_time'],
                        flight['period_start'],
                        flight['period_end'],
                        flight['remarks'],
                        'true'
                    ])
            print(f"  [途中経過保存: {len(all_flights)}便]")
        
        # 最終CSVに出力
        print(f"\n\n合計 {len(all_flights)} 便を取得")
        print(f"CSVファイルに出力中: {OUTPUT_FILE}")
        
        with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                'airline_code', 'flight_number', 'departure_code', 'arrival_code',
                'departure_time', 'arrival_time', 'period_start', 'period_end',
                'remarks', 'is_active'
            ])
            
            for flight in all_flights:
                writer.writerow([
                    'JAL',
                    flight['flight_number'],
                    flight['departure_code'],
                    flight['arrival_code'],
                    flight['departure_time'],
                    flight['arrival_time'],
                    flight['period_start'],
                    flight['period_end'],
                    flight['remarks'],
                    'true'
                ])
        
        print(f"\n完了！ {OUTPUT_FILE} を確認してください。")
        
    finally:
        try:
            driver.quit()
        except:
            pass


if __name__ == '__main__':
    import sys
    
    codeshare_only = '--codeshare' in sys.argv or '-c' in sys.argv
    
    if '--help' in sys.argv or '-h' in sys.argv:
        print("""
JAL国内線時刻表スクレイピングRPA

使用方法:
  python jal_scraper.py              # 全便取得
  python jal_scraper.py --codeshare  # コードシェア便のみ取得
  python jal_scraper.py -c           # コードシェア便のみ取得（短縮版）

対象期間の変更:
  スクリプト冒頭の PERIODS リストを編集してください。
  例: '20260329_20260531' を追加

出力:
  jal_schedules.csv      - 最終結果
  jal_schedules_temp.csv - 途中経過（クラッシュ時の復旧用）
""")
    else:
        main(codeshare_only=codeshare_only)
