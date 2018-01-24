//========================================================================
//
// pdftotext.cc
//
// Copyright 1997-2003 Glyph & Cog, LLC
//
// Modified for Debian by Hamish Moffatt, 22 May 2002.
//
//========================================================================

//========================================================================
//
// Modified under the Poppler project - http://poppler.freedesktop.org
//
// All changes made under the Poppler project to this file are licensed
// under GPL version 2 or later
//
// Copyright (C) 2006 Dominic Lachowicz <cinamod@hotmail.com>
// Copyright (C) 2007-2008, 2010, 2011, 2017 Albert Astals Cid <aacid@kde.org>
// Copyright (C) 2009 Jan Jockusch <jan@jockusch.de>
// Copyright (C) 2010, 2013 Hib Eris <hib@hiberis.nl>
// Copyright (C) 2010 Kenneth Berland <ken@hero.com>
// Copyright (C) 2011 Tom Gleason <tom@buildadam.com>
// Copyright (C) 2011 Steven Murdoch <Steven.Murdoch@cl.cam.ac.uk>
// Copyright (C) 2013 Yury G. Kudryashov <urkud.urkud@gmail.com>
// Copyright (C) 2013 Suzuki Toshiya <mpsuzuki@hiroshima-u.ac.jp>
// Copyright (C) 2015 Jeremy Echols <jechols@uoregon.edu>
// Copyright (C) 2017 Adrian Johnson <ajohnson@redneon.com>
//
// To see a description of the changes please see the Changelog file that
// came with your tarball or type make ChangeLog if you are building from git
//
//========================================================================

#include "config.h"
#include <poppler-config.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <string>
#include <sstream>
#include <iomanip>
#include <iostream>
#include "parseargs.h"
#include "printencodings.h"
#include "goo/GooString.h"
#include "goo/gmem.h"
#include "GlobalParams.h"
#include "Object.h"
#include "Stream.h"
#include "Array.h"
#include "Dict.h"
#include "XRef.h"
#include "Catalog.h"
#include "Page.h"
#include "PDFDoc.h"
#include "PDFDocFactory.h"
#include "TextOutputDev.h"
#include "CharTypes.h"
#include "UnicodeMap.h"
#include "PDFDocEncoding.h"
#include "Error.h"
#include "Win32Console.h"

static int firstPage = 1;
static int lastPage = 0;
static double resolution = 72.0;
static GBool json = gFalse;
static GBool physLayout = gFalse;
static double fixedPitch = 0;
static GBool rawOrder = gFalse;
static GBool noPageBreaks = gFalse;
static GBool quiet = gFalse;
static GBool printVersion = gFalse;
static GBool printHelp = gFalse;
static char datadir[8192] = "";

static const ArgDesc argDesc[] = {
        {"-f",       argInt,    &firstPage,    0,
                "first page to convert"},
        {"-l",       argInt,    &lastPage,     0,
                "last page to convert"},
        {"-r",       argFP,     &resolution,   0,
                "resolution, in DPI (default is 72)"},
        {"-layout",  argFlag,   &physLayout,   0,
                "maintain original physical layout"},
        {"-fixed",   argFP,     &fixedPitch,   0,
                "assume fixed-pitch (or tabular) text"},
        {"-raw",     argFlag,   &rawOrder,     0,
                "keep strings in content stream order"},
        {"-datadir", argString, datadir,       sizeof(datadir),
                "poppler data directory"},
        {"-nopgbrk", argFlag,   &noPageBreaks, 0,
                "don't insert page breaks between pages"},
        {"-json",    argFlag,   &json,         0,
                "output JSON with metadata, layout and rich text"},
        {"-q",       argFlag,   &quiet,        0,
                "don't print any messages or errors"},
        {"-v",       argFlag,   &printVersion, 0,
                "print copyright and version info"},
        {"-h",       argFlag,   &printHelp,    0,
                "print usage information"},
        {"-help",    argFlag,   &printHelp,    0,
                "print usage information"},
        {"--help",   argFlag,   &printHelp,    0,
                "print usage information"},
        {"-?",       argFlag,   &printHelp,    0,
                "print usage information"},
        {NULL}
};

// From https://stackoverflow.com/a/33799784
std::string escape_json(const std::string &s) {
    std::ostringstream o;
    for (auto c = s.cbegin(); c != s.cend(); c++) {
        switch (*c) {
            case '"': o << "\\\""; break;
            case '\\': o << "\\\\"; break;
            case '\b': o << "\\b"; break;
            case '\f': o << "\\f"; break;
            case '\n': o << "\\n"; break;
            case '\r': o << "\\r"; break;
            case '\t': o << "\\t"; break;
            default:
                if ('\x00' <= *c && *c <= '\x1f') {
                    o << "\\u"
                      << std::hex << std::setw(4) << std::setfill('0') << (int)*c;
                } else {
                    o << *c;
                }
        }
    }
    return o.str();
}

