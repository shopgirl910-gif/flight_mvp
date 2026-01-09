"""
JAL区間マイル取得スクリプト v3
schedulesに存在してroutesにない路線のみ取得
"""

from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import re

# 不足している路線（schedulesにあってroutesにない）
MISSING_ROUTES = [
    # 1-100
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
    # 101-197
    ('NGO', 'AKJ'), ('NGO', 'AOJ'), ('NGO', 'AXT'), ('NGO', 'GAJ'),
    ('NGO', 'HKD'), ('NGO', 'HNA'), ('NGO', 'ISG'), ('NGO', 'KIJ'),
    ('NGO', 'KMI'), ('NGO', 'KMJ'), ('NGO', 'KOJ'), ('NGO', 'MMB'),
    ('NGO', 'MMY'), ('NGO', 'MYJ'), ('NGO', 'NGS'), ('NGO', 'OIT'),
    ('NGO', 'SDJ'), ('NGS', 'HND'), ('NGS', 'ITM'), ('NGS', 'NGO'),
    ('NGS', 'TSJ'), ('NTQ', 'HND'), ('OBO', 'HND'), ('OGN', 'OKA'),
    ('OIT', 'HND'), ('OIT', 'NGO'), ('OKA', 'ASJ'), ('OKA', 'FSZ'),
    ('OKA', 'HIJ'), ('OKA', 'IWK'), ('OKA', 'KIJ'), ('OKA', 'KMI'),
    ('OKA', 'KMJ'), ('OKA', 'KMQ'), ('OKA', 'KOJ'), ('OKA', 'KTD'),
    ('OKA', 'MMD'), ('OKA', 'MYJ'), ('OKA', 'OGN'), ('OKA', 'OKE'),
    ('OKA', 'OKJ'), ('OKA', 'RNJ'), ('OKA', 'SDJ'), ('OKA', 'TAK'),
    ('OKA', 'UEO'), ('OKA', 'UKB'), ('OKD', 'AXT'), ('OKD', 'HKD'),
    ('OKD', 'KUH'), ('OKD', 'MMB'), ('OKD', 'MSJ'), ('OKD', 'RIS'),
    ('OKD', 'SHB'), ('OKE', 'KOJ'), ('OKE', 'OKA'), ('OKE', 'TKN'),
    ('OKI', 'ITM'), ('OKJ', 'CTS'), ('OKJ', 'HND'), ('OKJ', 'OKA'),
    ('ONJ', 'HND'), ('RIS', 'CTS'), ('RIS', 'OKD'), ('RNJ', 'KOJ'),
    ('RNJ', 'OKA'), ('SDJ', 'CTS'), ('SDJ', 'HIJ'), ('SDJ', 'ITM'),
    ('SDJ', 'NGO'), ('SDJ', 'OKA'), ('SHB', 'CTS'), ('SHB', 'HND'),
    ('SHB', 'OKD'), ('SYO', 'HND'), ('TAK', 'HND'), ('TAK', 'OKA'),
    ('TJH', 'ITM'), ('TKN', 'KOJ'), ('TKN', 'OKE'), ('TKS', 'HND'),
    ('TNE', 'KOJ'), ('TOY', 'CTS'), ('TOY', 'HND'), ('TRA', 'MMY'),
    ('TSJ', 'NGS'), ('TTJ', 'HND'), ('UBJ', 'HND'), ('UEO', 'OKA'),
    ('UKB', 'CTS'), ('UKB', 'HND'), ('UKB', 'OKA'), ('WKJ', 'CTS'),
    ('WKJ', 'HND'), ('YGJ', 'HND'),
]

OUTPUT_FILE = 'missing_routes_miles_v3.csv'

# 既に取得済みの路線をスキップ（両方向）
ALREADY_FETCHED = set()

def get_miles_for_route(dep, arr, browser):
    """JAL時刻表ページから区間マイルを取得"""
    periods = ['20260106_20260228', '20260301_20260328']
    
    for period in periods:
        url = f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep}&arrival={arr}&month={period}"
        
        try:
            page = browser.new_page()
            page.goto(url, timeout=60000)
            page.wait_for_timeout(2500)
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
    # 重複を除去（A→BとB→Aは同じマイル数）
    unique_routes = []
    seen = set()
    for dep, arr in MISSING_ROUTES:
        key = tuple(sorted([dep, arr]))
        if key not in seen:
            seen.add(key)
            unique_routes.append((dep, arr))
    
    print("=" * 60)
    print("JAL 区間マイル取得 v3")
    print(f"対象: {len(unique_routes)}路線（重複除去済み）")
    print("=" * 60)
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        
        results = []
        
        for i, (dep, arr) in enumerate(unique_routes):
            print(f"  [{i+1}/{len(unique_routes)}] {dep} → {arr} ... ", end='', flush=True)
            
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
            
            time.sleep(random.uniform(1, 1.5))
        
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
