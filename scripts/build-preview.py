"""Bundle index.html + demo config into one self-contained preview page (dist/preview.html)."""
import pathlib, re
root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "index.html").read_text()
app = src.split("<!--APP-START-->", 1)[1].split("<!--APP-END-->", 1)[0]
app = app.replace("</head>\n<body>\n", "", 1)
cfg = '<script>window.WINE_CONFIG={supabaseUrl:"",supabaseAnonKey:"",birthdayName:"Tim",eventLabel:"Birthday Blind Tasting"};</script>\n'
title, rest = re.match(r"\s*(<title>.*?</title>\n)(.*)", app, re.S).groups()
out = root / "dist" / "preview.html"
out.parent.mkdir(exist_ok=True)
out.write_text(title + cfg + rest)
print(out)