static void printInfoJSON(FILE *f, Dict *infoDict, UnicodeMap *uMap) {
    GooString *s1;
    GBool isUnicode;
    Unicode u;
    char buf[9];
    int i, n;

    bool firstE = true;
    for (int k = 0; k < infoDict->getLength(); k++) {
        const std::string keyStr = escape_json(infoDict->getKey(k));
        if (!keyStr.length()) continue;
        Object obj = infoDict->getVal(k);
        if (obj.isString()) {
            if (firstE) firstE = false; else fprintf(f, ",");
            s1 = obj.getString();
            if ((s1->getChar(0) & 0xff) == 0xfe &&
                (s1->getChar(1) & 0xff) == 0xff) {
                isUnicode = gTrue;
                i = 2;
            } else {
                isUnicode = gFalse;
                i = 0;
            }
            std::string valueStr = "";
            while (i < obj.getString()->getLength()) {
                if (isUnicode) {
                    u = ((s1->getChar(i) & 0xff) << 8) |
                        (s1->getChar(i + 1) & 0xff);
                    i += 2;
                } else {
                    u = pdfDocEncoding[s1->getChar(i) & 0xff];
                    ++i;
                }
                n = uMap->mapUnicode(u, buf, sizeof(buf));
                buf[n] = '\0';
                valueStr += escape_json(buf);
            }
            fprintf(f, "\"%s\":\"%s\"", keyStr.c_str(), valueStr.c_str());
        }
    }
}

void printDocJSON(FILE *f, PDFDoc *doc, TextOutputDev *textOut, int first, int last, UnicodeMap *uMap) {
    double xMin, yMin, xMax, yMax;
    TextPage *textPage;
    TextFlow *flow;
    TextBlock *blk;
    TextLine *line;
    TextWord *word;

    std::map<std::string, int> fonts;
    std::map<std::string, int> colors;
    std::map<std::string, int>::iterator it;

    fprintf(f, "{\"metadata\":{");

    Object info = doc->getDocInfo();
    if (info.isDict()) {
        printInfoJSON(f, info.getDict(), uMap);
    }

    fprintf(f, "},");
    fprintf(f, "\"totalPages\":%d,", doc->getNumPages());
    fprintf(f, "\"pages\":[");
    bool firstP = true;
    for (int page = first; page <= last; ++page) {
        if (firstP) firstP = false; else fprintf(f, ",");
        fprintf(f, "[%g,%g,[", doc->getPageMediaWidth(page), doc->getPageMediaHeight(page));
        doc->displayPage(textOut, page, resolution, resolution, 0, gTrue, gFalse, gFalse);
        textPage = textOut->takeText();
        bool firstF = true;
        for (flow = textPage->getFlows(); flow; flow = flow->getNext()) {
            if (firstF) firstF = false; else fprintf(f, ",");
            fprintf(f, "[[");
            bool firstB = true;
            for (blk = flow->getBlocks(); blk; blk = blk->getNext()) {
                if (firstB) firstB = false; else fprintf(f, ",");
                blk->getBBox(&xMin, &yMin, &xMax, &yMax);
                fprintf(f, "[%g,%g,%g,%g,[", xMin, yMin, xMax, yMax);
                bool firstL = true;
                for (line = blk->getLines(); line; line = line->getNext()) {
                    if (firstL) firstL = false; else fprintf(f, ",");
                    fprintf(f, "[[");
                    bool firstW = true;
                    for (word = line->getWords(); word; word = word->getNext()) {
                        if (firstW) firstW = false; else fprintf(f, ",");
                        word->getBBox(&xMin, &yMin, &xMax, &yMax);
                        const std::string myString = escape_json(word->getText()->getCString());

                        // Instead of the actual RGB offsets we only output a unique color number
                        double dr, dg, db;
                        int r, g, b;
                        char colorStr[256];
                        int color_nr = 0;

                        word->getColor(&dr, &dg, &db);
                        r = 255.0 * dr;
                        g = 255.0 * dg;
                        b = 255.0 * db;

                        sprintf(colorStr, "%02x%02x%02x", r, g, b);

                        colors.insert(std::make_pair(colorStr, colors.size()));
                        it = colors.find(colorStr);
                        if (it != colors.end()) {
                            color_nr = it->second;
                        }

                        // Instead of the actual font names we only output a unique font number
                        int font_nr = 0;
                        TextFontInfo *fontInfo = word->getFontInfo(0);

                        if (fontInfo && fontInfo->getFontName()) {
                            const std::string fontName = escape_json(fontInfo->getFontName()->getCString());
                            fonts.insert(std::make_pair(fontName, fonts.size()));
                            it = fonts.find(fontName);
                            if (it != fonts.end()) {
                                font_nr = it->second;
                            }
                        }

                        fprintf(f,
                                "["
                                        "%g,"
                                        "%g,"
                                        "%g,"
                                        "%g,"
                                        "%g,"
                                        "%d,"
                                        "%g,"
                                        "%d,"
                                        "%d,"
                                        "%d,"
                                        "%d,"
                                        "%d,"
                                        "%d,"
                                        "\"%s\""
                                        "]",
                                xMin,
                                yMin,
                                xMax,
                                yMax,
                                word->getFontSize(),
                                word->hasSpaceAfter(),
                                word->getBaseline(),
                                word->getRotation(),
                                word->isUnderlined(),
                                fontInfo->isBold(),
                                fontInfo->isItalic(),
                                color_nr,
                                font_nr,
                                myString.c_str()
                        );
                    }
                    fprintf(f, "]]");
                }
                fprintf(f, "]]");
            }
            fprintf(f, "]]");
        }
        fprintf(f, "]]");
    }
    fprintf(f, "]}");
}

