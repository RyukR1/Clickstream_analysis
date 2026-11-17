import argparse
import random
from datetime import date, datetime, timedelta
from pathlib import Path

PAGES = (
    ("/index.html", 18),
    ("/products/laptop", 14),
    ("/products/phone", 13),
    ("/products/tablet", 8),
    ("/search", 7),
    ("/cart", 9),
    ("/checkout", 5),
    ("/payment", 3),
    ("/order-confirmation", 2),
    ("/account", 4),
    ("/support", 3),
    ("/about", 2),
    ("/blog", 3),
)
ASSETS = (
    "/css/style.css",
    "/js/app.js",
    "/images/logo.png",
    "/images/banner.jpg",
    "/images/product1.jpg",
    "/images/product2.jpg",
    "/favicon.ico",
)
HOUR_WEIGHTS = (1, 1, 1, 1, 1, 2, 3, 5, 7, 8, 9, 9, 9, 9, 8, 8, 8, 9, 10, 10, 9, 6, 3, 2)
BOT_IPS = ("203.0.113.7", "203.0.113.8", "198.51.100.23", "198.51.100.99", "192.0.2.44")
BAD_LINES = (
    "-- truncated --",
    '10.0.0.1 - - [not-a-date] "GET /index.html HTTP/1.1" 200 512',
    '10.0.0.2 - - [06/Apr/2026:10:00:01 +0000] "GET /cart HTTP/1.1" abc 512',
    "garbage line with no structure",
    '10.0.0.3 - - [32/Foo/2026:99:99:99 +0000] "GET /cart HTTP/1.1" 200 512',
)


def make_ip_pool(rng, size):
    return [
        f"{rng.choice((10, 172, 192, 34, 52, 82, 103))}.{rng.randrange(256)}.{rng.randrange(256)}.{rng.randrange(1, 255)}"
        for _ in range(size)
    ]


def format_line(ip, ts, method, path, status, size):
    stamp = ts.strftime("%d/%b/%Y:%H:%M:%S +0000")
    return f'{ip} - - [{stamp}] "{method} {path} HTTP/1.1" {status} {size}'


def build_event(rng, ts, ips, pages, page_weights, bot_share):
    if rng.random() < bot_share:
        ip = rng.choice(BOT_IPS)
        path = rng.choice(PAGES)[0]
        return format_line(ip, ts, "GET", path, 200, rng.randint(500, 9000))
    ip = rng.choice(ips)
    roll = rng.random()
    if roll < 0.24:
        return format_line(ip, ts, "GET", rng.choice(ASSETS), 200, rng.randint(200, 80000))
    if roll < 0.28:
        return format_line(ip, ts, "GET", "/admin/login.php", 404, 0)
    if roll < 0.30:
        return format_line(ip, ts, "GET", rng.choice(pages), 500, rng.randint(100, 900))
    if roll < 0.33:
        return format_line(ip, ts, "GET", rng.choice(pages), 304, 0)
    path = rng.choices(pages, page_weights)[0]
    method = "POST" if path in ("/payment", "/checkout") and rng.random() < 0.5 else "GET"
    return format_line(ip, ts, method, path, 200, rng.randint(1000, 50000))


def generate(path, rows, days, start, seed, bad_rate, bot_share, unique_ips):
    rng = random.Random(seed)
    ips = make_ip_pool(rng, unique_ips)
    pages = [p for p, _ in PAGES]
    page_weights = [w for _, w in PAGES]
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    per_day = rows // days
    written = 0
    with out.open("w") as handle:
        for offset in range(days):
            day = datetime.combine(start + timedelta(days=offset), datetime.min.time())
            count = per_day + (rows - per_day * days if offset == days - 1 else 0)
            hours = rng.choices(range(24), HOUR_WEIGHTS, k=count)
            stamps = sorted(
                day + timedelta(hours=h, minutes=rng.randrange(60), seconds=rng.randrange(60))
                for h in hours
            )
            for ts in stamps:
                if rng.random() < bad_rate:
                    handle.write(rng.choice(BAD_LINES) + "\n")
                else:
                    handle.write(build_event(rng, ts, ips, pages, page_weights, bot_share) + "\n")
                written += 1
    return written


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Generate synthetic Apache access logs")
    parser.add_argument("--out", required=True)
    parser.add_argument("--rows", type=int, default=100_000)
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--start-date", type=date.fromisoformat, default=date(2026, 4, 6))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--bad-rate", type=float, default=0.01)
    parser.add_argument("--bot-share", type=float, default=0.03)
    parser.add_argument("--unique-ips", type=int, default=5000)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    written = generate(
        args.out, args.rows, args.days, args.start_date, args.seed,
        args.bad_rate, args.bot_share, args.unique_ips,
    )
    print(f"wrote {written} lines to {args.out}")


if __name__ == "__main__":
    main()
