#!/usr/bin/env python3
"""
ODPT APIからJAL時刻表を取得してSQL生成
使い方: python3 odpt_to_sql.py YOUR_ACCESS_TOKEN
"""

import sys
import requests
import json
from datetime import datetime

def fetch_schedules(access_token, operator):
    """ODPT APIからフライトスケジュール全件取得"""
    url = "https://api.odpt.org/api/v4/odpt:FlightSchedule"
    params = {
        "odpt:operator": f"odpt.Operator:{operator}",
        "acl:consumerKey": access_token
    }
    
    print(f"ODPT APIから{operator}時刻表を取得中...")
    response = requests.get(url, params=params)
    
    if response.status_code != 200:
        print(f"エラー: APIリクエスト失敗 (status={response.status_code})")
        print(response.text)
        return None
    
    data = response.json()
    print(f"取得成功: {len(data)}件のフライトデータ")
    
    return data

def extract_airport_code(odpt_airport):
    """ODPT空港IDから空港コードを抽出
    例: odpt.Airport:HND → HND
    """
    if not odpt_airport:
        return None
    return odpt_airport.split(":")[-1]

def extract_time(odpt_time):
    """ODPT時刻形式からHH:MM形式に変換
    例: 06:20:00 → 06:20
    """
    if not odpt_time:
        return None
    return odpt_time[:5]  # HH:MM部分のみ

def get_airline_code(flight_number):
    """便名から航空会社コードを判定"""
    if not flight_number:
        return 'JAL'
    
    # JL175, NH123 → 175, 123 のように数字部分だけ抽出
    import re
    
    # プレフィックス取得（JL, NH等）
    prefix_match = re.match(r'^([A-Z]+)', flight_number)
    prefix = prefix_match.group(1) if prefix_match else ''
    
    # 数字部分抽出
    num_match = re.search(r'\d+', flight_number)
    if not num_match:
        return 'JAL' if prefix == 'JL' else 'ANA'
    
    num = int(num_match.group())
    
    # JAL系
    if prefix == 'JL':
        if 2700 <= num <= 2799 or 3400 <= num <= 3499:
            return 'HAC'  # 北海道エアシステム
        elif num >= 4000:
            return 'JAC'  # J-AIR or FDA
        elif 600 <= num <= 699:
            return 'JTA'  # 日本トランスオーシャン航空
        elif 720 <= num <= 799:
            return 'RAC'  # 琉球エアコミューター
        else:
            return 'JAL'
    
    # ANA系
    elif prefix == 'NH':
        if 3700 <= num <= 3899:
            return 'SNA'  # ソラシドエア
        elif 4700 <= num <= 4999:
            return 'ADO'  # エア・ドゥ
        elif num >= 7000:
            return 'SFJ'  # スターフライヤー
        else:
            return 'ANA'
    
    # その他
    else:
        return 'ANA' if prefix == 'NH' else 'JAL'

def filter_flights(schedules, start_date, end_date):
    """期間内のフライトをフィルタ"""
    filtered = []
    
    for schedule in schedules:
        # 出発地・到着地取得
        origin = extract_airport_code(schedule.get("odpt:originAirport"))
        destination = extract_airport_code(schedule.get("odpt:destinationAirport"))
        
        if not origin or not destination:
            continue
        
        # flightScheduleObjectの配列をループ
        flight_objects = schedule.get("odpt:flightScheduleObject", [])
        
        for flight_obj in flight_objects:
            # 運航期間チェック
            valid_from = flight_obj.get("odpt:isValidFrom", "")[:10]  # YYYY-MM-DD
            valid_to = flight_obj.get("odpt:isValidTo", "")[:10]
            
            # 開始日以降の便のみ
            if valid_to and valid_to < start_date:
                continue  # 終了日が開始日より前
            
            # 便名取得（配列の最初の要素）
            flight_number_list = flight_obj.get("odpt:flightNumber", [])
            if not flight_number_list or len(flight_number_list) == 0:
                continue
            flight_number = flight_number_list[0]
            
            # 時刻取得
            dep_time = extract_time(flight_obj.get("odpt:originTime"))
            arr_time = extract_time(flight_obj.get("odpt:destinationTime"))
            
            if not dep_time or not arr_time:
                continue
            
            # 航空会社コード判定
            airline = get_airline_code(flight_number)
            
            filtered.append({
                'airline': airline,
                'flight_number': flight_number,
                'departure': origin,
                'arrival': destination,
                'dep_time': dep_time,
                'arr_time': arr_time,
                'valid_from': valid_from or start_date,
                'valid_to': valid_to or '2099-12-31'
            })
    
    return filtered

