"""
JAL区間マイル取得 - 最終版
残り29路線を取得
"""

from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import csv
import time
import random
import re

# 残り29路線
MISSING_ROUTES = [
    ('AOJ', 'NGO'), ('AXT', 'CTS'), ('CTS', 'AXT'), ('CTS', 'HKD'),
    ('CTS', 'KUH'), ('CTS', 'MSJ'), ('CTS', 'RIS'), ('CTS', 'SHB'),
    ('GAJ', 'NGO'), ('HKD', 'CTS'), ('HNA', 'NGO'), ('ISG', 'ITM'),
    ('ITM', 'ISG'), ('ITM', 'MMJ'), ('ITM', 'MMY'), ('KIJ', 'NGO'),
    ('KMJ', 'NGO'), ('KUH', 'CTS'), ('MMJ', 'ITM'), ('MMY', 'ITM'),
    ('MSJ', 'CTS'), ('MYJ', 'KOJ'), ('NGO', 'AOJ'), ('NGO', 'GAJ'),
    ('NGO', 'HNA'), ('NGO', 'KIJ'), ('NGO', 'KMJ'), ('RIS', 'CTS'),
    ('SHB', 'CTS'),
]

OUTPUT_FILE = 'jal_final_miles.csv'

def get_miles_for_route(dep, arr, browser):
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
    # 重複除去
    unique_routes = []
    seen = set()
    for dep, arr in MISSING_ROUTES:
        key = tuple(sorted([dep, arr]))
        if key not in seen:
            seen.add(key)
            unique_routes.append((dep, arr))
    
    print("=" * 60)
    print("JAL 区間マイル取得 - 最終版")
    print(f"対象: {len(unique_routes)}路線")
    print("=" * 60)
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        
        results = []
        
        for i, (dep, arr) in enumerate(unique_routes):
            print(f"  [{i+1}/{len(unique_routes)}] {dep} → {arr} ... ", end='', flush=True)
            
            miles = get_miles_for_route(dep, arr, browser)
            
            if miles:
                print(f"{miles}マイル")
                results.append({'departure_code': dep, 'arrival_code': arr, 'distance_miles': miles})
                results.append({'departure_code': arr, 'arrival_code': dep, 'distance_miles': miles})
            else:
                print("取得失敗")
            
            time.sleep(random.uniform(1, 1.5))
        
        browser.close()
    
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['departure_code', 'arrival_code', 'distance_miles'])
        writer.writeheader()
        writer.writerows(results)
    
    print(f"\n完了！ {OUTPUT_FILE} に{len(results)}件出力")


if __name__ == '__main__':
    main()
