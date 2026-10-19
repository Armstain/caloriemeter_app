#!/usr/bin/env python3
"""Scrape DAM (Department of Agricultural Marketing) daily Dhaka market prices.

Fetches https://dam.gov.bd/, parses the retail + wholesale price sections from
the page text, and writes data/prices.json. Designed to run as a daily GitHub
Action; keeps the previous file untouched when the scrape fails or looks wrong.

Exit codes: 0 = wrote fresh prices.json, 2 = kept previous file (nothing written).
"""

import json
import re
import sys
from datetime import date
from pathlib import Path

import requests
from bs4 import BeautifulSoup

DAM_URL = "https://dam.gov.bd/"
MIN_ITEMS_PER_SECTION = 20  # sanity gate: we track ~23 of the ~35 listed items
# The protein guide is useless without these; fail loudly if any are missing.
CRITICAL_ITEMS = {"egg_farm", "chicken_broiler", "fish_rui", "lentil_coarse", "chickpea"}

BN_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")


def bn_to_ascii(s: str) -> str:
    return s.translate(BN_DIGITS)


# Bangla item name (as it appears on dam.gov.bd) -> stable English id + unit.
# Unit: "kg" | "litre" | "piece" | "4pcs". Kept deliberately small: only items
# the protein guide / food DB actually needs get an id; unknown items are
# skipped (not fatal).
ITEM_MAP = {
    "চাল স্বর্না-মোটা": ("rice_coarse", "kg"),
    "পাজাম, ব্রি ধান ২৮, ব্রি ধান ২৯ - মাঝারি": ("rice_medium", "kg"),
    "জিরাশাইল-শম্পা কাটারি (সরু)": ("rice_fine", "kg"),
    "ব্রি ধান ৩৪ - সুগন্ধী": ("rice_aromatic", "kg"),
    "আটা-খোলা": ("flour_loose", "kg"),
    "মসুর - মোটা": ("lentil_coarse", "kg"),
    "মুগ -মোটা": ("mung_coarse", "kg"),
    "ছোলা": ("chickpea", "kg"),
    "সয়াবিন-খোলা": ("soybean_oil_loose", "litre"),
    "সয়াবিন-খোলা": ("soybean_oil_loose", "litre"),  # site spelling varies
    "পামওয়েল - খোলা": ("palm_oil_loose", "litre"),
    "পামওয়েল - খোলা": ("palm_oil_loose", "litre"),
    "সয়াবিন - ১ লিটার বোতল": ("soybean_oil_bottled", "litre"),
    "সয়াবিন - ১ লিটার বোতল": ("soybean_oil_bottled", "litre"),
    "চিনি - আমদানীকৃত(সাদা-খোলা)": ("sugar", "kg"),
    "পেঁয়াজ - দেশী": ("onion_local", "kg"),
    "পেঁয়াজ - দেশী": ("onion_local", "kg"),
    "মাছ - রুই(১.৫ কেজি হতে ৪ কেজি)": ("fish_rui", "kg"),
    "মাছ - কাতল(১.৫ কেজি হতে ৪ কেজি)": ("fish_katla", "kg"),
    "মাছ - পাঙ্গাস(চাষের)": ("fish_pangas", "kg"),
    "মাছ - তেলাপিয়া(চাষের)": ("fish_tilapia", "kg"),
    "মাছ - তেলাপিয়া(চাষের)": ("fish_tilapia", "kg"),
    "মোরগ/মুরগী - ব্রয়লার": ("chicken_broiler", "kg"),
    "মোরগ/মুরগী - ব্রয়লার": ("chicken_broiler", "kg"),
    "মোরগ/মুরগী - কক/সোনালী": ("chicken_sonali", "kg"),
    "মাংস - গরু": ("beef", "kg"),
    "মাংস - ছাগল": ("mutton_goat", "kg"),
    "ডিম - ফার্ম সাদা/লাল": ("egg_farm", "piece"),
    "ফল - কলা(সাগর)": ("banana_sagor", "4pcs"),
}

SECTION_RE = re.compile(
    r"ঢাকা মহানগরীর আজকের \((\d{2}-\d{2}-\d{4})\) তারিখের বাজারদর \((খুচরা|পাইকারি)\):"
)
ITEM_RE = re.compile(
    r"(.+?)\(([^)]+)\)\s*:\s*([\d০-৯.,]+)\s*-\s*([\d০-৯.,]+)"
)


def parse_number(s: str) -> float:
    return float(bn_to_ascii(s).replace(",", "").strip())


def parse_section(text: str, section: str):
    """Parse one price section; returns (report_date, {item_id: {...}})."""
    matches = [m for m in SECTION_RE.finditer(text) if m.group(2) == section]
    if not matches:
        return None, {}
    match = matches[0]
    report_date = match.group(1)
    # Section runs until the next section header or end of price block.
    start = match.end()
    next_header = SECTION_RE.search(text, start)
    block = text[start:next_header.start() if next_header else start + 6000]
    items = {}
    for chunk in block.split("|"):
        chunk = chunk.strip()
        if not chunk:
            continue
        m = ITEM_RE.match(chunk)
        if not m:
            continue
        name_bn, unit_bn, low, high = (g.strip() for g in m.groups())
        key = ITEM_MAP.get(name_bn)
        if not key:
            continue  # not an item we track; skip quietly
        item_id, unit = key
        lo, hi = parse_number(low), parse_number(high)
        items[item_id] = {
            "name_bn": name_bn,
            "unit": unit,
            "min": lo,
            "max": hi,
            "mid": round((lo + hi) / 2, 2),
        }
    return report_date, items


def scrape(page_text: str = None):
    if page_text is None:
        resp = requests.get(
            DAM_URL, timeout=30, headers={"User-Agent": "Mozilla/5.0 (Caloriemeter price bot)"}
        )
        resp.raise_for_status()
        soup = BeautifulSoup(resp.text, "html.parser")
        page_text = soup.get_text(" ", strip=True)
    retail_date, retail = parse_section(page_text, "খুচরা")
    wholesale_date, wholesale = parse_section(page_text, "পাইকারি")
    if not retail or len(retail) < MIN_ITEMS_PER_SECTION:
        raise ValueError(f"retail parse failed: got {len(retail)} items")
    if not wholesale or len(wholesale) < MIN_ITEMS_PER_SECTION:
        raise ValueError(f"wholesale parse failed: got {len(wholesale)} items")
    missing = CRITICAL_ITEMS - set(retail)
    if missing:
        raise ValueError(f"critical items missing from retail: {sorted(missing)}")
    return {
        "source": "dam.gov.bd",
        "report_date": bn_to_ascii(retail_date),  # date printed on the DAM page
        "scraped_at": date.today().isoformat(),
        "note_bn": "ঢাকা মহানগরীর খুচরা ও পাইকারি বাজারদর",
        "retail": retail,
        "wholesale": wholesale,
    }


def main() -> int:
    out_path = Path(__file__).resolve().parents[2] / "data" / "prices.json"
    try:
        data = scrape()
    except Exception as e:  # network down, markup changed, etc.
        print(f"SCRAPE FAILED ({e}); keeping previous prices.json", file=sys.stderr)
        return 2
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {out_path} ({len(data['retail'])} retail items, date {data['report_date']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
