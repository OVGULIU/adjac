"""
generate.py SRC DST
"""
import sys
import os
import argparse
try:
    import tempita
except ImportError:
    import Cython.Tempita as tempita


def define_symbol(string):
    try:
        key, value = string.split('=', 1)
        return key, eval(value)
    except:
        raise argparse.ArgumentError("%r is not of the form key=value" % (string,))


def main():
    p = argparse.ArgumentParser(usage=__doc__.strip())
    p.add_argument('-D', '--define', type=define_symbol, action="append", default=[],
                   metavar="NAME=VALUE", help="define a symbol in template")
    p.add_argument('src')
    p.add_argument('dst')
    args = p.parse_args()

    defines = dict(args.define)
    process(args.src, args.dst, defines)


def process(src, dst, defines):
    with open(src, 'r') as f:
        text = f.read()
        tmpl = tempita.Template(text)
        out = tmpl.substitute(defines)

    src = os.path.basename(src)
    with open(dst, 'w') as f:
        if dst.endswith('.f95'):
            f.write("!! NOTE: this file is autogenerated from {}: do not edit manually\n".format(src))
        else:
            f.write("/* NOTE: this file is autogenerated from {}: do not edit manually */\n".format(src))
        f.write(out)

    sys.exit(0)


if __name__ == "__main__":
    main()
