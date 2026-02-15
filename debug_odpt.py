#!/usr/bin/env python3
"""
ODPT APIデバッグ - 取得データの詳細確認
"""

import sys
import requests
import json

def fetch_and_analyze(access_token):
    url = "https://api.odpt.org/api/v4/odpt:FlightSchedule"
    params = {
        "odpt:operator": "odpt.Operator:JAL",
        "odpt:originAirport": "odpt.Airport:HND",
        "acl:consumerKey": access_token
    }
    
    print("データ取得中...")
    response = requests.get(url, params=params)
    
    if response.status_code != 200:
        print(f"エラー: {response.status_code}")
        return
    
    data = response.json()
    print(f"取得件数: {len(data)}件\n")
    
    # 最初の3件を詳細表示
    print("=== 最初の3件の詳細 ===")
    for i, schedule in enumerate(data[:3]):
        print(f"\n[{i+1}件目]")
        print(f"  originAirport: {schedule.get('odpt:originAirport')}")
        print(f"  destinationAirport: {schedule.get('odpt:destinationAirport')}")
        
        # flightScheduleObjectの中身を確認
        objs = schedule.get('odpt:flightScheduleObject', [])
        print(f"  フライト数: {len(objs)}個")
        
        for j, obj in enumerate(objs[:2]):  # 最初の2個だけ
            print(f"\n  [フライト {j+1}]")
            print(f"    flightNumber: {obj.get('odpt:flightNumber')}")
            print(f"    originTime: {obj.get('odpt:originTime')}")
            print(f"    destinationTime: {obj.get('odpt:destinationTime')}")
            print(f"    isValidFrom: {obj.get('odpt:isValidFrom')}")
            print(f"    isValidTo: {obj.get('odpt:isValidTo')}")
    
    # 運航期間の統計
    print("\n\n=== 運航期間の統計 ===")
    periods = {}
    for schedule in data:
        objs = schedule.get('odpt:flightScheduleObject', [])
        for obj in objs:
            valid_from = obj.get('odpt:isValidFrom', '')[:10]
            valid_to = obj.get('odpt:isValidTo', '')[:10]
            period = f"{valid_from} 〜 {valid_to}"
            periods[period] = periods.get(period, 0) + 1
    
    for period, count in sorted(periods.items())[:10]:
        print(f"  {period}: {count}便")
    
    if len(periods) > 10:
        print(f"  ...他 {len(periods)-10}期間")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("使い方: python3 debug_odpt.py YOUR_ACCESS_TOKEN")
        sys.exit(1)
    
    fetch_and_analyze(sys.argv[1])
