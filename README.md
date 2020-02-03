`cross-poppler` compiles [Poppler PDF tools](https://poppler.freedesktop.org/) for macOS (x64), Windows (x86, x64), Linux (x86, x64).

This is only intended to be used for `pdfinfo` and `pdftotext`.

### pdfinfo
`pdfinfo` is modified to output to a specified file.

### pdftotext
`pdftotext` is modified to output a preprocessed JSON that contains rich and structured information about the PDF and the text extracted from it:
- PDF metadata
- Page dimensions
- Page count
- Word position
- Font size
- Space after word
- Baseline
- Rotation
- Bold
- Italic
- Color
- Font

Also, a command line switch is added to customize the path to `poppler-data` directory. 

### Build

PDF tools are build inside the Docker container.

A macOS SDK is needed. Place `MacOSX10.*.sdk.tar.xz` to the current directory. Refer to [here](https://github.com/tpoechtrager/osxcross#packaging-the-sdk) for instructions.

Versions known to work:
- MacOSX10.11.sdk.tar.xz generated from XCode 7.3
- MacOSX10.15.sdk.tar.xz generated from XCode 11.3.1 on macOS 10.15.2
```
git clone https://github.com/zotero/cross-poppler
cd cross-poppler
mv path_to_sdk/MacOSX10.*.sdk.tar.xz ./
./build.sh
```

`./build/pdftools.tar.gz` contains the built binaries and `poppler-data` directory.
