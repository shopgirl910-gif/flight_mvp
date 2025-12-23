"""
JAL区間マイル取得スクリプト
不足している路線のマイル数を取得してCSV出力
"""

from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import re

# 不足している路線リスト（先ほどのSQLクエリ結果から）
MISSING_ROUTES = [
    ('AKJ', 'HND'), ('AKJ', 'NGO'), ('AOJ', 'CTS'), ('AOJ', 'ITM'),
    ('ASJ', 'KKX'), ('ASJ', 'KOJ'), ('ASJ', 'RNJ'), ('ASJ', 'TKN'),
    ('AXJ', 'FUK'), ('AXJ', 'KMJ'), ('AXT', 'CTS'), ('AXT', 'HND'),
    ('AXT', 'ITM'), ('AXT', 'NGO'), ('CTS', 'AOJ'), ('CTS', 'AXT'),
    ('CTS', 'FKS'), ('CTS', 'HIJ'), ('CTS', 'HKD'), ('CTS', 'HNA'),
    ('CTS', 'KMQ'), ('CTS', 'KUH'), ('CTS', 'MMB'), ('CTS', 'OKJ'),
    ('CTS', 'SHB'), ('CTS', 'TOY'), ('CTS', 'UKB'), ('CTS', 'WKJ'),
    ('FKS', 'CTS'), ('FKS', 'ITM'), ('FSZ', 'OKA'), ('FUJ', 'FUK'),
    ('FUJ', 'NGS'), ('FUK', 'ASJ'), ('FUK', 'AXJ'), ('FUK', 'FUJ'),
    ('FUK', 'HNA'), ('FUK', 'IZO'), ('FUK', 'KCZ'), ('FUK', 'KMI'),
    ('FUK', 'KMQ'), ('FUK', 'KOJ'), ('FUK', 'KUM'), ('FUK', 'MYJ'),
    ('FUK', 'SDJ'), ('FUK', 'TKS'), ('FUK', 'TSJ'), ('HAC', 'HND'),
    ('HIJ', 'CTS'), ('HIJ', 'HND'), ('HIJ', 'OKA'), ('HIJ', 'SDJ'),
    ('HKD', 'CTS'), ('HKD', 'HND'), ('HKD', 'ITM'), ('HKD', 'NGO'),
    ('HKD', 'OIR'), ('HND', 'ASJ'), ('HND', 'HAC'), ('HND', 'HSG'),
    ('HND', 'IWJ'), ('HND', 'KKJ'), ('HND', 'KMI'), ('HND', 'MBE'),
    ('HND', 'MSJ'), ('HND', 'NTQ'), ('HND', 'ONJ'), ('HND', 'SHB'),
    ('HND', 'SHM'), ('HND', 'SYO'), ('HND', 'UKB'), ('HND', 'WKJ'),
    ('HSG', 'HND'), ('IKI', 'NGS'), ('ISG', 'MMY'), ('ISG', 'NGO'),
    ('ISG', 'OGN'), ('ITM', 'AOJ'), ('ITM', 'ASJ'), ('ITM', 'AXT'),
    ('ITM', 'FKS'), ('ITM', 'GAJ'), ('ITM', 'HKD'), ('ITM', 'HNA'),
    ('ITM', 'IZO'), ('ITM', 'KCZ'), ('ITM', 'KIJ'), ('ITM', 'KMI'),
    ('ITM', 'KUM'), ('ITM', 'MSJ'), ('ITM', 'NRT'), ('ITM', 'OIT'),
    ('IWJ', 'HND'), ('IWK', 'HND'), ('IWK', 'OKA'), ('KCZ', 'HND'),
    ('KCZ', 'ITM'), ('KIJ', 'ITM'), ('KIJ', 'OKA'), ('KIX', 'HND'),
]

OUTPUT_FILE = 'missing_routes_miles.csv'

def get_miles_for_route(dep, arr, browser):
    """JAL時刻表ページから区間マイルを取得"""
    url = f"https://www.jal.co.jp/jp/ja/dom/route/time/timeTable.html?departure={dep}&arrival={arr}&month=20260106_20260228"
    
    try:
        page = browser.new_page()
        page.goto(url, timeout=60000)
        page.wait_for_timeout(3000)
        html = page.content()
        page.close()
        
        soup = BeautifulSoup(html, 'html.parser')
        
        # 「区間マイル：XXXマイル」を探す
        text = soup.get_text()
        match = re.search(r'区間マイル[：:]\s*(\d+)\s*マイル', text)
        
        if match:
            return int(match.group(1))
        
        return None
        
    except Exception as e:
        print(f"  エラー: {e}")
        try:
            page.close()
        except:
            pass
        return None


def main():
    print("=" * 60)
    print("JAL 区間マイル取得")
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
                # 逆方向も追加（マイル数は同じ）
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
