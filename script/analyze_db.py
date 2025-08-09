#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SQLite数据库结构分析脚本
用于查看数据库的表结构、列信息、索引等
"""

import sqlite3
import os
import sys
from pathlib import Path


def analyze_database(db_path):
    """
    分析SQLite数据库结构

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

        print(f"=== 数据库结构分析: {db_path} ===\n")

        # 获取所有表名
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()

        if not tables:
            print("数据库中没有找到任何表")
            return

        print(f"发现 {len(tables)} 个表:\n")

        # 分析每个表
        for i, (table_name,) in enumerate(tables, 1):
            print(f"{i}. 表名: {table_name}")

            # 获取表结构信息
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns = cursor.fetchall()

            print("   列信息:")
            for col in columns:
                col_id, col_name, col_type, not_null, default_val, pk = col
                pk_info = " (主键)" if pk else ""
                not_null_info = " NOT NULL" if not_null else ""
                default_info = f" DEFAULT {default_val}" if default_val else ""
                print(
                    f"     - {col_name}: {col_type}{not_null_info}{default_info}{pk_info}")

            # 获取表的行数
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            row_count = cursor.fetchone()[0]
            print(f"    行数: {row_count}")

            # 获取索引信息
            cursor.execute(f"PRAGMA index_list({table_name})")
            indexes = cursor.fetchall()

            if indexes:
                print("   索引:")
                for idx in indexes:
                    idx_name = idx[1]
                    cursor.execute(f"PRAGMA index_info({idx_name})")
                    idx_columns = cursor.fetchall()
                    col_names = [col[2] for col in idx_columns]
                    print(f"     - {idx_name}: {', '.join(col_names)}")

            # 获取表的创建语句
            cursor.execute(
                f"SELECT sql FROM sqlite_master WHERE type='table' AND name='{table_name}'")
            create_sql = cursor.fetchone()
            if create_sql and create_sql[0]:
                print("   创建语句:")
                print(f"     {create_sql[0]}")

            print()

        # 获取数据库统计信息
        print("=== 数据库统计信息 ===")
        total_tables = len(tables)
        total_rows = 0

        for (table_name,) in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            row_count = cursor.fetchone()[0]
            total_rows += row_count

        print(f"总表数: {total_tables}")
        print(f"总行数: {total_rows}")

        # 获取数据库文件大小
        file_size = os.path.getsize(db_path)
        print(f"数据库文件大小: {file_size:,} 字节 ({file_size/1024:.2f} KB)")

        conn.close()

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
            print("用法: python analyze_db.py [数据库文件路径]")
            print(f"或者将数据库文件放在当前目录，命名为 '{default_db}'")
            return

    analyze_database(db_path)


if __name__ == "__main__":
    main()