int main(int argc, char *argv[]) {
    PDFDoc *doc;
    GooString *fileName;
    GooString *textFileName;
    TextOutputDev *textOut;
    FILE *f;
    UnicodeMap *uMap;
    Object info;
    GBool ok;
    int exitCode;

    Win32Console win32Console(&argc, &argv);
    exitCode = 99;

    // parse args
    ok = parseArgs(argDesc, &argc, argv);

    if (!ok || argc != 3 || printVersion || printHelp) {
        fprintf(stderr, "This is a custom Poppler pdftotext build. Please use the original version!\n");
        fprintf(stderr, "pdftotext version %s\n", PACKAGE_VERSION);
        fprintf(stderr, "%s\n", popplerCopyright);
        fprintf(stderr, "%s\n", xpdfCopyright);
        if (!printVersion) {
            printUsage("pdftotext", "<PDF-file> <output-file>", argDesc);
        }
        if (printVersion || printHelp)
            exitCode = 0;
        goto err0;
    }

    // read config file
    globalParams = new GlobalParams(datadir);

    // force LF EOL on all platforms
    globalParams->setTextEOL("unix");

    fileName = new GooString(argv[1]);
    if (fixedPitch) {
        physLayout = gTrue;
    }

    if (noPageBreaks) {
        globalParams->setTextPageBreaks(gFalse);
    }
    if (quiet) {
        globalParams->setErrQuiet(quiet);
    }

    // get mapping to output encoding
    if (!(uMap = globalParams->getTextEncoding())) {
        error(errCommandLine, -1, "Couldn't get text encoding");
        delete fileName;
        goto err1;
    }

    doc = PDFDocFactory().createPDFDoc(*fileName, NULL, NULL);
    if (!doc->isOk()) {
        exitCode = 1;
        goto err2;
    }

    // construct text file name
    textFileName = new GooString(argv[2]);

    // get page range
    if (firstPage < 1) {
        firstPage = 1;
    }
    if (lastPage < 1 || lastPage > doc->getNumPages()) {
        lastPage = doc->getNumPages();
    }
    if (lastPage < firstPage) {
        error(errCommandLine, -1,
              "Wrong page range given: the first page ({0:d}) can not be after the last page ({1:d}).",
              firstPage, lastPage);
        goto err3;
    }

    // output JSON
    if (json) {
        if (!(f = fopen(textFileName->getCString(), "wb"))) {
            error(errIO, -1, "Couldn't open text file '{0:t}'", textFileName);
            exitCode = 2;
            goto err3;
        }

        textOut = new TextOutputDev(NULL, physLayout, fixedPitch, rawOrder, false);

        if (textOut->isOk()) {
            printDocJSON(f, doc, textOut, firstPage, lastPage, uMap);
        }

        fclose(f);

    } // output text
    else {
        textOut = new TextOutputDev(textFileName->getCString(),
                                    physLayout, fixedPitch, rawOrder, false);
        if (textOut->isOk()) {
            doc->displayPages(textOut, firstPage, lastPage, resolution, resolution, 0,
                              gTrue, gFalse, gFalse);

        } else {
            delete textOut;
            exitCode = 2;
            goto err3;
        }
    }
    delete textOut;

    exitCode = 0;

    // clean up
    err3:
    delete textFileName;
    err2:
    delete doc;
    delete fileName;
    uMap->decRefCnt();
    err1:
    delete globalParams;
    err0:

    // check for memory leaks
    Object::memCheck(stderr);
    gMemReport(stderr);

    return exitCode;
}
