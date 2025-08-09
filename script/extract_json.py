#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从SQLite数据库中提取JSON数据并按照mode分类保存
"""

import sqlite3
import json
import os
import sys
from pathlib import Path


def extract_json_data(db_path):
    """
    从数据库中提取JSON数据并按照mode分类保存

    Args:
        db_path (str): 数据库文件路径
    """
    if not os.path.exists(db_path):
        print(f"错误：数据库文件 '{db_path}' 不存在")
        return

    try:
        # 连接到数据库
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        print(f"=== 开始提取JSON数据: {db_path} ===\n")

        # 获取detail表的所有数据
        cursor.execute("SELECT id, mode, detail FROM detail")
        rows = cursor.fetchall()

        if not rows:
            print("detail表中没有找到任何数据")
            return

        print(f"找到 {len(rows)} 条记录\n")

        # 创建目录
        salmon_run_dir = Path("salmon_run")
        battle_dir = Path("battle")

        salmon_run_dir.mkdir(exist_ok=True)
        battle_dir.mkdir(exist_ok=True)

        # 统计信息
        salmon_run_count = 0
        battle_count = 0
        error_count = 0

        # 处理每一行数据
        for i, (id_val, mode, detail_json) in enumerate(rows, 1):
            try:
                # 解析JSON
                detail_data = json.loads(detail_json)

                # 根据mode分类
                if mode == "salmon_run":
                    # 保存到salmon_run目录
                    output_dir = salmon_run_dir
                    filename = f"{id_val}.json"
                    salmon_run_count += 1
                else:
                    # 保存到battle目录，包装在vsHistoryDetail中
                    output_dir = battle_dir
                    filename = f"{id_val}.json"
                    # 包装数据
                    detail_data = {"vsHistoryDetail": detail_data}
                    battle_count += 1

                # 保存JSON文件
                output_path = output_dir / filename
                with open(output_path, 'w', encoding='utf-8') as f:
                    json.dump(detail_data, f, ensure_ascii=False, indent=2)

                if i % 100 == 0:
                    print(f"已处理 {i}/{len(rows)} 条记录...")

            except json.JSONDecodeError as e:
                print(f"JSON解析错误 (ID: {id_val}): {e}")
                error_count += 1
            except Exception as e:
                print(f"处理错误 (ID: {id_val}): {e}")
                error_count += 1

        conn.close()

        # 输出统计信息
        print(f"\n=== 提取完成 ===")
        print(f"总记录数: {len(rows)}")
        print(f"salmon_run 模式: {salmon_run_count} 条")
        print(f"battle 模式: {battle_count} 条")
        print(f"错误数: {error_count} 条")
        print(f"\n文件保存位置:")
        print(f"- salmon_run 模式: {salmon_run_dir.absolute()}")
        print(f"- battle 模式: {battle_dir.absolute()}")

        # 显示一些示例文件
        if salmon_run_count > 0:
            salmon_files = list(salmon_run_dir.glob("*.json"))[:3]
            print(f"\nsalmon_run 示例文件:")
            for file in salmon_files:
                print(f"  - {file.name}")

        if battle_count > 0:
            battle_files = list(battle_dir.glob("*.json"))[:3]
            print(f"\nbattle 示例文件:")
            for file in battle_files:
                print(f"  - {file.name}")

    except sqlite3.Error as e:
        print(f"数据库错误: {e}")
    except Exception as e:
        print(f"发生错误: {e}")


def main():
    """主函数"""
    # 默认数据库路径
    default_db = "conch-bay.db"

    if len(sys.argv) > 1:
        db_path = sys.argv[1]
    else:
        # 检查当前目录是否有数据库文件
        if os.path.exists(default_db):
            db_path = default_db
        else:
            print("用法: python extract_json.py [数据库文件路径]")
            print(f"或者将数据库文件放在当前目录，命名为 '{default_db}'")
            return

    extract_json_data(db_path)


if __name__ == "__main__":
    main()