def generate_sql(flights, period_start, period_end):
    """SQL INSERT文を生成"""
    
    # 重複除去（便名+出発時刻+出発地+到着地でユニーク）
    unique_flights = {}
    for f in flights:
        key = f"{f['flight_number']}_{f['dep_time']}_{f['departure']}_{f['arrival']}"
        if key not in unique_flights:
            unique_flights[key] = f
    
    flights = list(unique_flights.values())
    flights.sort(key=lambda x: (x['departure'], x['arrival'], x['flight_number']))
    
    sql_lines = [
        "-- =====================================================",
        f"-- JAL + ANA 国内線全路線 {period_start}以降 時刻表",
        f"-- ODPT APIから取得: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"-- 取得便数: {len(flights)}便",
        "-- =====================================================",
        "",
        "-- 既存データを無効化",
        "UPDATE schedules",
        "SET is_active = false",
        "WHERE airline_code IN ('JAL', 'JTA', 'RAC', 'JAC', 'HAC', 'ANA', 'ADO', 'SNA', 'SFJ')",
        f"  AND period_start >= '{period_start}';",
        "",
        "-- 新規データ挿入",
        "INSERT INTO schedules (",
        "  airline_code,",
        "  flight_number,",
        "  departure_code,",
        "  arrival_code,",
        "  departure_time,",
        "  arrival_time,",
        "  is_active,",
        "  period_start,",
        "  period_end",
        ")",
        "VALUES"
    ]
    
    # VALUES部分
    values = []
    for f in flights:
        values.append(
            f"('{f['airline']}', '{f['flight_number']}', "
            f"'{f['departure']}', '{f['arrival']}', "
            f"'{f['dep_time']}', '{f['arr_time']}', "
            f"true, '{f['valid_from']}', '{f['valid_to']}')"
        )
    
    sql_lines.append(",\n".join(values) + ";")
    
    # 統計情報
    sql_lines.extend([
        "",
        "-- =====================================================",
        "-- 航空会社別便数:",
    ])
    
    airline_count = {}
    for f in flights:
        airline_count[f['airline']] = airline_count.get(f['airline'], 0) + 1
    
    for airline, count in sorted(airline_count.items()):
        sql_lines.append(f"-- {airline}: {count}便")
    
    sql_lines.extend([
        "",
        "-- 路線別便数（上位20路線）:",
    ])
    
    route_count = {}
    for f in flights:
        route = f"{f['departure']}-{f['arrival']}"
        route_count[route] = route_count.get(route, 0) + 1
    
    for route, count in sorted(route_count.items(), key=lambda x: x[1], reverse=True)[:20]:
        sql_lines.append(f"-- {route}: {count}便")
    
    sql_lines.append("-- =====================================================")
    
    return "\n".join(sql_lines)

def main():
    if len(sys.argv) < 2:
        print("使い方: python3 odpt_to_sql.py YOUR_ACCESS_TOKEN")
        print("例: python3 odpt_to_sql.py abcd1234efgh5678")
        sys.exit(1)
    
    access_token = sys.argv[1]
    period_start = "2026-03-29"
    period_end = "2099-12-31"  # 終了日制限なし
    
    all_flights = []
    
    # 1. JALデータ取得
    print("\n=== JAL ===")
    jal_schedules = fetch_schedules(access_token, "JAL")
    if jal_schedules:
        jal_flights = filter_flights(jal_schedules, period_start, period_end)
        print(f"JAL該当便数: {len(jal_flights)}便")
        all_flights.extend(jal_flights)
    
    # 2. ANAデータ取得
    print("\n=== ANA ===")
    ana_schedules = fetch_schedules(access_token, "ANA")
    if ana_schedules:
        ana_flights = filter_flights(ana_schedules, period_start, period_end)
        print(f"ANA該当便数: {len(ana_flights)}便")
        all_flights.extend(ana_flights)
    
    print(f"\n合計: {len(all_flights)}便")
    
    if not all_flights:
        print("エラー: 該当するフライトが見つかりませんでした")
        sys.exit(1)
    
    # 3. SQL生成
    sql = generate_sql(all_flights, period_start, period_end)
    
    # 4. ファイル保存
    output_file = f"jal_ana_all_{period_start}_onwards.sql"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(sql)
    
    print(f"\nSQLファイル生成完了: {output_file}")
    print("\n最初の5件:")
    for flight in all_flights[:5]:
        print(f"  {flight['airline']} {flight['flight_number']}: "
              f"{flight['departure']}->{flight['arrival']} "
              f"{flight['dep_time']}-{flight['arr_time']}")



if __name__ == '__main__':
    main()
