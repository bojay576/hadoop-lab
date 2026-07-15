#!/usr/bin/env python3
"""
实验2: 生成模拟电商访问日志数据
日志格式: timestamp\tuser_id\tproduct_id\taction\tcategory\tduration_sec
"""
import random
import datetime
import sys
import os

# 配置
NUM_RECORDS = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
OUTPUT_FILE = sys.argv[2] if len(sys.argv) > 2 else "/tmp/ecommerce-access.log"

# 模拟数据
ACTIONS = ["view", "click", "cart", "purchase", "search", "favorite"]
CATEGORIES = ["电子产品", "服装", "食品", "图书", "家居", "运动", "美妆", "数码"]

# 生成热门商品 (Zipf 分布模拟)
PRODUCT_IDS = [f"P{str(i).zfill(5)}" for i in range(1, 501)]
USER_IDS = [f"U{str(i).zfill(6)}" for i in range(1, 10001)]

# 搜索关键词
SEARCH_KEYWORDS = [
    "手机", "笔记本", "耳机", "运动鞋", "T恤", "连衣裙",
    "零食", "小说", "台灯", "瑜伽垫", "面膜", "充电宝"
]

def generate_log():
    """生成一条模拟日志记录"""
    # 时间范围: 最近7天
    base_time = datetime.datetime.now() - datetime.timedelta(days=7)
    timestamp = base_time + datetime.timedelta(
        seconds=random.randint(0, 7 * 24 * 3600)
    )

    user_id = random.choice(USER_IDS)
    product_id = random.choices(
        PRODUCT_IDS,
        weights=[1.0 / (i ** 0.5) for i in range(1, len(PRODUCT_IDS) + 1)],
        k=1
    )[0]
    action = random.choices(
        ACTIONS,
        weights=[40, 25, 10, 5, 15, 5],  # view 最多, purchase 最少
        k=1
    )[0]
    category = random.choice(CATEGORIES)
    duration = random.randint(1, 300)

    # 如果是搜索行为，添加搜索关键词
    if action == "search":
        product_id = random.choice(SEARCH_KEYWORDS)

    return f"{timestamp.strftime('%Y-%m-%d %H:%M:%S')}\t{user_id}\t{product_id}\t{action}\t{category}\t{duration}"


def main():
    print(f"生成 {NUM_RECORDS} 条电商访问日志...")
    print(f"输出文件: {OUTPUT_FILE}")

    with open(OUTPUT_FILE, 'w') as f:
        for i in range(NUM_RECORDS):
            f.write(generate_log() + '\n')
            if (i + 1) % 10000 == 0:
                print(f"  已生成 {i + 1}/{NUM_RECORDS} 条记录...")

    file_size = os.path.getsize(OUTPUT_FILE)
    print(f"\n生成完成!")
    print(f"文件: {OUTPUT_FILE}")
    print(f"记录数: {NUM_RECORDS}")
    print(f"文件大小: {file_size / 1024 / 1024:.2f} MB")
    print(f"\n前5条示例数据:")
    with open(OUTPUT_FILE, 'r') as f:
        for i, line in enumerate(f):
            if i >= 5:
                break
            print(f"  {line.strip()}")


if __name__ == "__main__":
    main()
