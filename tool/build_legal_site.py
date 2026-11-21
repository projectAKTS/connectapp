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
<title>{title} · Kindupp</title>
<link rel="icon" type="image/svg+xml" href="https://kindupp.com/favicon.svg">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Kindupp">
<meta property="og:title" content="{title} · Kindupp">
<meta property="og:description" content="Real experience. Human connection.">
<meta property="og:image" content="https://kindupp.com/og-kindupp.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title} · Kindupp">
<meta name="twitter:description" content="Real experience. Human connection.">
<meta name="twitter:image" content="https://kindupp.com/og-kindupp.png">
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
<header><a href="https://kindupp.com/">Kindupp</a></header>
{body}
<footer>
  <a href="https://kindupp.com/privacy/">Privacy draft</a><a href="https://kindupp.com/terms/">Terms draft</a><a href="https://kindupp.com/community-guidelines/">Community guidelines</a>
  <a href="https://kindupp.com/delete-account/">Delete account</a>
  <a href="mailto:{email}">Contact</a>
</footer>
</main>
</body>
</html>
"""


def write(name, title, body):
    (OUT / name).parent.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(PAGE.format(title=html.escape(title), body=body, email=VARS["supportEmail"]))


write("privacy.html", "Privacy Policy (Draft)", markdown(const("privacy")))
write("terms.html", "Terms of Service (Draft)", markdown(const("terms")))
write("safety.html", "Help & safety", markdown(const("safety")) + markdown(const("guidelines")))
write("index.html", "Real help from people who've been there", """
<h1>Real help from people who've been there</h1>
<div class="card">
<p>Kindupp connects people with others who share their own experience.
Ask the community, exchange messages, and arrange free calls.</p>
<p>Members share personal experience. Kindupp is not legal, immigration or
medical advice.</p>
</div>""")
write("delete-account.html", "Delete your account", f"""
<h1>Delete your Kindupp account</h1>
<div class="card">
<h2>In the app</h2>
<p>Open <strong>Settings</strong> and choose <strong>Delete account</strong>.
The app removes the sign-in account and most profile data; some records may
remain as described in the Privacy Policy draft.</p>
<h2>Without the app</h2>
<p>Email <a href="mailto:{VARS["supportEmail"]}?subject=Delete%20my%20Kindupp%20account">{html.escape(VARS["supportEmail"])}</a>
from the address you used to sign up. We will follow up to verify and
process the request; contact support for current status.</p>
</div>
<h2>Data removed through the app flow</h2>
<ul>
<li>Your sign-in account, profile, posts, and related user media</li>
<li>Some profile references, comments, and review text</li>
</ul>
<h2>Records that can remain</h2>
<ul>
<li>Messages/media in another participant's conversation, safety reports, and call records</li>
<li>Consultation/payment records and data retained by providers or backups</li>
</ul>""")
write("stripe/return.html", "Payout setup", """
<h1>You're all set</h1>
<p>Your payout details were sent to Stripe. You can return to the Kindupp app.</p>""")
write("stripe/refresh.html", "Payout setup", """
<h1>Let's try that again</h1>
<p>The setup link expired. Go back to the Kindupp app and open payout setup again.</p>""")
print("built", sorted(str(p.relative_to(OUT)) for p in OUT.rglob("*.html")))
