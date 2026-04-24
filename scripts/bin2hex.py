import sys

inp = sys.argv[1]
out = sys.argv[2]

with open(inp, "rb") as f, open(out, "w") as o:
    while True:
        word = f.read(4)
        if not word:
            break
        val = int.from_bytes(word, "little")
        o.write(f"{val:08x}\n")
