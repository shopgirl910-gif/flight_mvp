"""
JAL区間マイル取得スクリプト v2
不足している残りの路線を取得
"""

from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import re

# 不足している路線リスト（追加分）
MISSING_ROUTES = [
    ('AKJ', 'NGO'), ('AOJ', 'HND'), ('AOJ', 'NGO'), ('AXT', 'CTS'),
    ('AXT', 'NGO'), ('AXT', 'OKD'), ('CTS', 'AXT'), ('CTS', 'FKS'),
    ('CTS', 'HKD'), ('CTS', 'KMQ'), ('CTS', 'KUH'), ('CTS', 'MSJ'),
    ('CTS', 'OKJ'), ('CTS', 'RIS'), ('CTS', 'SHB'), ('CTS', 'TOY'),
    ('CTS', 'UKB'), ('CTS', 'WKJ'), ('FKS', 'CTS'), ('FKS', 'ITM'),
    ('FSZ', 'OKA'), ('FUK', 'KMQ'), ('GAJ', 'HND'), ('GAJ', 'NGO'),
    ('HAC', 'HND'), ('HIJ', 'OKA'), ('HIJ', 'SDJ'), ('HKD', 'CTS'),
    ('HKD', 'NGO'), ('HKD', 'OKD'), ('HNA', 'NGO'), ('HND', 'HAC'),
    ('HND', 'HSG'), ('HND', 'IWJ'), ('HND', 'MBE'), ('HND', 'NTQ'),
    ('HND', 'ONJ'), ('HND', 'SHB'), ('HND', 'SYO'), ('HND', 'UKB'),
    ('HND', 'WKJ'), ('HSG', 'HND'), ('ISG', 'ITM'), ('ISG', 'NGO'),
    ('ITM', 'FKS'), ('ITM', 'ISG'), ('ITM', 'KCZ'), ('ITM', 'MMJ'),
    ('ITM', 'MMY'), ('ITM', 'OKI'), ('ITM', 'TJH'), ('IWJ', 'HND'),
    ('IWK', 'HND'), ('IWK', 'OKA'), ('IZO', 'HND'), ('IZO', 'OKI'),
    ('KCZ', 'ITM'), ('KIJ', 'NGO'), ('KIJ', 'OKA'), ('KIX', 'MMY'),
    ('KKX', 'KOJ'), ('KMI', 'NGO'), ('KMI', 'OKA'), ('KMJ', 'HND'),
    ('KMJ', 'ITM'), ('KMJ', 'NGO'), ('KMJ', 'OKA'), ('KMQ', 'CTS'),
    ('KMQ', 'FUK'), ('KMQ', 'HND'), ('KMQ', 'OKA'), ('KOJ', 'HND'),
    ('KOJ', 'ITM'), ('KOJ', 'KKX'), ('KOJ', 'KUM'), ('KOJ', 'NGO'),
    ('KOJ', 'OKA'), ('KOJ', 'OKE'), ('KOJ', 'RNJ'), ('KOJ', 'TKN'),
    ('KOJ', 'TNE'), ('KTD', 'OKA'), ('KUH', 'CTS'), ('KUH', 'HND'),
    ('KUH', 'OKD'), ('KUM', 'KOJ'), ('MBE', 'HND'), ('MMB', 'HND'),
    ('MMB', 'NGO'), ('MMB', 'OKD'), ('MMD', 'OKA'), ('MMJ', 'ITM'),
    ('MMY', 'ITM'), ('MMY', 'KIX'), ('MMY', 'NGO'), ('MMY', 'TRA'),
    ('MSJ', 'CTS'), ('MSJ', 'OKD'), ('MYJ', 'HND'), ('MYJ', 'ITM'),
]

OUTPUT_FILE = 'missing_routes_miles_v2.csv'

def get_miles_for_route(dep, arr, browser):
    """JAL時刻表ページから区間マイルを取得"""
    # 複数の期間を試す
    periods = ['20260106_20260228', '20260301_20260328']
    
    for period in periods:
        url = f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep}&arrival={arr}&month={period}"
        
        try:
            page = browser.new_page()
            page.goto(url, timeout=60000)
            page.wait_for_timeout(3000)
            html = page.content()
            page.close()
            
            soup = BeautifulSoup(html, 'html.parser')
            text = soup.get_text()
            match = re.search(r'区間マイル[：:]\s*(\d+)\s*マイル', text)
            
            if match:
                return int(match.group(1))
                
        except Exception as e:
            try:
                page.close()
            except:
                pass
    
    return None


def main():
    print("=" * 60)
    print("JAL 区間マイル取得 v2")
    print(f"対象: {len(MISSING_ROUTES)}路線")
    print("=" * 60)
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        
        results = []
        
        for i, (dep, arr) in enumerate(MISSING_ROUTES):
            print(f"  [{i+1}/{len(MISSING_ROUTES)}] {dep} → {arr} ... ", end='', flush=True)
            
            miles = get_miles_for_route(dep, arr, browser)
            
            if miles:
                print(f"{miles}マイル")
                results.append({
                    'departure_code': dep,
                    'arrival_code': arr,
                    'distance_miles': miles
                })
                # 逆方向も追加
                results.append({
                    'departure_code': arr,
                    'arrival_code': dep,
                    'distance_miles': miles
                })
            else:
                print("取得失敗")
            
            time.sleep(random.uniform(1, 2))
        
        browser.close()
    
    # CSV出力
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['departure_code', 'arrival_code', 'distance_miles'])
        writer.writeheader()
        writer.writerows(results)
    
    print("\n" + "=" * 60)
    print(f"完了！ 出力ファイル: {OUTPUT_FILE}")
    print(f"取得: {len(results)}件")
    print("=" * 60)


if __name__ == '__main__':
    main()
