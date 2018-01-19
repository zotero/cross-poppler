Compiles [Poppler PDF tools](https://poppler.freedesktop.org/) for macOS (x64), Windows (x86, x64), Linux (x86, x64).
This is only intended to be used for `pdfinfo` and `pdftotext`. `pdfinfo` is modified to output to a specified file.
All building happens inside a Docker container.

macOS 10.11 SDK is needed. Place `MacOSX10.11.sdk.tar.xz` to the current directory. [Extract it from Xcode 7.3](https://github.com/tpoechtrager/osxcross#packaging-the-sdk).

```
git clone https://github.com/mrtcode/cross-poppler
cd cross-poppler
mv path_to_sdk/MacOSX10.11.sdk.tar.xz ./
./build.sh
```

Check `./build` for the built binaries.