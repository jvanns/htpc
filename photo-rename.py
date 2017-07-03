#!/usr/bin/python

import os
import sys
from optparse import OptionParser

from PIL import Image
from PIL.ExifTags import TAGS

from os.path import dirname
from time import time, strftime, strptime

def parse_command_line():
    parser = OptionParser(version='%prog 0.1')

    parser.add_option('-x', '--dry-run', action='store_true',
                      dest='dryrun',
                      default=False,
                      help="""don't rename files, just print the action
                              [default: %default]""")

    parser.add_option('-d', '--destination-dir', action='store', type='str',
                      dest='dest_dir',
                      metavar='DESTINATION_DIR',
                      default=None,
                      help="""choose an alternative output directory
                              [default: same directory as original file]""")

    return parser.parse_args()


def get_field (exif,field):
    for (k,v) in exif.iteritems():
        if TAGS.get(k) == field:
            return v


if __name__ == '__main__':
    modified = 0
    now = int(round(time()))
    options, arguments = parse_command_line()

    for f in arguments:
        try:
            exif = Image.open(f)._getexif()
            t = get_field(exif, 'DateTime')
            s = int(strftime('%s', strptime(t, '%Y:%m:%d %H:%M:%S')))
        except Exception, e:
            info = os.stat(f)
            s = int(info.st_mtime)
            print >> sys.stderr, '%s: No EXIF data, using mtime %d' % (
                f, s
            )

        try:
            suffix = 0
            ext = f.split('.')[-1]
            outdir = dirname(f) + os.sep

            if options.dest_dir is not None:
                outdir = options.dest_dir + os.sep

            while os.access("%s%d-%d.%s" % (outdir, s, suffix, ext), os.F_OK):
                suffix += 1

            dst = "%s%d-%d.%s" % (outdir, s, suffix, ext)

            if not options.dryrun:
                os.rename(f, dst)
                os.utime(dst, (now, s))
                modified += 1
            else:
                print '%s -> %s' % (f, dst)
                print '%d / %d ' % (now, s)
        except Exception, e:
            print >> sys.stderr, e

    print '%d files modified' % (modified)
