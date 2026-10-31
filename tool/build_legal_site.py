#!/usr/bin/env python3
"""Builds the public/ legal pages from lib/config/legal_texts.dart.

Run after editing the in-app texts so the website stays identical:
    python3 tool/build_legal_site.py
"""
import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / "lib/config/legal_texts.dart").read_text()
OUT = ROOT / "public"


def const(name):
    m = re.search(r"static const String " + name + r" = '''\n(.*?)''';", SRC, re.S)
    if m:
        return m.group(1)
    m = re.search(r"static const String " + name + r" = '([^']*)';", SRC)
    return m.group(1)


VARS = {"supportEmail": const("supportEmail"), "lastUpdated": const("lastUpdated")}


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\w)_(.+?)_(?!\w)", r"<em>\1</em>", text)
    email = html.escape(VARS["supportEmail"])
    return text.replace(email, f'<a href="mailto:{email}">{email}</a>')


def markdown(md):
    md = md.replace("${lastUpdated}", VARS["lastUpdated"]).replace("$supportEmail", VARS["supportEmail"])
    out, para, items = [], [], []

    def flush():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()

    for line in md.splitlines():
        s = line.rstrip()
        if not s.strip():
            flush()
        elif s.startswith("### "):
            flush(); out.append(f"<h3>{inline(s[4:])}</h3>")
        elif s.startswith("## "):
            flush(); out.append(f"<h2>{inline(s[3:])}</h2>")
        elif s.startswith("- "):
            if para:
                flush()
            items.append(s[2:])
        elif s.startswith("  ") and items:
            items[-1] += " " + s.strip()
        else:
            para.append(s.strip())
    flush()
    return "\n".join(out)


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Helperly</title>
<style>
  body {{ margin: 0; background: #ffffff; color: #2D2C2B;
    font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }}
  main {{ max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }}
  header a {{ color: #0F4C46; font-weight: 700; text-decoration: none; font-size: 20px; }}
  h1, h2, h3 {{ line-height: 1.25; }}
  h2 {{ margin-top: 28px; }}
  a {{ color: #0F4C46; }}
  .card {{ background: #FBFAF8; border: 1px solid #EFEAE3; border-radius: 16px; padding: 20px; }}
  footer {{ margin-top: 40px; color: #757370; font-size: 14px; }}
  footer a {{ margin-right: 16px; }}
</style>
</head>
<body>
<main>
<header><a href="/">Helperly</a></header>
{body}
<footer>
  <a href="/privacy.html">Privacy</a><a href="/terms.html">Terms</a><a href="/safety.html">Safety</a>
  <a href="/delete-account.html">Delete account</a>
  <a href="mailto:{email}">Contact</a>
</footer>
</main>
</body>
</html>
"""


def write(name, title, body):
    (OUT / name).parent.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(PAGE.format(title=html.escape(title), body=body, email=VARS["supportEmail"]))


write("privacy.html", "Privacy Policy", markdown(const("privacy")))
write("terms.html", "Terms of Use", markdown(const("terms")))
write("safety.html", "Help & safety", markdown(const("safety")) + markdown(const("guidelines")))
write("index.html", "Real help from people who've been there", """
<h1>Real help from people who've been there</h1>
<div class="card">
<p>Helperly connects newcomers to Canada with people who share their own
experience: settling in, finding housing and work, student life and more.
Ask the community, message helpers, or book a short call.</p>
<p>Helpers share personal experience. Helperly is not legal, immigration or
medical advice.</p>
</div>""")
write("delete-account.html", "Delete your account", f"""
<h1>Delete your Helperly account</h1>
<div class="card">
<h2>In the app</h2>
<p>Open <strong>Profile</strong>, tap the <strong>settings</strong> icon, then
<strong>Delete account</strong>. Your account is deleted right away.</p>
<h2>Without the app</h2>
<p>Email <a href="mailto:{VARS["supportEmail"]}?subject=Delete%20my%20Helperly%20account">{html.escape(VARS["supportEmail"])}</a>
from the address you signed up with and ask us to delete your account. We
confirm and delete it within 30 days.</p>
</div>
<h2>What is deleted</h2>
<ul>
<li>Your profile, photos, posts and comments</li>
<li>Your sign-in account and notification settings</li>
</ul>
<h2>What we keep</h2>
<ul>
<li>Payment records we must keep by law</li>
<li>Messages you already sent, which stay in the other person's conversation</li>
</ul>""")
write("stripe/return.html", "Payout setup", """
<h1>You're all set</h1>
<p>Your payout details were sent to Stripe. You can return to the Helperly app.</p>""")
write("stripe/refresh.html", "Payout setup", """
<h1>Let's try that again</h1>
<p>The setup link expired. Go back to the Helperly app and open payout setup again.</p>""")
print("built", sorted(str(p.relative_to(OUT)) for p in OUT.rglob("*.html")))
